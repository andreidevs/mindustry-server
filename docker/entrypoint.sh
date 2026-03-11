#!/bin/sh
set -eu

SERVER_NAME="${SERVER_NAME:-Mindustry 155.4 Beta}"
SERVER_DESC="${SERVER_DESC:-Public beta server}"
SERVER_PORT="${SERVER_PORT:-6567}"
SERVER_MODE="${SERVER_MODE:-survival}"
SERVER_MAP="${SERVER_MAP:-Abandoned_Outpost}"
SERVER_AUTO_HOST="${SERVER_AUTO_HOST:-true}"
SERVER_AUTO_PAUSE="${SERVER_AUTO_PAUSE:-true}"
SERVER_STRICT="${SERVER_STRICT:-true}"
SERVER_EXTRA_COMMANDS="${SERVER_EXTRA_COMMANDS:-}"
ENABLE_NEW_HORIZON="${ENABLE_NEW_HORIZON:-false}"
NEW_HORIZON_VERSION="${NEW_HORIZON_VERSION:-2.0_v154_1}"
NEW_HORIZON_URL="${NEW_HORIZON_URL:-https://github.com/Yuria-Shikibe/NewHorizonMod/releases/download/2.0_v154_1/NewHorizonMod.2.0_v154_1.jar}"
NEW_HORIZON_SHA256="${NEW_HORIZON_SHA256:-052545941e5a306b2ca03cb80e90d4138efc4d78db21c44138dd55e5830d0003}"
JAVA_OPTS="${JAVA_OPTS:--Xms512m -Xmx2G}"

mkdir -p /data/config
mkdir -p /data/config/mods
mkdir -p /data/config/maps

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

ensure_file_sha256() {
  file_path="$1"
  expected_sha="$2"

  if [ ! -f "$file_path" ]; then
    return 1
  fi

  echo "${expected_sha}  ${file_path}" | sha256sum -c - >/dev/null 2>&1
}

install_new_horizon() {
  enabled="$(printf '%s' "$ENABLE_NEW_HORIZON" | tr '[:upper:]' '[:lower:]')"
  case "$enabled" in
    true|1|yes|on)
      mod_file="/data/config/mods/NewHorizonMod.${NEW_HORIZON_VERSION}.jar"
      patch_marker="/data/config/mods/.new-horizon-${NEW_HORIZON_VERSION}.headless-patched"
      patch_src="/opt/mindustry-patches/newhorizon/src/newhorizon/content/NHSounds.java"

      patch_new_horizon() {
        workdir="/tmp/newhorizon-headless-patch"
        rm -rf "$workdir"
        mkdir -p "$workdir/out"
        javac --release 8 -cp /opt/mindustry/server-release.jar -d "$workdir/out" "$patch_src"
        (
          cd "$workdir/out"
          jar uf "$mod_file" newhorizon/content/NHSounds.class
        )
        rm -rf "$workdir"
      }

      if [ -f "$mod_file" ] && [ -f "$patch_marker" ]; then
        echo "New Horizon already installed and headless-patched: ${mod_file}"
        return
      fi

      if ensure_file_sha256 "$mod_file" "$NEW_HORIZON_SHA256"; then
        echo "Found official New Horizon jar, applying headless patch..."
      else
        tmp_file="${mod_file}.tmp"
        rm -f "$tmp_file"
        echo "Downloading New Horizon ${NEW_HORIZON_VERSION}..."
        curl -fsSL "$NEW_HORIZON_URL" -o "$tmp_file"
        echo "${NEW_HORIZON_SHA256}  ${tmp_file}" | sha256sum -c -
        mv "$tmp_file" "$mod_file"
        echo "Installed New Horizon upstream jar: ${mod_file}"
      fi

      patch_new_horizon
      rm -f "${mod_file}.tmp" "${mod_file}.orig"
      touch "$patch_marker"
      echo "Applied headless patch to New Horizon: ${mod_file}"
      ;;
    false|0|no|off)
      ;;
    *)
      echo "Invalid boolean value: $ENABLE_NEW_HORIZON" >&2
      exit 1
      ;;
  esac
}

ensure_builtin_map() {
  map_alias="$1"
  RESOLVED_SERVER_MAP="$map_alias"

  case "$map_alias" in
    Tar_Fields|tarFields|tar-fields|tar_fields)
      map_file="/data/config/maps/tarFields.msav"

      if [ ! -f "$map_file" ]; then
        workdir="/tmp/mindustry-map-extract"
        rm -rf "$workdir"
        mkdir -p "$workdir"
        (
          cd "$workdir"
          jar xf /opt/mindustry/server-release.jar maps/serpulo/tarFields.msav
        )
        mv "$workdir/maps/serpulo/tarFields.msav" "$map_file"
        rm -rf "$workdir"
        echo "Extracted built-in campaign map Tar Fields to ${map_file}" >&2
      fi

      # Campaign maps imported from the server jar are registered as custom maps.
      RESOLVED_SERVER_MAP="tarfields"
      return
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

install_new_horizon

auto_host="$(printf '%s' "$SERVER_AUTO_HOST" | tr '[:upper:]' '[:lower:]')"
case "$auto_host" in
  true|1|yes|on)
    if [ -n "$SERVER_MAP" ]; then
      ensure_builtin_map "$SERVER_MAP"
      append_command "host $RESOLVED_SERVER_MAP $SERVER_MODE"
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
