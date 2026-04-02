#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "$ENV_FILE"
  set +a
fi

PAPERCLIP_API_URL="${PAPERCLIP_API_URL:-}"
PAPERCLIP_API_KEY="${PAPERCLIP_API_KEY:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
REPORT_TIMEZONE="${REPORT_TIMEZONE:-Asia/Jakarta}"
REPORT_MAX_ITEMS="${REPORT_MAX_ITEMS:-6}"
RETRY_MAX_ATTEMPTS="${RETRY_MAX_ATTEMPTS:-3}"
RETRY_DELAY_SEC="${RETRY_DELAY_SEC:-5}"
DRY_RUN="${DRY_RUN:-0}"
LOG_FILE="${LOG_FILE:-$ROOT_DIR/deliverables/logs/daily-telegram-report.log}"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp="$(TZ="$REPORT_TIMEZONE" date '+%Y-%m-%d %H:%M:%S %Z')"
  printf '%s [%s] %s\n' "$timestamp" "$level" "$message" | tee -a "$LOG_FILE"
}

require_var() {
  local var_name="$1"
  if [[ -z "${!var_name:-}" ]]; then
    log "ERROR" "Variabel wajib belum di-set: $var_name"
    return 1
  fi
}

fetch_assignments_json() {
  curl -fsS "$PAPERCLIP_API_URL/api/agents/me/inbox-lite" \
    -H "Authorization: Bearer $PAPERCLIP_API_KEY"
}

build_report_text() {
  local inbox_json="$1"

  INBOX_JSON="$inbox_json" REPORT_MAX_ITEMS="$REPORT_MAX_ITEMS" python3 - <<'PY'
import json
import os
from collections import Counter
from datetime import datetime
from zoneinfo import ZoneInfo

max_items = int(os.environ.get("REPORT_MAX_ITEMS", "6"))
inbox = json.loads(os.environ["INBOX_JSON"])

status_counter = Counter(item.get("status", "unknown") for item in inbox)
status_order = ["in_progress", "todo", "blocked", "in_review", "done", "backlog", "cancelled"]

now = datetime.now(ZoneInfo("Asia/Jakarta")).strftime("%d-%m-%Y %H:%M WIB")

lines = [
    "Atlas Daily Report",
    f"Waktu: {now}",
    f"Total assignment: {len(inbox)}",
    "",
    "Ringkasan status:",
]

for key in status_order:
    if key in status_counter:
        lines.append(f"- {key}: {status_counter[key]}")

remaining_keys = sorted(set(status_counter.keys()) - set(status_order))
for key in remaining_keys:
    lines.append(f"- {key}: {status_counter[key]}")

if inbox:
    lines.append("")
    lines.append(f"Top {min(max_items, len(inbox))} item prioritas:")
    for item in inbox[:max_items]:
        identifier = item.get("identifier", "-")
        title = item.get("title", "(tanpa judul)")
        status = item.get("status", "unknown")
        priority = item.get("priority", "unknown")
        lines.append(f"- {identifier} [{status}/{priority}] {title}")

print("\n".join(lines))
PY
}

send_telegram() {
  local text="$1"
  curl -fsS "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${text}" \
    --data-urlencode "disable_web_page_preview=true" > /dev/null
}

main() {
  log "INFO" "Mulai job laporan harian Telegram"

  require_var PAPERCLIP_API_URL
  require_var PAPERCLIP_API_KEY

  local inbox_json
  if ! inbox_json="$(fetch_assignments_json)"; then
    log "ERROR" "Gagal mengambil data assignment dari Paperclip API"
    return 1
  fi

  local report_text
  report_text="$(build_report_text "$inbox_json")"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "INFO" "DRY_RUN=1 aktif. Pengiriman Telegram dilewati"
    printf '%s\n\n%s\n' '----- REPORT PREVIEW -----' "$report_text" | tee -a "$LOG_FILE"
    return 0
  fi

  require_var TELEGRAM_BOT_TOKEN
  require_var TELEGRAM_CHAT_ID

  local attempt=1
  while (( attempt <= RETRY_MAX_ATTEMPTS )); do
    if send_telegram "$report_text"; then
      log "INFO" "Laporan berhasil dikirim ke Telegram (attempt $attempt/$RETRY_MAX_ATTEMPTS)"
      return 0
    fi

    log "WARN" "Gagal kirim Telegram (attempt $attempt/$RETRY_MAX_ATTEMPTS), retry dalam ${RETRY_DELAY_SEC}s"
    sleep "$RETRY_DELAY_SEC"
    ((attempt++))
  done

  log "ERROR" "Pengiriman Telegram gagal setelah $RETRY_MAX_ATTEMPTS percobaan"
  return 1
}

main "$@"
