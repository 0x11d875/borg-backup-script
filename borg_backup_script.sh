#!/usr/bin/env bash
set -uo pipefail



# DO NOT implement here! gets overwrite in config!
pre_backup() {
  :
}
# DO NOT implement here! gets overwrite in config!
post_backup() {
  :
}


CONF="/etc/borg-backup.conf"
[[ -r "$CONF" ]] || { echo "Config not found: $CONF" >&2; exit 2; }

source "$CONF"

now() { date '+%Y-%m-%d_%H:%M:%S'; }
REPO="ssh://${USERNAME}@${BORG_DOMAIN}:${BORG_PORT}/${BORG_REPO_PATH}"



EXCLUDE_OPTS=()
if [[ -v EXCLUDE_PATTERNS ]]; then
  for pat in "${EXCLUDE_PATTERNS[@]}"; do
    [[ -n "$pat" ]] || continue
    EXCLUDE_OPTS+=(--exclude "$pat")
  done
fi



require_cfg() {
  local k
  for k in USERNAME BORG_DOMAIN BORG_REPO_PATH; do
    [[ -n "${!k:-}" ]] || { echo "Config error: $k empty" >&2; exit 2; }
  done

  # INCLUDE_PATHS must be set
  if [[ ${INCLUDE_PATHS+x} != x ]]; then
    echo "Config error: INCLUDE_PATHS not set" >&2
    exit 2
  fi

  # and non-empty
  if ((${#INCLUDE_PATHS[@]} == 0)); then
    echo "Config error: INCLUDE_PATHS empty" >&2
    exit 2
  fi
}



ensure_repo() {
  if ! borg list "--${BORG_LOGLEVEL}" "$REPO" >/dev/null 2>&1; then
    echo "[$(now)] repo missing, init"
    borg init "--${BORG_LOGLEVEL}" --encryption=repokey "$REPO"
    borg key export --paper "$REPO" || true
  fi
}



do_backup() {
  echo "RUN: borg create username=${USERNAME},borg_domain=${BORG_DOMAIN},borg_port=${BORG_PORT},borg_repo=${BORG_REPO_PATH}"
  pre_backup
  require_cfg
  ensure_repo
  local archive; archive="$(date '+%Y-%m-%d_%H:%M:%S')"
  local create_opts=( "--${BORG_LOGLEVEL}" -s --show-rc --verbose -C lz4 )
  [[ "${PROGRESS}" == "yes" ]] && create_opts+=(--progress)
  borg create --exclude-caches "${create_opts[@]}" "${EXCLUDE_OPTS[@]}" "${REPO}::${archive}" "${INCLUDE_PATHS[@]}";
  prune
  compact
  yield_check
  post_backup
  echo "RUN: done"
}



prune()  {
  require_cfg
  echo "RUN: borg prune"
  borg prune -v --list --stats \
    --keep-minutely="${KEEP_MINUTELY}" \
    --keep-hourly="${KEEP_HOURLY}" \
    --keep-daily="${KEEP_DAILY}" \
    --keep-weekly="${KEEP_WEEKLY}" \
    --keep-monthly="${KEEP_MONTHLY}" \
    --keep-yearly="${KEEP_YEARLY}" \
    "$REPO"
}



compact()  {
  require_cfg
  echo "RUN: borg compact"
  borg compact -v "$REPO"
}



yield_check() {
  echo "RUN: borg yield_check"
  require_cfg
  # partial repo check (CRC only, resumes with --max-duration)
  local max_duration="${1:-600}" # use first arg or default value 600 in seconds
  echo "RUN: borg check --repository-only --max-duration $max_duration $REPO"
  borg check --repository-only --max-duration "$max_duration" "$REPO"
}



full_check() {
  echo "RUN: borg full_check"
  require_cfg
  # e.g. monthly full check with cryptographic data verification (slow)
  echo "RUN: borg check --verbose --verify-data $REPO"
  borg check --verbose --verify-data "$REPO"
}



repo_list()  { require_cfg; borg list "--${BORG_LOGLEVEL}" "$REPO"; }
repo_info()  { require_cfg; borg info "--${BORG_LOGLEVEL}" "$REPO"; }



mount_repo() {
  require_cfg
  local mnt="/tmp/borg_mount"
  echo "Mounting backups at ${mnt}"
  mkdir -p "$mnt"
  borg mount "--${BORG_LOGLEVEL}" "$REPO" "$mnt"
}



umount_repo() {
  local mnt="/tmp/borg_mount"
  borg umount "--${BORG_LOGLEVEL}" "$mnt" || true
  rmdir "$mnt" || true
  echo "Umounted and removed ${mnt}"
}



diff_archives() {
  require_cfg
  local a1="${1:-}"; local a2="${2:-}"
  [[ -n "$a1" && -n "$a2" ]] || { echo "Usage: $0 diff <ARCHIVE1> <ARCHIVE2|PATH>" >&2; exit 2; }
  borg diff "${REPO}::${a1}" "${a2}"
}



break_lock() { require_cfg; borg break-lock "$REPO"; }



usage() { echo "Usage: $0 {backup|list|info|mount|umount|diff|break-lock|compact|prune}"; }




main() {
  case "${1:-}" in
    backup) do_backup ;;
    list) repo_list ;;
    info) repo_info ;;
    prune) prune ;;
    compact) compact ;;
    mount) mount_repo ;;
    umount) umount_repo ;;
    diff) shift; diff_archives "$@" ;;
    break-lock) break_lock ;;
    *) usage; exit 2 ;;
  esac
}
main "$@"
