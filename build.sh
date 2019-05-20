#!/bin/sh
set -eu

: ${IMAGES_REPO:=linuxkitrpi/images}

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

linuxkit_cli() {
  "$(dirname "$0")/scripts/linuxkit-cli.sh" "$@"
}

while getopts "Bps:w:" arg ; do
  case "$arg" in
    "B") build_image="no"; ;;
    "p") push_image="yes"; ;;
    "s") save_dir="$OPTARG"; ;;
    "w") workspace="$OPTARG"; ;;
    "?") fail "usage: $0 [-Bps] [-w workspace] [TARGET]..."
      ;;
  esac
done

shift $((OPTIND - 1))

if [ -n "${workspace:-}" ] ; then
  linuxkit_cli agent start "$workspace"
fi

for path ; do
  unset tag
  case "$path" in
    pkg/*|tools/*)
      tag=$(linuxkit_cli pkg show-tag "$path")
      if [ "${build_image:-yes}" = "yes" ] ; then
        linuxkit_cli pkg build "$path"
      fi
      ;;
    kernel)
      tag=$(linuxkit_cli pkg show-tag "$path")
      if [ "${build_image:-yes}" = "yes" ] ; then
        if [ $(docker version --format '{{.Server.Arch}}') = "arm64" ] ; then
          linuxkit_cli pkg build "$path"
        else
          linuxkit_cli pkg kernel-cross-compile "$path"
        fi
      fi
      ;;
    images/dockerd.yml)
      tag=$(linuxkit_cli yml docker-show-tag "$IMAGES_REPO" "$path")
      if [ "${build_image:-yes}" = "yes" ] ; then
        linuxkit_cli yml docker-build "$IMAGES_REPO" "$path"
      fi
      ;;
    *)
      fail "error: no build instructions for target '$path'"
      ;;
  esac

  if [ -n "${save_dir:-}" ] ; then
    linuxkit_cli save -d "$save_dir" "$tag"
  fi

  if [ "${push_image:-no}" = "yes" ] ; then
    linuxkit_cli push "$tag"
  fi
done
