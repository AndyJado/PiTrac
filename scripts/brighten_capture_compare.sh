#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  brighten_capture_compare.sh [OPTIONS] [IMAGE_OR_DIR ...]

Generate three outputs per resolved input image:
  1. original image (unchanged, used in the comparison strip)
  2. brightened image
  3. brightened image with auto-level and contrast stretch
  4. side-by-side comparison strip in the order:
     original | brightened | brightened + contrast

If an argument is a directory, the script uses the newest image in that directory.
If no image or directory is provided, it defaults to the newest image in:
  artifacts/focus_captures

Options:
  -o, --outdir DIR         Output directory. Defaults to each source image directory.
  -b, --brightness VALUE   Brightness percentage for ImageMagick -modulate.
                           Default: 400
  -s, --stretch VALUE      Contrast stretch applied after auto-level.
                           Default: 1%x1%
  -h, --help               Show this help text.

Examples:
  brighten_capture_compare.sh
  brighten_capture_compare.sh artifacts/focus_captures/cam2_auto_20260405_102854_05.jpg
  brighten_capture_compare.sh artifacts/focus_captures
  brighten_capture_compare.sh --brightness 500 --outdir /tmp/probe image.jpg

Notes:
  Requires ImageMagick (`magick` preferred, `convert` accepted as fallback).
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

resolve_magick_cmd() {
  if command -v magick >/dev/null 2>&1; then
    MAGICK_CMD=(magick)
    return 0
  fi

  if command -v convert >/dev/null 2>&1; then
    MAGICK_CMD=(convert)
    return 0
  fi

  die "ImageMagick not found. Install 'magick' and try again."
}

require_numeric() {
  local label="$1"
  local value="$2"

  if [[ ! "${value}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    die "${label} must be a positive number, got: ${value}"
  fi
}

file_mtime() {
  local path="$1"

  if stat -f '%m' "${path}" >/dev/null 2>&1; then
    stat -f '%m' "${path}"
    return 0
  fi

  stat -c '%Y' "${path}"
}

latest_image_in_dir() {
  local dir="$1"
  local latest_file=""
  local latest_mtime=""
  local candidate=""
  local candidate_mtime=""
  local candidate_name=""

  [[ -d "${dir}" ]] || die "Input directory does not exist: ${dir}"

  while IFS= read -r -d '' candidate; do
    candidate_name="$(basename "${candidate}")"

    case "${candidate_name}" in
      *_compare.*|*_edges_probe.*|*_bright*x.*|*_bright*pct.*|*_bright*x_autolevel.*|*_bright*pct_autolevel.*)
        continue
        ;;
    esac

    candidate_mtime="$(file_mtime "${candidate}")" || continue

    if [[ -z "${latest_file}" ]] || (( candidate_mtime > latest_mtime )); then
      latest_file="${candidate}"
      latest_mtime="${candidate_mtime}"
    fi
  done < <(
    find "${dir}" -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.bmp' -o -iname '*.tif' -o -iname '*.tiff' \) \
      -print0
  )

  [[ -n "${latest_file}" ]] || die "No images found in directory: ${dir}"
  printf '%s\n' "${latest_file}"
}

resolve_input_path() {
  local input="$1"

  if [[ -d "${input}" ]]; then
    latest_image_in_dir "${input}"
    return 0
  fi

  [[ -f "${input}" ]] || die "Input image does not exist: ${input}"
  printf '%s\n' "${input}"
}

brightness_tag() {
  local value="$1"

  if [[ "${value}" =~ ^([0-9]+)$ ]] && (( ${BASH_REMATCH[1]} % 100 == 0 )); then
    printf 'bright%dx' "$(( ${BASH_REMATCH[1]} / 100 ))"
    return 0
  fi

  value="${value//./p}"
  printf 'bright%spct' "${value}"
}

process_image() {
  local src="$1"
  local outdir="$2"
  local brightness="$3"
  local stretch="$4"
  local src_dir filename stem extension tag
  local bright_path contrast_path compare_path

  [[ -f "${src}" ]] || die "Input image does not exist: ${src}"

  src_dir="$(cd "$(dirname "${src}")" && pwd)"
  filename="$(basename "${src}")"

  if [[ "${filename}" == *.* ]]; then
    stem="${filename%.*}"
    extension=".${filename##*.}"
  else
    stem="${filename}"
    extension=".jpg"
  fi

  if [[ -z "${outdir}" ]]; then
    outdir="${src_dir}"
  fi

  mkdir -p "${outdir}"

  tag="$(brightness_tag "${brightness}")"
  bright_path="${outdir}/${stem}_${tag}${extension}"
  contrast_path="${outdir}/${stem}_${tag}_autolevel${extension}"
  compare_path="${outdir}/${stem}_compare${extension}"

  "${MAGICK_CMD[@]}" "${src}" \
    -modulate "${brightness},100,100" \
    -quality 95 \
    "${bright_path}"

  "${MAGICK_CMD[@]}" "${src}" \
    -modulate "${brightness},100,100" \
    -auto-level \
    -contrast-stretch "${stretch}" \
    -quality 95 \
    "${contrast_path}"

  "${MAGICK_CMD[@]}" \
    \( "${src}" -bordercolor white -border 1 \) \
    \( "${bright_path}" -bordercolor white -border 1 \) \
    \( "${contrast_path}" -bordercolor white -border 1 \) \
    +append \
    -quality 95 \
    "${compare_path}"

  printf 'source: %s\n' "${src}"
  printf 'bright: %s\n' "${bright_path}"
  printf 'bright+contrast: %s\n' "${contrast_path}"
  printf 'compare: %s\n' "${compare_path}"
}

main() {
  local script_dir repo_root default_input_dir
  local outdir=""
  local brightness="400"
  local stretch="1%x1%"
  local images=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -o|--outdir)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        outdir="$2"
        shift 2
        ;;
      -b|--brightness)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        brightness="$2"
        shift 2
        ;;
      -s|--stretch)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        stretch="$2"
        shift 2
        ;;
      --)
        shift
        while [[ $# -gt 0 ]]; do
          images+=("$1")
          shift
        done
        ;;
      -*)
        die "Unknown option: $1"
        ;;
      *)
        images+=("$1")
        shift
        ;;
    esac
  done

  require_numeric "brightness" "${brightness}"
  resolve_magick_cmd

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "${script_dir}/.." && pwd)"
  default_input_dir="${repo_root}/artifacts/focus_captures"

  if [[ ${#images[@]} -eq 0 ]]; then
    images+=("${default_input_dir}")
  fi

  local image resolved_image
  for image in "${images[@]}"; do
    resolved_image="$(resolve_input_path "${image}")"
    process_image "${resolved_image}" "${outdir}" "${brightness}" "${stretch}"
  done
}

main "$@"
