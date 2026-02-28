#!/bin/bash
set -e

# --- Validation ---

if [ -z "$DB_TYPE" ] || { [ "$DB_TYPE" != "postgres" ] && [ "$DB_TYPE" != "mariadb" ]; }; then
  echo "Error: DB_TYPE must be 'postgres' or 'mariadb' (got '${DB_TYPE}')"
  exit 1
fi

if [ "$BACKUP_ALL" != "true" ] && [ -z "$DB_NAME" ]; then
  echo "Error: DB_NAME is required when BACKUP_ALL is not 'true'"
  exit 1
fi

# Validate DB_NAME contains only safe characters
if [ -n "$DB_NAME" ]; then
  case "$DB_NAME" in
    *[!a-zA-Z0-9_,]*)
      echo "Error: DB_NAME contains invalid characters (allowed: a-z, 0-9, _, comma)"
      exit 1
      ;;
  esac
fi

if [ -z "$S3_ACCESS_KEY_ID" ]; then
  echo "Error: S3_ACCESS_KEY_ID is required"
  exit 1
fi

if [ -z "$S3_SECRET_ACCESS_KEY" ]; then
  echo "Error: S3_SECRET_ACCESS_KEY is required"
  exit 1
fi

if [ -z "$S3_BUCKET" ]; then
  echo "Error: S3_BUCKET is required"
  exit 1
fi

# --- S3 setup ---

export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="$S3_REGION"

AWS_ARGS=""
if [ -n "$S3_ENDPOINT" ]; then
  AWS_ARGS="--endpoint-url $S3_ENDPOINT"
fi

if [ -n "$S3_PREFIX" ]; then
  S3_PREFIX="/${S3_PREFIX}"
fi

# --- Helper: download, decrypt, decompress ---

download_backup() {
  local prefix="$1"
  local backup_file

  echo "Finding latest ${prefix}backup in s3://${S3_BUCKET}${S3_PREFIX}/"
  backup_file=$(aws $AWS_ARGS s3 ls "s3://${S3_BUCKET}${S3_PREFIX}/${prefix}" | sort -r | head -n 1 | awk '{print $4}')

  if [ -z "$backup_file" ]; then
    echo "Error: No backups found matching '${prefix}*'"
    exit 1
  fi

  echo "Latest backup: $backup_file"

  aws $AWS_ARGS s3 cp "s3://${S3_BUCKET}${S3_PREFIX}/${backup_file}" "$backup_file"

  local src_file="$backup_file"

  if echo "$src_file" | grep -q '\.enc$'; then
    if [ -z "$ENCRYPTION_PASSWORD" ]; then
      echo "Error: Backup is encrypted but ENCRYPTION_PASSWORD is not set"
      rm -f "$src_file"
      exit 1
    fi
    echo "Decrypting backup..."
    openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -d \
      -in "$src_file" -out "${src_file%.enc}" -pass env:ENCRYPTION_PASSWORD
    rm -f "$src_file"
    src_file="${src_file%.enc}"
  fi

  if echo "$src_file" | grep -q '\.gz$'; then
    echo "Decompressing backup..."
    gunzip -c "$src_file" > restore.sql
    rm -f "$src_file"
  else
    mv "$src_file" restore.sql
  fi
}

# --- Restore ---

case "$DB_TYPE" in
  postgres)
    export PGPASSWORD="$DB_PASSWORD"
    HOST_OPTS="-h $DB_HOST -p $DB_PORT -U $DB_USER"

    if [ "$BACKUP_ALL" = "true" ]; then
      download_backup "all_"
      if [ "$DROP_PUBLIC" = "yes" ]; then
        echo "Dropping public schema..."
        psql $HOST_OPTS -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
      fi
      echo "Restoring all databases..."
      psql $HOST_OPTS < restore.sql
    else
      for DB in $(echo "$DB_NAME" | tr "," "\n"); do
        download_backup "${DB}_"
        if [ "$DROP_PUBLIC" = "yes" ]; then
          echo "Dropping public schema in ${DB}..."
          psql $HOST_OPTS "$DB" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
        fi
        echo "Restoring database: $DB"
        psql $HOST_OPTS "$DB" < restore.sql
        rm -f restore.sql
      done
    fi
    ;;
  mariadb)
    export MYSQL_PWD="$DB_PASSWORD"
    HOST_OPTS="-h $DB_HOST -P $DB_PORT -u $DB_USER"

    if [ "$BACKUP_ALL" = "true" ]; then
      download_backup "all_"
      if [ "$DROP_PUBLIC" = "yes" ]; then
        for DB in $(echo "$DB_NAME" | tr "," "\n"); do
          echo "Dropping and recreating ${DB}..."
          mysql $HOST_OPTS -e "DROP DATABASE IF EXISTS \`${DB}\`; CREATE DATABASE \`${DB}\`;"
        done
      fi
      echo "Restoring all databases..."
      mysql $HOST_OPTS < restore.sql
    else
      for DB in $(echo "$DB_NAME" | tr "," "\n"); do
        download_backup "${DB}_"
        if [ "$DROP_PUBLIC" = "yes" ]; then
          echo "Dropping and recreating ${DB}..."
          mysql $HOST_OPTS -e "DROP DATABASE IF EXISTS \`${DB}\`; CREATE DATABASE \`${DB}\`;"
        fi
        echo "Restoring database: $DB"
        mysql $HOST_OPTS "$DB" < restore.sql
        rm -f restore.sql
      done
    fi
    ;;
esac

rm -f restore.sql
echo "Restore completed successfully"
