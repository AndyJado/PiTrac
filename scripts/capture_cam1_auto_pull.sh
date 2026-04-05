#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  capture_cam1_auto_pull.sh [REMOTE_HOST]
  capture_cam1_auto_pull.sh auto [REMOTE_HOST]
  capture_cam1_auto_pull.sh 25ms [REMOTE_HOST]
  capture_cam1_auto_pull.sh [cam1|cam2] [REMOTE_HOST] [SHOT_COUNT]
  capture_cam1_auto_pull.sh auto [cam1|cam2] [REMOTE_HOST] [SHOT_COUNT]
  capture_cam1_auto_pull.sh 25ms [cam1|cam2] [REMOTE_HOST] [SHOT_COUNT]
  capture_cam1_auto_pull.sh [cam1|cam2] [REMOTE_HOST] --shots SHOT_COUNT
  capture_cam1_auto_pull.sh auto [cam1|cam2] [REMOTE_HOST] --shots SHOT_COUNT
  capture_cam1_auto_pull.sh 25ms [cam1|cam2] [REMOTE_HOST] --shots SHOT_COUNT

Environment:
  REMOTE_USER_HOME   Remote home directory used for LM_Shares and default PiTrac config path
  PITRAC_CONFIG_PATH Remote generated PiTrac config path
                     (default: $REMOTE_USER_HOME/.pitrac/config/generated_golf_sim_config.json)
  TUNING_FILE        Explicit libcamera tuning file. Set to auto to choose based on camera.

Examples:
  capture_cam1_auto_pull.sh
  capture_cam1_auto_pull.sh mzp
  capture_cam1_auto_pull.sh auto
  capture_cam1_auto_pull.sh 25ms
  capture_cam1_auto_pull.sh cam2
  capture_cam1_auto_pull.sh auto cam2
  capture_cam1_auto_pull.sh 25ms cam2
  capture_cam1_auto_pull.sh cam2 mzp
  capture_cam1_auto_pull.sh cam2 5
  capture_cam1_auto_pull.sh auto cam2 mzp 5
  capture_cam1_auto_pull.sh 25ms cam2 mzp 5
  capture_cam1_auto_pull.sh cam2 mzp 5
  capture_cam1_auto_pull.sh cam2 --shots 5
EOF
}

CAMERA_NAME="cam1"
CAMERA_INDEX=0
REMOTE_HOST="mzp"
SHOT_COUNT="${SHOT_COUNT:-1}"
REQUESTED_CAPTURE_MODE=""
REQUESTED_SHUTTER_US=""
REMOTE_HOST_SET=0
SHOT_COUNT_SET=0

parse_camera_arg() {
  case "$1" in
    cam1|camera1|0)
      CAMERA_NAME="cam1"
      CAMERA_INDEX=0
      ;;
    cam2|camera2|1)
      CAMERA_NAME="cam2"
      CAMERA_INDEX=1
      ;;
    *)
      return 1
      ;;
  esac
}

parse_shutter_arg() {
  local raw="$1"
  local value unit

  if [[ "${raw}" =~ ^([1-9][0-9]*)(ms|us)$ ]]; then
    value="${BASH_REMATCH[1]}"
    unit="${BASH_REMATCH[2]}"
  else
    return 1
  fi

  case "${unit}" in
    ms)
      REQUESTED_SHUTTER_US="$(( value * 1000 ))"
      ;;
    us)
      REQUESTED_SHUTTER_US="${value}"
      ;;
    *)
      return 1
      ;;
  esac

  REQUESTED_CAPTURE_MODE="manual"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -n|--shots)
      if [[ $# -lt 2 ]]; then
        printf 'Missing value for %s\n' "$1" >&2
        usage >&2
        exit 1
      fi
      SHOT_COUNT="$2"
      SHOT_COUNT_SET=1
      shift 2
      ;;
    auto)
      REQUESTED_CAPTURE_MODE="auto"
      REQUESTED_SHUTTER_US=""
      shift
      ;;
    cam1|camera1|0|cam2|camera2|1)
      parse_camera_arg "$1"
      shift
      ;;
    *)
      if parse_shutter_arg "$1"; then
        shift
      elif [[ "$1" =~ ^[0-9]+$ ]] && [[ "${SHOT_COUNT_SET}" -eq 0 ]]; then
        SHOT_COUNT="$1"
        SHOT_COUNT_SET=1
        shift
      elif [[ "${REMOTE_HOST_SET}" -eq 0 ]]; then
        REMOTE_HOST="$1"
        REMOTE_HOST_SET=1
        shift
      else
        usage >&2
        exit 1
      fi
      ;;
  esac
