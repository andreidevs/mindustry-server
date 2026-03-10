#!/bin/sh
set -eu

SERVER_NAME="${SERVER_NAME:-Mindustry 155.4 Beta}"
SERVER_DESC="${SERVER_DESC:-Public beta server}"
SERVER_PORT="${SERVER_PORT:-6567}"
SERVER_MODE="${SERVER_MODE:-survival}"
SERVER_MAP="${SERVER_MAP:-}"
SERVER_AUTO_HOST="${SERVER_AUTO_HOST:-true}"
SERVER_AUTO_PAUSE="${SERVER_AUTO_PAUSE:-true}"
SERVER_STRICT="${SERVER_STRICT:-true}"
SERVER_EXTRA_COMMANDS="${SERVER_EXTRA_COMMANDS:-}"
JAVA_OPTS="${JAVA_OPTS:--Xms512m -Xmx2G}"

mkdir -p /data/config

case "$SERVER_NAME" in
  *,*)
    echo "SERVER_NAME must not contain commas." >&2
    exit 1
    ;;
esac

case "$SERVER_DESC" in
  *,*)
    echo "SERVER_DESC must not contain commas." >&2
    exit 1
    ;;
esac

normalize_bool() {
  value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$value" in
    true|1|yes|on)
      printf 'on'
      ;;
    false|0|no|off)
      printf 'false'
      ;;
    *)
      echo "Invalid boolean value: $1" >&2
      exit 1
      ;;
  esac
}

append_command() {
  command="$1"
  if [ -z "$command" ]; then
    return
  fi

  if [ -z "${START_COMMANDS:-}" ]; then
    START_COMMANDS="$command"
  else
    START_COMMANDS="${START_COMMANDS},$command"
  fi
}

append_command "config name $SERVER_NAME"
append_command "config desc $SERVER_DESC"
append_command "config port $SERVER_PORT"
append_command "config autoPause $(normalize_bool "$SERVER_AUTO_PAUSE")"
append_command "config strict $(normalize_bool "$SERVER_STRICT")"

auto_host="$(printf '%s' "$SERVER_AUTO_HOST" | tr '[:upper:]' '[:lower:]')"
case "$auto_host" in
  true|1|yes|on)
    if [ -n "$SERVER_MAP" ]; then
      append_command "host $SERVER_MAP $SERVER_MODE"
    else
      if [ "$SERVER_MODE" != "survival" ]; then
        echo "SERVER_MODE requires SERVER_MAP when mode is not 'survival'." >&2
        exit 1
      fi
      append_command "host"
    fi
    ;;
  false|0|no|off)
    ;;
  *)
    echo "Invalid boolean value: $SERVER_AUTO_HOST" >&2
    exit 1
    ;;
esac

if [ -n "$SERVER_EXTRA_COMMANDS" ]; then
  append_command "$SERVER_EXTRA_COMMANDS"
fi

echo "Launching Mindustry server with commands: ${START_COMMANDS:-<none>}"

# Intentional word splitting for JAVA_OPTS.
# shellcheck disable=SC2086
set -- java $JAVA_OPTS -jar /opt/mindustry/server-release.jar

if [ -n "${START_COMMANDS:-}" ]; then
  set -- "$@" "$START_COMMANDS"
fi

exec "$@"
