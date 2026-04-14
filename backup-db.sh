#!/bin/bash
# YallaNhjez — Daily MySQL backup script
# Add to cron: 0 3 * * * /opt/yallanhjez/backup-db.sh
# Keeps the last 7 daily backups

set -euo pipefail

BACKUP_DIR="/opt/yallanhjez/backups"
CONTAINER="yallanhjez-mysql-1"
DATE=$(date +%Y-%m-%d_%H%M)
KEEP_DAYS=7

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting backup..."

docker exec "$CONTAINER" mysqldump \
  -u root \
  -p"$MYSQL_ROOT_PASSWORD" \
  --single-transaction \
  --routines \
  --triggers \
  sportsvenue \
  | gzip > "$BACKUP_DIR/sportsvenue_${DATE}.sql.gz"

echo "[$(date)] Backup saved: sportsvenue_${DATE}.sql.gz"

# Delete backups older than $KEEP_DAYS days
find "$BACKUP_DIR" -name "sportsvenue_*.sql.gz" -mtime +$KEEP_DAYS -delete

echo "[$(date)] Cleaned up old backups (keeping last $KEEP_DAYS days)"
