#!/bin/bash
# PlayMaker JO — Daily MySQL backup script
# Add to cron: 0 3 * * * /opt/playmakerjo/backup-db.sh
# Keeps the last 7 daily backups

set -euo pipefail

BACKUP_DIR="/opt/playmakerjo/backups"
CONTAINER="playmakerjo-mysql-1"
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

# Offsite copy (only when RCLONE_REMOTE is set, e.g. b2:playmakerjo-backups)
if [ -n "${RCLONE_REMOTE:-}" ]; then
  echo "[$(date)] Copying backup to ${RCLONE_REMOTE}/playmakerjo-db..."
  rclone copy "$BACKUP_DIR/sportsvenue_${DATE}.sql.gz" "${RCLONE_REMOTE}/playmakerjo-db" || true
  rclone delete --min-age "${RCLONE_KEEP_DAYS:-30}d" "${RCLONE_REMOTE}/playmakerjo-db" || true
  echo "[$(date)] Offsite copy done (keeping last ${RCLONE_KEEP_DAYS:-30} days)"
fi

# Delete backups older than $KEEP_DAYS days
find "$BACKUP_DIR" -name "sportsvenue_*.sql.gz" -mtime +$KEEP_DAYS -delete

echo "[$(date)] Cleaned up old backups (keeping last $KEEP_DAYS days)"
