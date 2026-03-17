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
SERVER_BOOTSTRAP_MODE="${SERVER_BOOTSTRAP_MODE:-auto}"
SERVER_BOOTSTRAP_SAVE_SLOT="${SERVER_BOOTSTRAP_SAVE_SLOT:-}"
SERVER_EXTRA_COMMANDS="${SERVER_EXTRA_COMMANDS:-}"
ENABLE_EXOGENESIS="${ENABLE_EXOGENESIS:-false}"
EXOGENESIS_COMMIT="${EXOGENESIS_COMMIT:-f173a5b34e4133f0a9bdfdedb1d75b9e01501269}"
EXOGENESIS_URL="${EXOGENESIS_URL:-https://codeload.github.com/AureusStratus/ExoGenesis/tar.gz/${EXOGENESIS_COMMIT}}"
EXOGENESIS_SHA256="${EXOGENESIS_SHA256:-bcb5861821e118e799dd2a79c419782984148a8b57f8c15f8da7e3c8504e1827}"
ENABLE_NEW_HORIZON="${ENABLE_NEW_HORIZON:-false}"
NEW_HORIZON_VERSION="${NEW_HORIZON_VERSION:-2.0_v154_1}"
NEW_HORIZON_URL="${NEW_HORIZON_URL:-https://github.com/Yuria-Shikibe/NewHorizonMod/releases/download/2.0_v154_1/NewHorizonMod.2.0_v154_1.jar}"
NEW_HORIZON_SHA256="${NEW_HORIZON_SHA256:-052545941e5a306b2ca03cb80e90d4138efc4d78db21c44138dd55e5830d0003}"
JAVA_OPTS="${JAVA_OPTS:--Xms512m -Xmx2G}"

SERVER_ROOT_DIR="$(pwd)"
SERVER_DATA_DIR="${SERVER_ROOT_DIR}/config"
SERVER_MODS_DIR="${SERVER_DATA_DIR}/mods"
SERVER_MAPS_DIR="${SERVER_DATA_DIR}/maps"
SERVER_SAVES_DIR="${SERVER_DATA_DIR}/saves"
SERVER_SEED_SAVES_DIR="/opt/mindustry-seeds/saves"

mkdir -p "$SERVER_DATA_DIR"
mkdir -p "$SERVER_MODS_DIR"
mkdir -p "$SERVER_MAPS_DIR"
mkdir -p "$SERVER_SAVES_DIR"

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
      mod_file="${SERVER_MODS_DIR}/NewHorizonMod.${NEW_HORIZON_VERSION}.jar"
      patch_marker="${SERVER_MODS_DIR}/.new-horizon-${NEW_HORIZON_VERSION}.headless-patched"
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

install_exogenesis() {
  enabled="$(printf '%s' "$ENABLE_EXOGENESIS" | tr '[:upper:]' '[:lower:]')"
  case "$enabled" in
    true|1|yes|on)
      mod_dir="${SERVER_MODS_DIR}/exogenesis"
      marker_file="${mod_dir}/.installed-commit"
      tmp_root="/tmp/exogenesis-install"
      tmp_archive="${tmp_root}/exogenesis.tar.gz"
      tmp_dir="${SERVER_MODS_DIR}/.exogenesis-tmp"

      if [ -f "$marker_file" ] && [ -f "${mod_dir}/mod.json" ] && [ "$(cat "$marker_file")" = "$EXOGENESIS_COMMIT" ]; then
        echo "Exogenesis already installed: ${mod_dir}"
        return
      fi

      rm -rf "$tmp_root" "$tmp_dir"
      mkdir -p "$tmp_root" "$tmp_dir"

      echo "Downloading Exogenesis ${EXOGENESIS_COMMIT}..."
      curl -fsSL "$EXOGENESIS_URL" -o "$tmp_archive"
      echo "${EXOGENESIS_SHA256}  ${tmp_archive}" | sha256sum -c -

      tar -xzf "$tmp_archive" -C "$tmp_dir" --strip-components=1
      printf '%s\n' "$EXOGENESIS_COMMIT" > "$tmp_dir/.installed-commit"

      rm -rf "$mod_dir"
      mv "$tmp_dir" "$mod_dir"
      rm -rf "$tmp_root"

      echo "Installed Exogenesis: ${mod_dir}"
      ;;
    false|0|no|off)
      ;;
    *)
      echo "Invalid boolean value: $ENABLE_EXOGENESIS" >&2
      exit 1
      ;;
  esac
}

