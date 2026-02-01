#!/bin/sh
set -e

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

export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

AWS_ARGS=""
if [ -n "$S3_ENDPOINT" ]; then
  AWS_ARGS="--endpoint-url $S3_ENDPOINT"
fi

export PGPASSWORD=$POSTGRES_PASSWORD

POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"

if [ -z "$S3_PREFIX" ]; then
  S3_PREFIX=""
else
  S3_PREFIX="/${S3_PREFIX}"
fi

if [ "$SCHEDULE" = "**None**" ]; then
  exec /do-backup.sh
else
  apk add --no-cache dcron
  echo "$SCHEDULE root /bin/sh /do-backup.sh" > /etc/crontabs/root
  crond -f -l 2
fi

POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"

if [ -z "$S3_PREFIX" ]; then
  S3_PREFIX=""
else
  S3_PREFIX="/${S3_PREFIX}"
fi

if [ "$POSTGRES_BACKUP_ALL" = "true" ]; then
  SRC_FILE=dump.sql.gz
  DEST_FILE=all_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz

  echo "Creating dump of all databases from ${POSTGRES_HOST}..."
  pg_dumpall $POSTGRES_HOST_OPTS | gzip > $SRC_FILE

  if [ -n "$ENCRYPTION_PASSWORD" ]; then
    echo "Encrypting ${SRC_FILE}"
    openssl enc -aes-256-cbc -in $SRC_FILE -out ${SRC_FILE}.enc -k $ENCRYPTION_PASSWORD
    rm $SRC_FILE
    SRC_FILE="${SRC_FILE}.enc"
    DEST_FILE="${DEST_FILE}.enc"
  fi

  echo "Uploading dump to $S3_BUCKET"
  aws $AWS_ARGS s3 cp $SRC_FILE "s3://${S3_BUCKET}${S3_PREFIX}/${DEST_FILE}"

  echo "SQL backup uploaded successfully"
  rm -rf $SRC_FILE
else
  for DB in $(echo $POSTGRES_DATABASE | tr "," "\n"); do
    SRC_FILE=dump.sql.gz
    DEST_FILE=${DB}_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz

    echo "Creating dump of ${DB} database from ${POSTGRES_HOST}..."
    pg_dump $POSTGRES_HOST_OPTS $DB | gzip > $SRC_FILE

    if [ -n "$ENCRYPTION_PASSWORD" ]; then
      echo "Encrypting ${SRC_FILE}"
      openssl enc -aes-256-cbc -in $SRC_FILE -out ${SRC_FILE}.enc -k $ENCRYPTION_PASSWORD
      rm $SRC_FILE
      SRC_FILE="${SRC_FILE}.enc"
      DEST_FILE="${DEST_FILE}.enc"
    fi

    echo "Uploading dump to $S3_BUCKET"
    aws $AWS_ARGS s3 cp $SRC_FILE "s3://${S3_BUCKET}${S3_PREFIX}/${DEST_FILE}"

    echo "SQL backup uploaded successfully"
    rm -rf $SRC_FILE
  done
fi
