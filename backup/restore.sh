#!/bin/sh
set -e

export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION
export PGPASSWORD=$POSTGRES_PASSWORD

AWS_ARGS=""
if [ -n "$S3_ENDPOINT" ]; then
  AWS_ARGS="--endpoint-url $S3_ENDPOINT"
fi

POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER"

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

if [[ $SRC_FILE == *.enc ]]; then
  if [ -z "$ENCRYPTION_PASSWORD" ]; then
    echo "Error: Backup is encrypted but ENCRYPTION_PASSWORD is not set"
    exit 1
  fi
  echo "Decrypting backup..."
  openssl enc -aes-256-cbc -d -in $SRC_FILE -out ${SRC_FILE%.enc} -k $ENCRYPTION_PASSWORD
  SRC_FILE=${SRC_FILE%.enc}
fi

if [[ $SRC_FILE == *.gz ]]; then
  echo "Decompressing backup..."
  gunzip -c $SRC_FILE > restore.sql
else
  cp $SRC_FILE restore.sql
fi

if [ "$DROP_PUBLIC" = "yes" ]; then
  echo "Dropping public schema..."
  psql $POSTGRES_HOST_OPTS -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
fi

if [ "$POSTGRES_BACKUP_ALL" = "true" ]; then
  echo "Restoring all databases..."
  psql $POSTGRES_HOST_OPTS < restore.sql
else
  for DB in $(echo $POSTGRES_DATABASE | tr "," "\n"); do
    echo "Restoring database: $DB"
    psql $POSTGRES_HOST_OPTS $DB < restore.sql
  done
fi

echo "Restore completed successfully"
rm -f restore.sql $LATEST_BACKUP ${LATEST_BACKUP%.enc}
