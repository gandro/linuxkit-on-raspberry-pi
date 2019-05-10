#!/bin/sh
set -eu

: ${BASEDIR:=$(dirname "$0")}
: ${DESTDIR:="${BASEDIR}/build"}
: ${IMAGES_REPO:=linuxkitrpi/images}

: ${DOCKER_HOST:=unix://var/run/docker.sock}

: ${LINUXKIT_CLI_IMAGE:=linuxkitrpi/linuxkit-cli}
: ${LINUXKIT_CLI_TAG:=54ffd7bd1c1d42a9aa0027474720aa2360c45b11}
: ${LINUXKIT_CLI_NAME:=linuxkit-cli}

: ${LINUXKIT_PKG_FLAGS:=-disable-content-trust}
: ${LINUXKIT_BUILD_FLAGS:=-disable-content-trust}

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

docker_init() {
  # check if the docker client is installed
  if ! command -v docker > /dev/null ; then
    fail "$0 requires docker to be installed"
  fi

  # wait for docker server to come up
  while [ -z "$(docker version --format '{{.Server.Version}}' 2>/dev/null)" ] ; do
    sleep 1
  done

  # spawn linuxkit-cli build container
  trap linuxkit_cli_stop EXIT INT HUP QUIT TERM ALRM
  linuxkit_cli_start
}

docker_arch() {
  docker version --format '{{.Server.Arch}}'
}

docker_context_forward() {
  printf ' --env %s' "DOCKER_HOST" \
    "DOCKER_CERT_PATH" "DOCKER_TLS" "DOCKER_TLS_VERIFY"
  case "$DOCKER_HOST" in
    'unix://'*)
      printf ' %s' "--volume" "${DOCKER_HOST#unix:/}:${DOCKER_HOST#unix:/}"
      ;;
    'tcp://'*)
      printf ' %s' "--network" "host"
      ;;
    *)
      fail "unsupported DOCKER_HOST format"
      ;;
  esac
}

docker_save_build() {
  if [ -z "$SAVE_BUILDS" ] ; then
    return
  fi

  # save built image as tar
  local filename="$(printf '%s' $1 | tr '/:' '-').tar"

  if [ -n "$(docker images -q "$1")" ] ; then
    mkdir -p "$DESTDIR"
    docker save -o "${DESTDIR}/${filename}" "$1"
  fi
}

docker_manifest_set_arch() {
  # extract layers in temporary directory
  local layers=$(mktemp -d "${TMPDIR:-/tmp}/layers.XXXXXXXXX")
  docker save "$1" | tar -C "$layers" -x

  # HACK: replace architecture in all json files
  find "$layers" -type f \( -name 'json' -o -name '*.json' \) | \
    while read -r file
  do
    manifest=$(mktemp)
    jq --arg arch "$2" '(select(.architecture) | .architecture=$arch)? // .' \
      "$file" > "$manifest" && mv "$manifest" "$file"
  done

  # replace image in local image store
  tar -C "$layers" -c . | docker load
  rm -rf "$layers"
}

linuxkit_cli_start() {
  # spawn a 'linuxkit-cli' contaner
  local container_id=$(docker run $(docker_context_forward) \
    --detach --interactive --tty --rm \
    --volume /workspace --workdir /workspace \
    --name "$LINUXKIT_CLI_NAME" \
    "${LINUXKIT_CLI_IMAGE}:${LINUXKIT_CLI_TAG}" cat)

  # copy over basedir (excluding destdir)
  tar -c -C "$BASEDIR" --exclude "${DESTDIR#${BASEDIR}/}" . | \
    docker exec -i "$LINUXKIT_CLI_NAME" tar -x

  # copy docker certs
  if [ -d "$DOCKER_CERT_PATH" ] ; then
    docker exec "$LINUXKIT_CLI_NAME" mkdir -p "$(dirname $DOCKER_CERT_PATH)"
    docker cp "$DOCKER_CERT_PATH" "${LINUXKIT_CLI_NAME}:${DOCKER_CERT_PATH}"
  fi

  # set docker config
  if [ -e ~/.docker/config.json ]; then
    docker exec "$LINUXKIT_CLI_NAME" mkdir -p /root/.docker/
    docker cp  ~/.docker/config.json "${LINUXKIT_CLI_NAME}:/root/.docker/"
  fi
}

linuxkit_cli_stop() {
  docker stop "$LINUXKIT_CLI_NAME" >/dev/null
}

