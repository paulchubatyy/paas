FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    postgresql-client \
    mariadb-client \
    awscli \
    gzip \
    openssl \
    && rm -rf /var/lib/apt/lists/*

COPY backup.sh do-backup.sh restore.sh /

RUN chmod +x /backup.sh /do-backup.sh /restore.sh

ENV DB_TYPE=postgres
ENV DB_HOST=db
ENV DB_PORT=5432
ENV DB_USER=
ENV DB_PASSWORD=
ENV DB_NAME=
ENV BACKUP_ALL=false
ENV EXTRA_OPTS=
ENV ENCRYPTION_PASSWORD=
ENV DROP_PUBLIC=yes
ENV S3_BUCKET=
ENV S3_REGION=us-east-1
ENV S3_PREFIX=backup
ENV SCHEDULE=@daily

CMD ["/bin/sh", "/backup.sh"]