done

if ! [[ "${SHOT_COUNT}" =~ ^[1-9][0-9]*$ ]]; then
  printf 'SHOT_COUNT must be a positive integer, got: %s\n' "${SHOT_COUNT}" >&2
  exit 1
fi

REMOTE_USER_HOME="${REMOTE_USER_HOME:-/home/mzp}"
PITRAC_CONFIG_PATH="${PITRAC_CONFIG_PATH:-${REMOTE_USER_HOME}/.pitrac/config/generated_golf_sim_config.json}"
TUNING_FILE="${TUNING_FILE:-auto}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_DIR="${REPO_ROOT}/artifacts/focus_captures"
STAMP="$(date +%Y%m%d_%H%M%S)"
REMOTE_DIR="${REMOTE_USER_HOME}/LM_Shares/Images/script_auto_${CAMERA_NAME}_${STAMP}"

mkdir -p "${LOCAL_DIR}"

ssh "${REMOTE_HOST}" \
  "CAMERA_INDEX=${CAMERA_INDEX}" \
  "CAMERA_NAME=${CAMERA_NAME}" \
  "REMOTE_DIR=${REMOTE_DIR}" \
  "SHOT_COUNT=${SHOT_COUNT}" \
  "REQUESTED_CAPTURE_MODE=${REQUESTED_CAPTURE_MODE}" \
  "REQUESTED_SHUTTER_US=${REQUESTED_SHUTTER_US}" \
  "PITRAC_CONFIG_PATH=${PITRAC_CONFIG_PATH}" \
  "TUNING_FILE=${TUNING_FILE}" \
  bash -s <<'EOF'
set -euo pipefail

is_valid_gain() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

is_valid_shutter() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

resolve_tuning_file() {
  if [[ -n "${TUNING_FILE}" ]] && [[ "${TUNING_FILE}" != "auto" ]]; then
    printf '%s\n' "${TUNING_FILE}"
    return 0
  fi

  local model ipa_dir
  model="$(tr -d '\0' < /sys/firmware/devicetree/base/model 2>/dev/null || true)"

  case "${model}" in
    *"Raspberry Pi 4"*)
      ipa_dir="/usr/share/libcamera/ipa/rpi/vc4"
      ;;
    *)
      ipa_dir="/usr/share/libcamera/ipa/rpi/pisp"
      ;;
  esac

  if [[ "${CAMERA_NAME}" == "cam1" ]]; then
    printf '%s\n' "${ipa_dir}/imx296.json"
  else
    printf '%s\n' "${ipa_dir}/imx296_noir.json"
  fi
}

load_pitrac_capture_settings() {
  if ! command -v python3 >/dev/null 2>&1; then
    return 1
  fi

  if [[ ! -f "${PITRAC_CONFIG_PATH}" ]]; then
    return 1
  fi

  python3 - "${PITRAC_CONFIG_PATH}" "${CAMERA_NAME}" <<'PY'
import json
import sys

config_path = sys.argv[1]
camera_name = sys.argv[2]

gain_key = "kCamera1Gain" if camera_name == "cam1" else "kCamera2Gain"
shutter_key = "kCamera1StillShutterTimeuS" if camera_name == "cam1" else "kCamera2StillShutterTimeuS"

with open(config_path, "r", encoding="utf-8") as handle:
    config = json.load(handle)

cameras = config.get("gs_config", {}).get("cameras", {})
gain = cameras.get(gain_key)
shutter = cameras.get(shutter_key)

if gain is None or shutter is None:
    sys.exit(1)

print(f"CAMERA_GAIN={gain}")
print(f"CAMERA_SHUTTER_US={shutter}")
PY
}

CAPTURE_MODE="auto"
CAPTURE_NOTE="PiTrac config unavailable; falling back to auto exposure"
CAMERA_GAIN=""
CAMERA_SHUTTER_US=""
RESOLVED_TUNING_FILE="$(resolve_tuning_file)"

if [[ "${REQUESTED_CAPTURE_MODE:-}" == "auto" ]]; then
  CAPTURE_NOTE="Forced auto exposure by script argument"