linuxkit_pkg_build() {
  docker exec --tty "$LINUXKIT_CLI_NAME" \
    linuxkit pkg build $LINUXKIT_PKG_FLAGS "$@"
}

linuxkit_pkg_show_tag() {
    docker exec "$LINUXKIT_CLI_NAME" \
      linuxkit pkg show-tag $LINUXKIT_PKG_FLAGS "$1"
}

linuxkit_image_build() {
    docker exec "$LINUXKIT_CLI_NAME" \
      linuxkit build $LINUXKIT_BUILD_FLAGS "$@"
}

linuxkit_image_show_tag() {
  local name=$(basename "${1%.*}")
  local hash=$(docker exec "$LINUXKIT_CLI_NAME" git hash-object "$1")

  printf '%s:%s-%s' "${IMAGES_REPO}" "${name}" "${hash}"
}

linuxkit_manifest_inspect() {
  docker exec "$LINUXKIT_CLI_NAME" \
    manifest-tool inspect "$1" 2>/dev/null
}

linuxkit_manifest_push() {
  local tag="$1"
  local update_manifest=""

  # make sure to push any local arch-specific image
  for arch in amd64 arm64 s390x ; do
    local target="${tag}-${arch}"
    if
      [ -n "$(docker images -q "$target")" ] && \
      [ -z "$(linuxkit_manifest_inspect "$target")" ]
    then
      docker push "$target"
      update_manifest="yes"
    fi
  done

  # create or update the multiarch manifest 
  if
    [ -n "$update_manifest" ] || \
    [ -z "$(linuxkit_manifest_inspect "$tag")" ]
  then
    docker exec "$LINUXKIT_CLI_NAME" /usr/local/bin/push-manifest.sh "$tag"
  fi
}

build_pkg() {
  # build package
  linuxkit_pkg_build "$1"

  # save built package as tar file
  local tag=$(linuxkit_pkg_show_tag "$1")-$(docker_arch)
  docker_save_build "${tag}"
}

build_kernel() {
  if [ "$(docker_arch)" = "arm64" ] ; then
    # natively build as a normal package
    build_pkg "$1"
  else
    # cross-compile kernel
    local tag=$(linuxkit_pkg_show_tag "$1")-arm64
    docker build -t "$tag" --build-arg "AARCH64_CROSS_COMPILE=1" "$1"

    # patch target arch in manifest
    docker_manifest_set_arch "$tag" "arm64"

    # save resulting image as tar file
    docker_save_build "${tag}"
  fi
}

build_image() {
  # build yaml file inside linuxkit-cli contianer
  local name=$(basename "${1%.*}")
  local outdir=$(docker exec "$LINUXKIT_CLI_NAME" mktemp -d)
  local outfile="${outdir}/${name}-initrd.tar"
  linuxkit_image_build -format tar-kernel-initrd -name "$name" -dir "$outdir" "$1"

  # create docker image from artifacts
  local tag=$(linuxkit_image_show_tag "$1")-$(docker_arch)
  docker exec "$LINUXKIT_CLI_NAME" docker import "$outfile" "$tag"

  # clean up and save image in build dir
  docker exec "$LINUXKIT_CLI_NAME" rm -rf "$outdir"
  docker_save_build "${tag}"
}

push_pkg() {
  linuxkit_manifest_push "$(linuxkit_pkg_show_tag "$1")"
}

push_kernel() {
  push_pkg "$1"
}

push_image() {
  linuxkit_manifest_push "$(linuxkit_image_show_tag "$1")"
}

SAVE_BUILDS=""
ACTION="build"
while getopts ":hsp" opt; do
  case $opt in
    h)
      printf "Usage: %s [-h] [DIR]...\n" "$0"
      printf "Build packages, images or kernel in the specified DIRs.\n"
      exit 0
      ;;
    s)
      SAVE_BUILDS="yes"
      ;;
    p)
      ACTION="push"
      ;;
    \?)
      fail "Invalid option: -%s\n" "$OPTARG"
      ;;
  esac
done

shift $(($OPTIND - 1))

if [ $# = 0 ] ; then
  fail "no targets specified"
fi

docker_init

for arg ; do
  case "$arg" in
    kernel) ${ACTION}_kernel "$arg" ;;
    images/*) ${ACTION}_image "$arg" ;;
    pkg/*|tools/*) ${ACTION}_pkg "$arg" ;;
    *) fail "invalid target: $arg" ;;
  esac
done