seed_save_files() {
  if [ ! -d "$SERVER_SEED_SAVES_DIR" ]; then
    return
  fi

  found_seed_file=false

  for seed_file in "$SERVER_SEED_SAVES_DIR"/*.msav; do
    if [ ! -e "$seed_file" ]; then
      continue
    fi

    found_seed_file=true
    target_file="${SERVER_SAVES_DIR}/$(basename "$seed_file")"

    if [ -f "$target_file" ]; then
      continue
    fi

    cp "$seed_file" "$target_file"
    echo "Seeded save file: ${target_file}"
  done

  if [ "$found_seed_file" = true ]; then
    echo "Seed save directory detected: ${SERVER_SEED_SAVES_DIR}"
  fi
}

has_autosave() {
  for autosave_file in "$SERVER_SAVES_DIR"/auto_*.msav; do
    if [ -e "$autosave_file" ]; then
      return 0
    fi
  done

  return 1
}

resolve_bootstrap_save_slot() {
  if [ -n "$SERVER_BOOTSTRAP_SAVE_SLOT" ]; then
    target_save="${SERVER_SAVES_DIR}/${SERVER_BOOTSTRAP_SAVE_SLOT}.msav"

    if [ ! -f "$target_save" ]; then
      echo "Configured bootstrap save slot '${SERVER_BOOTSTRAP_SAVE_SLOT}' was not found at ${target_save}." >&2
      exit 1
    fi

    RESOLVED_BOOTSTRAP_SAVE_SLOT="$SERVER_BOOTSTRAP_SAVE_SLOT"
    return 0
  fi

  seed_count=0
  detected_slot=""

  for seed_file in "$SERVER_SEED_SAVES_DIR"/*.msav; do
    if [ ! -e "$seed_file" ]; then
      continue
    fi

    seed_count=$((seed_count + 1))
    detected_slot="$(basename "$seed_file" .msav)"
  done

  if [ "$seed_count" -eq 1 ]; then
    RESOLVED_BOOTSTRAP_SAVE_SLOT="$detected_slot"
    return 0
  fi

  return 1
}

ensure_builtin_map() {
  map_alias="$1"
  RESOLVED_SERVER_MAP="$map_alias"

  case "$map_alias" in
    Tar_Fields|tarFields|tar-fields|tar_fields)
      map_file="${SERVER_MAPS_DIR}/tarFields.msav"

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
install_exogenesis
seed_save_files

BOOTSTRAP_HANDLED=false
bootstrap_mode="$(printf '%s' "$SERVER_BOOTSTRAP_MODE" | tr '[:upper:]' '[:lower:]')"

case "$bootstrap_mode" in
  auto)
    if has_autosave; then
      append_command "loadautosave"
      BOOTSTRAP_HANDLED=true
      echo "Bootstrap source: latest autosave"
    elif resolve_bootstrap_save_slot; then
      append_command "load $RESOLVED_BOOTSTRAP_SAVE_SLOT"
      BOOTSTRAP_HANDLED=true
      echo "Bootstrap source: save slot ${RESOLVED_BOOTSTRAP_SAVE_SLOT}"
    fi
    ;;
  off|false|0|no)
    ;;
  *)
    echo "Invalid bootstrap mode: $SERVER_BOOTSTRAP_MODE" >&2
    exit 1
    ;;
esac

auto_host="$(printf '%s' "$SERVER_AUTO_HOST" | tr '[:upper:]' '[:lower:]')"
case "$auto_host" in
  true|1|yes|on)
    if [ "$BOOTSTRAP_HANDLED" = false ]; then
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

echo "Using Mindustry data directory: ${SERVER_DATA_DIR}"
echo "Launching Mindustry server with commands: ${START_COMMANDS:-<none>}"

# Intentional word splitting for JAVA_OPTS.
# shellcheck disable=SC2086
set -- java $JAVA_OPTS -jar /opt/mindustry/server-release.jar

if [ -n "${START_COMMANDS:-}" ]; then
  set -- "$@" "$START_COMMANDS"
fi

exec "$@"
