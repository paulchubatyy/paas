#!/bin/sh
set -e

if [ "$SCHEDULE" = "**None**" ]; then
  echo "Running one-time backup..."
  exec /do-backup.sh
else
  echo "Setting up scheduled backup: $SCHEDULE"
  apt-get update && apt-get install -y cron
  echo "$SCHEDULE root /bin/sh /do-backup.sh >> /var/log/backup.log 2>&1" > /etc/cron.d/backup
  chmod 0644 /etc/cron.d/backup
  cron -f
fi