elif [[ "${REQUESTED_CAPTURE_MODE:-}" == "manual" ]]; then
  CAPTURE_MODE="manual"
  CAMERA_SHUTTER_US="${REQUESTED_SHUTTER_US}"
  CAPTURE_NOTE="Forced shutter ${CAMERA_SHUTTER_US}us by script argument"

  capture_settings="$(load_pitrac_capture_settings 2>/dev/null || true)"
  if [[ -n "${capture_settings}" ]]; then
    while IFS='=' read -r key value; do
      case "${key}" in
        CAMERA_GAIN)
          CAMERA_GAIN="${value}"
          ;;
      esac
    done <<< "${capture_settings}"

    if is_valid_gain "${CAMERA_GAIN}"; then
      CAPTURE_NOTE="Forced shutter ${CAMERA_SHUTTER_US}us by script argument; using PiTrac gain from ${PITRAC_CONFIG_PATH}"
    else
      CAMERA_GAIN=""
      CAPTURE_NOTE="Forced shutter ${CAMERA_SHUTTER_US}us by script argument; PiTrac gain unavailable"
    fi
  else
    CAPTURE_NOTE="Forced shutter ${CAMERA_SHUTTER_US}us by script argument; PiTrac gain unavailable"
  fi
else
  capture_settings="$(load_pitrac_capture_settings 2>/dev/null || true)"
  if [[ -n "${capture_settings}" ]]; then
    while IFS='=' read -r key value; do
      case "${key}" in
        CAMERA_GAIN)
          CAMERA_GAIN="${value}"
          ;;
        CAMERA_SHUTTER_US)
          CAMERA_SHUTTER_US="${value}"
          ;;
      esac
    done <<< "${capture_settings}"

    if is_valid_gain "${CAMERA_GAIN}" && is_valid_shutter "${CAMERA_SHUTTER_US}"; then
      CAPTURE_MODE="pitrac-config"
      CAPTURE_NOTE="Using PiTrac config from ${PITRAC_CONFIG_PATH}"
    else
      CAPTURE_NOTE="PiTrac config values were invalid; falling back to auto exposure"
    fi
  fi
fi

capture_one() {
  local out_file="$1"
  local cmd=(
    timeout 12s
    rpicam-still
    --camera "${CAMERA_INDEX}"
    --nopreview
    --timeout 2000
    --width 1456
    --height 1088
    --denoise cdn_off
    --encoding jpg
    --tuning-file "${RESOLVED_TUNING_FILE}"
  )

  if is_valid_shutter "${CAMERA_SHUTTER_US}"; then
    cmd+=(--shutter "${CAMERA_SHUTTER_US}")
  fi

  if is_valid_gain "${CAMERA_GAIN}"; then
    cmd+=(--gain "${CAMERA_GAIN}")
  fi

  cmd+=(-o "${out_file}")
  "${cmd[@]}"
}

mkdir -p "${REMOTE_DIR}"

if [[ "${SHOT_COUNT}" -eq 1 ]]; then
  capture_one "${REMOTE_DIR}/${CAMERA_NAME}_auto.jpg"
else
  for shot_num in $(seq 1 "${SHOT_COUNT}"); do
    printf -v out_file '%s/%s_auto_%02d.jpg' "${REMOTE_DIR}" "${CAMERA_NAME}" "${shot_num}"
    capture_one "${out_file}"
  done
fi

printf 'Remote capture mode: %s\n' "${CAPTURE_MODE}"
printf 'Remote capture note: %s\n' "${CAPTURE_NOTE}"
printf 'Remote tuning file: %s\n' "${RESOLVED_TUNING_FILE}"
if is_valid_gain "${CAMERA_GAIN}"; then
  printf 'Remote gain: %s\n' "${CAMERA_GAIN}"
fi
if is_valid_shutter "${CAMERA_SHUTTER_US}"; then
  printf 'Remote shutter (us): %s\n' "${CAMERA_SHUTTER_US}"
fi
EOF

for shot_num in $(seq 1 "${SHOT_COUNT}"); do
  if [[ "${SHOT_COUNT}" -eq 1 ]]; then
    REMOTE_OUT="${REMOTE_DIR}/${CAMERA_NAME}_auto.jpg"
    LOCAL_OUT="${LOCAL_DIR}/${CAMERA_NAME}_auto_${STAMP}.jpg"
  else
    printf -v REMOTE_OUT '%s/%s_auto_%02d.jpg' "${REMOTE_DIR}" "${CAMERA_NAME}" "${shot_num}"
    printf -v LOCAL_OUT '%s/%s_auto_%s_%02d.jpg' "${LOCAL_DIR}" "${CAMERA_NAME}" "${STAMP}" "${shot_num}"
  fi

  scp "${REMOTE_HOST}:${REMOTE_OUT}" "${LOCAL_OUT}"
  printf 'Local image: %s\n' "${LOCAL_OUT}"
done

printf 'Camera: %s (index %s)\n' "${CAMERA_NAME}" "${CAMERA_INDEX}"
printf 'Shots: %s\n' "${SHOT_COUNT}"
printf 'Remote dir: %s\n' "${REMOTE_DIR}"
