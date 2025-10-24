#!/usr/bin/env bash
# setup_container_core.sh
# Evenly divide available CPU cores across listed containers using `docker update --cpuset-cpus`.
# Also save the schedule to a file in the current folder.

set -euo pipefail

########################################
# 1) EDIT THIS LIST
########################################
containers=(
  nginx_new
  vsack_nginx_rate
  vsack_nginx_waf
  vsack_nginx_disable
  vsack_nginx_log
  vsack_nginx_ssl
  sqlite
  vsack_proftpd
  vsack_proftpd_limit
  vsack_proftpd_user_permission
  vsack_sudo_log
  vsack_sudo_approve
  sudo-eval
  apache-eval-auth
  apache-eval-waf
  apache-eval-post
  apache-eval-log
  apache-eval-select
  # add more names here...
)

########################################
# 2) CONFIG (optional)
########################################
START_CORE="${START_CORE:-0}"
CORE_LIST="${CORE_LIST:-}"
DRY_RUN="${DRY_RUN:-0}"
SCHEDULE_FILE="./container_core_schedule.txt"


########################################
# Helpers
########################################
die() { echo "ERROR: $*" >&2; exit 1; }
have_docker() { command -v docker >/dev/null 2>&1; }
container_exists() { docker inspect "$1" >/dev/null 2>&1; }

update_container() {
  local name="$1"
  local cpus="$2"
  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] docker update --cpuset-cpus=\"$cpus\" \"$name\""
  else
    docker update --cpuset-cpus="$cpus" "$name"
    echo "Pinned $name -> CPUs: $cpus"
  fi
}

compress_core_list() {
  local -a nums=("$@")
  local out=""
  local start=""
  local prev=""

  for n in "${nums[@]}"; do
    if [ -z "$start" ]; then
      start="$n"; prev="$n"
      continue
    fi
    if (( n == prev + 1 )); then
      prev="$n"
    else
      if [ -n "$out" ]; then out+=","; fi
      if [ "$start" = "$prev" ]; then
        out+="$start"
      else
        out+="$start-$prev"
      fi
      start="$n"; prev="$n"
    fi
  done

  if [ -n "$start" ]; then
    if [ -n "$out" ]; then out+=","; fi
    if [ "$start" = "$prev" ]; then
      out+="$start"
    else
      out+="$start-$prev"
    fi
  fi
  printf "%s" "$out"
}

########################################
# Main
########################################
have_docker || die "Docker not found in PATH."

# Build the list of available cores
cores=()
if [ -n "$CORE_LIST" ]; then
  IFS=',' read -r -a cores <<<"$CORE_LIST"
  tmp=()
  for c in "${cores[@]}"; do
    c="$(echo "$c" | tr -d '[:space:]')"
    if [[ "$c" =~ ^[0-9]+-[0-9]+$ ]]; then
      IFS='-' read -r a b <<<"$c"
      for ((i=a; i<=b; i++)); do tmp+=("$i"); done
    elif [[ "$c" =~ ^[0-9]+$ ]]; then
      tmp+=("$c")
    else
      die "Invalid core entry: $c"
    fi
  done
  cores=("${tmp[@]}")
else
  total="$(nproc)"
  for ((i=START_CORE; i<total; i++)); do
    cores+=("$i")
  done
fi

IFS=$'\n' read -r -d '' -a cores < <(printf "%s\n" "${cores[@]}" | awk '!seen[$0]++' | sort -n && printf '\0')

num_containers="${#containers[@]}"
num_cores="${#cores[@]}"

[ "$num_containers" -gt 0 ] || die "Container list is empty."
[ "$num_cores" -gt 0 ] || die "No CPU cores available."
[ "$num_cores" -ge "$num_containers" ] || die "Not enough cores ($num_cores) for $num_containers containers."

echo "Distributing $num_cores cores among $num_containers containers."
[ "$DRY_RUN" = "1" ] && echo "DRY-RUN is enabled."

base=$(( num_cores / num_containers ))
rem=$(( num_cores % num_containers ))

offset=0
: >"$SCHEDULE_FILE"  # clear schedule file
echo "Container CPU assignment schedule:" >>"$SCHEDULE_FILE"

for idx in "${!containers[@]}"; do
  cname="${containers[$idx]}"
  size="$base"
  if (( idx < rem )); then
    size=$(( base + 1 ))
  fi

  slice=()
  for ((k=0; k<size; k++)); do
    slice+=("${cores[$((offset+k))]}")
  done
  offset=$(( offset + size ))

  if ! container_exists "$cname"; then
    echo "WARN: Container '$cname' not found (skipping)."
    continue
  fi

  cpus_str="$(compress_core_list "${slice[@]}")"
  update_container "$cname" "$cpus_str"

  # write to schedule file
  echo "$cname -> $cpus_str" >>"$SCHEDULE_FILE"
done

echo "Schedule written to $SCHEDULE_FILE"