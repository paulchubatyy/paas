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

# --- Helpers ---

encrypt_and_upload() {
  local src_file="$1" dest_file="$2"

  if [ -n "$ENCRYPTION_PASSWORD" ]; then
    echo "Encrypting ${src_file}"
    openssl enc -aes-256-cbc -pbkdf2 -iter 600000 \
      -in "$src_file" -out "${src_file}.enc" -pass env:ENCRYPTION_PASSWORD
    rm "$src_file"
    src_file="${src_file}.enc"
    dest_file="${dest_file}.enc"
  fi

  echo "Uploading to s3://${S3_BUCKET}${S3_PREFIX}/${dest_file}"
  aws $AWS_ARGS s3 cp "$src_file" "s3://${S3_BUCKET}${S3_PREFIX}/${dest_file}"
  rm -f "$src_file"

  echo "Backup uploaded successfully"
}

# --- Dump ---

TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%SZ")

case "$DB_TYPE" in
  postgres)
    export PGPASSWORD="$DB_PASSWORD"
    HOST_OPTS="-h $DB_HOST -p $DB_PORT -U $DB_USER $EXTRA_OPTS"

    if [ "$BACKUP_ALL" = "true" ]; then
      echo "Dumping all databases from ${DB_HOST}..."
      pg_dumpall $HOST_OPTS | gzip > dump.sql.gz
      encrypt_and_upload dump.sql.gz "all_${TIMESTAMP}.sql.gz"
    else
      for DB in $(echo "$DB_NAME" | tr "," "\n"); do
        echo "Dumping ${DB} from ${DB_HOST}..."
        pg_dump $HOST_OPTS "$DB" | gzip > dump.sql.gz
        encrypt_and_upload dump.sql.gz "${DB}_${TIMESTAMP}.sql.gz"
      done
    fi
    ;;
  mariadb)
    export MYSQL_PWD="$DB_PASSWORD"
    HOST_OPTS="-h $DB_HOST -P $DB_PORT -u $DB_USER"

    if [ "$BACKUP_ALL" = "true" ]; then
      echo "Dumping all databases from ${DB_HOST}..."
      mysqldump $HOST_OPTS --single-transaction --all-databases $EXTRA_OPTS | gzip > dump.sql.gz
      encrypt_and_upload dump.sql.gz "all_${TIMESTAMP}.sql.gz"
    else
      for DB in $(echo "$DB_NAME" | tr "," "\n"); do
        echo "Dumping ${DB} from ${DB_HOST}..."
        mysqldump $HOST_OPTS --single-transaction $EXTRA_OPTS "$DB" | gzip > dump.sql.gz
        encrypt_and_upload dump.sql.gz "${DB}_${TIMESTAMP}.sql.gz"
      done
    fi
    ;;
esac
