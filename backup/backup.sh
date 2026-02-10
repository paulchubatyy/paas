#!/bin/sh
set -e

if [ "$SCHEDULE" = "**None**" ]; then
  echo "Running one-time backup..."
  exec /do-backup.sh
fi

# Convert schedule to seconds
case "$SCHEDULE" in
  @yearly|@annually) INTERVAL=31536000 ;;
  @monthly)          INTERVAL=2592000 ;;
  @weekly)           INTERVAL=604800 ;;
  @daily|@midnight)  INTERVAL=86400 ;;
  @hourly)           INTERVAL=3600 ;;
  @every_minute)     INTERVAL=60 ;;
  *)
    echo "Unsupported schedule: $SCHEDULE (use @daily, @hourly, @weekly, @monthly, or @yearly)"
    exit 1
    ;;
esac

echo "Backup schedule: $SCHEDULE (every ${INTERVAL}s)"
echo "Running initial backup..."
/do-backup.sh

echo "Scheduler started. Next backup in ${INTERVAL}s..."
while true; do
  sleep "$INTERVAL"
  echo "Running scheduled backup..."
  /do-backup.sh
  echo "Next backup in ${INTERVAL}s..."
done
