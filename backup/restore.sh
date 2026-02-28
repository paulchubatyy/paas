#!/bin/sh
set -e

export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

AWS_ARGS=""
if [ -n "$S3_ENDPOINT" ]; then
  AWS_ARGS="--endpoint-url $S3_ENDPOINT"
fi

if [ -z "$S3_PREFIX" ]; then
  S3_PREFIX=""
else
  S3_PREFIX="/${S3_PREFIX}"
fi

echo "Finding latest backup in s3://${S3_BUCKET}${S3_PREFIX}/"
LATEST_BACKUP=$(aws $AWS_ARGS s3 ls "s3://${S3_BUCKET}${S3_PREFIX}/" | sort -r | head -n 1 | awk '{print $4}')

if [ -z "$LATEST_BACKUP" ]; then
  echo "Error: No backups found"
  exit 1
fi

echo "Latest backup: $LATEST_BACKUP"

SRC_FILE=$LATEST_BACKUP

echo "Downloading backup from S3..."
aws $AWS_ARGS s3 cp "s3://${S3_BUCKET}${S3_PREFIX}/${LATEST_BACKUP}" $SRC_FILE

if echo "$SRC_FILE" | grep -q '\.enc$'; then
  if [ -z "$ENCRYPTION_PASSWORD" ]; then
    echo "Error: Backup is encrypted but ENCRYPTION_PASSWORD is not set"
    exit 1
  fi
  echo "Decrypting backup..."
  openssl enc -aes-256-cbc -d -in $SRC_FILE -out "${SRC_FILE%.enc}" -k $ENCRYPTION_PASSWORD
  SRC_FILE="${SRC_FILE%.enc}"
fi

if echo "$SRC_FILE" | grep -q '\.gz$'; then
  echo "Decompressing backup..."
  gunzip -c $SRC_FILE > restore.sql
else
  cp $SRC_FILE restore.sql
fi

case "$DB_TYPE" in
  postgres)
    export PGPASSWORD=$DB_PASSWORD
    HOST_OPTS="-h $DB_HOST -p $DB_PORT -U $DB_USER"

    if [ "$DROP_PUBLIC" = "yes" ]; then
      echo "Dropping public schema..."
      psql $HOST_OPTS -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
    fi

    if [ "$BACKUP_ALL" = "true" ]; then
      echo "Restoring all databases..."
      psql $HOST_OPTS < restore.sql
    else
      for DB in $(echo $DB_NAME | tr "," "\n"); do
        echo "Restoring database: $DB"
        psql $HOST_OPTS $DB < restore.sql
      done
    fi
    ;;
  mariadb)
    export MYSQL_PWD=$DB_PASSWORD
    HOST_OPTS="-h $DB_HOST -P $DB_PORT -u $DB_USER"

    if [ "$DROP_PUBLIC" = "yes" ]; then
      echo "Dropping and recreating database..."
      for DB in $(echo $DB_NAME | tr "," "\n"); do
        mysql $HOST_OPTS -e "DROP DATABASE IF EXISTS \`$DB\`; CREATE DATABASE \`$DB\`;"
      done
    fi

    if [ "$BACKUP_ALL" = "true" ]; then
      echo "Restoring all databases..."
      mysql $HOST_OPTS < restore.sql
    else
      for DB in $(echo $DB_NAME | tr "," "\n"); do
        echo "Restoring database: $DB"
        mysql $HOST_OPTS $DB < restore.sql
      done
    fi
    ;;
  *)
    echo "Error: Unsupported DB_TYPE '$DB_TYPE' (use 'postgres' or 'mariadb')"
    exit 1
    ;;
esac

echo "Restore completed successfully"
rm -f restore.sql $LATEST_BACKUP "${LATEST_BACKUP%.enc}"
