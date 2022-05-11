#!/usr/bin/env bash

function join_by() {
  local d="$1"
  echo -n "$2"
  shift 2 && printf '%s' "${@/#/$d}"
}

for cmd in docker mktemp; do
  if ! type "$cmd" &>/dev/null; then
    echo "Missing command: $cmd"
    exit 1
  fi
done

SCRIPT_FILE="$(basename ${BASH_SOURCE[0]})"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

function exit_with_help() {
  >&2 echo "Usage: $SCRIPT_FILE [-v|--verbose] <refspec>"
  exit 1
}

args=(
  "v,verbose"
)

short_args=()
long_args=()
for arg in "${args[@]}"; do
  IFS=',' read -ra arg_arr <<< "$arg"
  short_args+=("${arg_arr[0]}")
  long_args+=("${arg_arr[1]}")
done

short_args="$(join_by ',' ${short_args[@]})"
long_args="$(join_by ',' ${long_args[@]})"

options="$(getopt -n "$SCRIPT_FILE" \
  -o="$short_args" \
  --long="$long_args" -- "$@" \
)" || exit_with_help

eval set -- "$options"
while true; do
  # Check if "$1" is set
  [[ "${1:+1}" -ne 1 ]] && break

  # Parameter list ends with "--"
  [[ "$1" == "--" ]] && { shift; break; }

  case "$1" in
    -v|--verbose) opt_verbose=1 ;;
    *) >&2 echo "Unknown arg: $1"; exit_with_help ;;
  esac
  shift
done

if [[ "${1:+1}" -eq 1 ]]; then
  refspec="$1"
  shift
fi

# Check if we have too many parameters
[[ "${1:+1}" -eq 1 ]] && exit_with_help

# Make sure we have a refspec at this point
[[ -z "$refspec" ]] && exit_with_help

iidfile="$(mktemp)"
function cleanup() { rm -rf "$iidfile"; }
trap cleanup EXIT

if [[ -n "$opt_verbose" ]]; then
  docker build "$DIR" \
    --build-arg GIT_CHECKOUT_REF="$refspec" \
    --progress plain \
    --iidfile "$iidfile" >&2 || exit 1
else
  docker build "$DIR" \
    --build-arg GIT_CHECKOUT_REF="$refspec" \
    --progress plain \
    --iidfile "$iidfile" &>/dev/null || {
    >&2 echo "docker build failed"
    exit 1
  }
fi

if [[ ! -f "$iidfile" ]]; then
  echo "Missing iidfile"
  exit 1
fi

image_id="$(cat "$iidfile")"
rm "$iidfile"

image_tag="openwrt-builder-$image_id"
docker tag "$image_id" "$image_tag"

echo "$image_tag"
