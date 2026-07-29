#!/bin/bash
# PlayMaker JO — MySQL backup
#
# Install (once):  ./backup-db.sh --install-cron
# Verify a file:   ./backup-db.sh --verify-only backups/sportsvenue_2026-07-29_0936.sql.gz
#
# The previous version could not work from cron, and when it failed it failed in the worst
# possible way. It read $MYSQL_ROOT_PASSWORD without sourcing .env, so under `set -u` it
# aborted — but only AFTER the shell had already created the output file via `>`. gzip with no
# input writes a valid 20-byte header, so every failed run left a file that looked exactly
# like a successful backup. The cron entry documented in its header was never installed, so
# this had been failing invisibly rather than loudly.
#
# Two rules follow, and everything below serves them:
#   1. Never write the final filename until the dump is verified. Dump to `.part`, check it,
#      then rename — the rename is the commit.
#   2. Exit non-zero on any failure, so cron mails root instead of staying quiet.

set -euo pipefail

# cron runs with a near-empty environment and an arbitrary working directory, which is why
# this resolves its own location instead of assuming either.
cd "$(dirname "$(readlink -f "$0")")"

BACKUP_DIR="$(pwd)/backups"
CONTAINER="playmakerjo-mysql-1"
DATABASE="sportsvenue"
KEEP_DAYS=7
MIN_BYTES=20000          # a real dump of this schema is ~200KB uncompressed. This is a floor
                         # to catch empty and near-empty output, not a target.

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] FAILED: $*" >&2; exit 1; }

# ── Verification ────────────────────────────────────────────────────────────────────────
# Shared by the backup path and --verify-only, so a backup is checked by exactly the code that
# would later be used to vouch for it.
verify_dump() {
  local file="$1" expected_tables="${2:-}"

  [ -s "$file" ] || die "$file is empty or missing"
  gzip -t "$file" 2>/dev/null || die "$file is not valid gzip"

  local bytes
  bytes=$(gunzip -c "$file" | wc -c)
  [ "$bytes" -ge "$MIN_BYTES" ] \
    || die "$file decompresses to only ${bytes} bytes (floor ${MIN_BYTES}) — near-empty dump"

  # mysqldump writes this as its last line. A dump truncated by a full disk, an OOM kill or a
  # dropped connection is otherwise valid gzip containing valid SQL — it just stops partway,
  # silently missing whichever tables came last.
  gunzip -c "$file" | tail -5 | grep -q -- "-- Dump completed" \
    || die "$file has no '-- Dump completed' marker — the dump was truncated"

  local tables
  tables=$(gunzip -c "$file" | grep -c "^CREATE TABLE" || true)
  [ "$tables" -gt 0 ] || die "$file contains no CREATE TABLE statements"

  if [ -n "$expected_tables" ] && [ "$tables" -ne "$expected_tables" ]; then
    die "$file has $tables tables but the live database has $expected_tables"
  fi

  log "verified: $(basename "$file") — ${bytes} bytes uncompressed, ${tables} tables"
}

# ── --verify-only ───────────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--verify-only" ]; then
  [ -n "${2:-}" ] || die "usage: $0 --verify-only <file.sql.gz>"
  verify_dump "$2"
  log "OK"
  exit 0
fi

# ── --install-cron ──────────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--install-cron" ]; then
  SELF="$(pwd)/backup-db.sh"
  LINE="0 3 * * * $SELF >> /var/log/playmakerjo-backup.log 2>&1"
  if crontab -l 2>/dev/null | grep -Fq "$SELF"; then
    log "cron entry already present:"
    crontab -l 2>/dev/null | grep -F "$SELF"
  else
    { crontab -l 2>/dev/null || true; echo "$LINE"; } | crontab -
    log "installed: $LINE"
  fi
  exit 0
fi

# ── Backup ──────────────────────────────────────────────────────────────────────────────
# Sourcing .env is what makes this work under cron. The old script assumed the caller had
# already exported these — true in an interactive shell, false everywhere else.
[ -f ./.env ] || die "no .env beside this script (looked in $(pwd))"
set -a
# shellcheck disable=SC1091
. ./.env
set +a

[ -n "${MYSQL_ROOT_PASSWORD:-}" ] || die "MYSQL_ROOT_PASSWORD is not set in $(pwd)/.env"

mkdir -p "$BACKUP_DIR"
DATE=$(date +%Y-%m-%d_%H%M)
FINAL="$BACKUP_DIR/${DATABASE}_${DATE}.sql.gz"
PART="${FINAL}.part"

# Any exit before the rename removes the partial, so a failed run leaves nothing that could
# later be mistaken for a backup.
cleanup() { [ -f "$PART" ] && rm -f "$PART"; }
trap cleanup EXIT

log "Starting backup of ${DATABASE}..."

# Ask the live database how many tables it has, so the dump is checked against reality rather
# than a number hardcoded here that would rot the next time a migration adds a table.
EXPECTED_TABLES=$(docker exec "$CONTAINER" mysql -u root -p"$MYSQL_ROOT_PASSWORD" -N -B \
  -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DATABASE}';" \
  2>/dev/null | tr -d '\r') || die "cannot reach MySQL in container ${CONTAINER}"
log "live database reports ${EXPECTED_TABLES} tables"

docker exec "$CONTAINER" mysqldump \
  -u root \
  -p"$MYSQL_ROOT_PASSWORD" \
  --single-transaction \
  --routines \
  --triggers \
  "$DATABASE" \
  2>/dev/null \
  | gzip > "$PART"

verify_dump "$PART" "$EXPECTED_TABLES"

# The commit. Nothing below this line can leave a bad file under the real name.
mv "$PART" "$FINAL"
trap - EXIT
log "Backup saved: $(basename "$FINAL")"

# ── Offsite copy (only when RCLONE_REMOTE is set, e.g. b2:playmakerjo-backups) ───────────
if [ -n "${RCLONE_REMOTE:-}" ]; then
  log "Copying to ${RCLONE_REMOTE}/playmakerjo-db..."
  rclone copy "$FINAL" "${RCLONE_REMOTE}/playmakerjo-db" || log "WARNING: offsite copy failed"
  rclone delete --min-age "${RCLONE_KEEP_DAYS:-30}d" "${RCLONE_REMOTE}/playmakerjo-db" || true
  log "Offsite copy done (keeping last ${RCLONE_KEEP_DAYS:-30} days)"
fi

# ── Retention ───────────────────────────────────────────────────────────────────────────
# Scoped to this script's own naming so the hand-taken .sql snapshots in backups/ are left
# alone — they predate this and are the only pre-CRM copies of the database.
find "$BACKUP_DIR" -name "${DATABASE}_*.sql.gz" -mtime "+${KEEP_DAYS}" -delete
find "$BACKUP_DIR" -name "${DATABASE}_*.sql.gz.part" -mtime +1 -delete
log "Cleaned up backups older than ${KEEP_DAYS} days"
