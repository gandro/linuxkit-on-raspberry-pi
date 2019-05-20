#!/bin/sh
set -eu

: ${DOCKER_HOST:=unix://var/run/docker.sock}

: ${LINUXKIT_PKG_FLAGS:=-disable-content-trust}
: ${LINUXKIT_BUILD_FLAGS:=-disable-content-trust}

: ${AGENT_IMAGE:=linuxkitrpi/linuxkit-cli}
: ${AGENT_TAG:=e0211387a0107f46ba5571cce2da2490a5049f9c}
: ${AGENT_CONTAINER_NAME:=linuxkit-cli-agent}

: ${MKIMAGE_RPI3_SQUASHFS_IMAGE:=linuxkitrpi/mkimage-squashfs}
: ${MKIMAGE_RPI3_SQUASHFS_TAG:=a095a0cd5c879e7ac0b7ecee62ca60a394fa22c7}


fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
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

docker_manifest_set_arch() {
  _layers=$(mktemp -d "${TMPDIR:-/tmp}/layers.XXXXXXXXX")
  docker save "$1" | tar -C "$_layers" -x

  # HACK: replace architecture in all json files
  find "$_layers" -type f \( -name 'json' -o -name '*.json' \) | \
    while read -r file
  do
    manifest=$(mktemp)
    cat "$file" | docker run --interactive --rm "${AGENT_IMAGE}:${AGENT_TAG}" \
      jq --arg arch "$2" '(select(.architecture) | .architecture=$arch)? // .' \
      > "$manifest" && mv "$manifest" "$file"
  done

  # replace image in local image store
  tar -C "$_layers" -c . | docker load
  rm -rf "$_layers"
}

docker_manifest_exists() {
  _agent=$(agent_id)
  docker exec "$_agent" manifest-tool inspect "$1" 2>&1 >/dev/null
}

agent_start() {
  if [ $# -lt 1 ] || ! [ -d "$1" ] ; then
    fail "usage: $0 agent start WORKSPACE"
  fi

  if ! [ -d "$1/.git" ] ; then
    fail "workspace directory must be a git repository"
  fi

  # spawn a 'linuxkit-cli' contaner
  printf "Starting agent '%s'\n" "${AGENT_CONTAINER_NAME}" 2>&1
  _agent=$(docker run $(docker_context_forward) \
    --detach --interactive --tty --rm \
    --volume /workspace --workdir /workspace \
    --name "$AGENT_CONTAINER_NAME" \
    "${AGENT_IMAGE}:${AGENT_TAG}" cat)

  # copy docker certs
  if [ -d "${DOCKER_CERT_PATH:-}" ] ; then
    docker exec "$_agent" mkdir -p "$(dirname $DOCKER_CERT_PATH)"
    docker cp "$DOCKER_CERT_PATH" "${_agent}:${DOCKER_CERT_PATH}"
  fi

  # copy docker config
  if [ -e ~/.docker/config.json ]; then
    docker exec "$_agent" mkdir -p /root/.docker/
    docker cp  ~/.docker/config.json "${_agent}:/root/.docker/"
  fi

  # copy workspace
  printf "Sending workspace directory '%s' to agent\n" "$1" 2>&1
  docker cp "${1}/." "${_agent}:/workspace"
}

agent_stop() {
  _agent=$(agent_id)
  docker stop "$_agent" >/dev/null
}

agent_id() {
    _id=$(docker ps --quiet --filter "name=$AGENT_CONTAINER_NAME")
    if [ -z "$_id" ] ; then
        fail "agent container '$AGENT_CONTAINER_NAME' is not running"
    else
        printf "%s\n" "$_id"
    fi
}

agent() {
  if [ $# -lt 1 ] ; then
    fail "usage: $0 agent [id|start|stop]"
  fi

  case "$1" in
    id)
      agent_id ;;
    start)
      shift 1
      agent_start "$@" ;;
    stop)
      agent_stop ;;
    *)
      fail "'$1' is not a valid subcommand" ;;
  esac
}

pkg_build() {
  if [ $# -lt 1 ] ; then
    fail "usage: $0 pkg build PATH"
  fi

  _agent=$(agent_id)
  docker exec --tty "$_agent" linuxkit pkg build $LINUXKIT_PKG_FLAGS "$@"
}

pkg_show_tag() {
  if [ $# -lt 1 ] ; then
    fail "usage: $0 pkg show-tag PATH"
  fi

  _agent=$(agent_id)
  docker exec "$_agent" linuxkit pkg show-tag $LINUXKIT_PKG_FLAGS "$@"
}

pkg_kernel_cross_compile() {
  if [ $# -lt 1 ] ; then
    fail "usage: $0 pkg kernel-cross-compile PATH"
  fi

  _agent=$(agent_id)
  _tag="$(pkg_show_tag "$1")"
  _arch_tag="${_tag}-arm64"

  if docker_manifest_exists "$_tag" ; then
    printf "image '%s' already exists. skipping build.\n" "$_tag" 2>&1
    return
  fi

  docker exec --tty "$_agent" \
    docker build --tag "${_arch_tag}" --build-arg "AARCH64_CROSS_COMPILE=1" "$1"

  # patch target arch in manifest
  docker_manifest_set_arch "$_arch_tag" "arm64"
  docker tag "$_arch_tag" "$_tag"
}

pkg() {
  if [ $# -lt 2 ]; then
    fail "usage: $0 pkg [build|show-tag|kernel-cross-compile]"
  fi

  _cmd="$1"
  shift 1
  case "$_cmd" in
    build)
      pkg_build "$@" ;;
    show-tag)
      pkg_show_tag "$@" ;;
    kernel-cross-compile)
      pkg_kernel_cross_compile "$@" ;;
    *)
      fail "'$1' is not a valid subcommand" ;;
  esac
}

yml_build() {
  _dir="."
  if getopts "d:" _arg ; then
    case "$_arg" in
      "d") _dir="$OPTARG"; shift 2 ;;
      "?") return 1 ;;
    esac
  fi

  if [ $# -lt 1 ] ; then
    fail "usage: $0 yml build YAML"
  fi

  _agent=$(agent_id)
  _tmpdir=$(docker exec "$_agent" mktemp -d)
  docker exec --interactive "$_agent" \
    linuxkit build $LINUXKIT_BUILD_FLAGS -dir "$_tmpdir" "$@"
  docker cp "${_agent}:${_tmpdir}/." "${_dir}"
  docker exec "$_agent" rm -rf "${_tmpdir}"
}

yml_docker_show_tag() {
  if [ $# != 2 ] ; then
    fail "usage: $0 yml show-tag REPOSITORY YAML"
  fi

  _agent=$(agent_id)
  if ! docker exec "$_agent" test -f "$2" ; then
    fail "yml file must existing inside the workspace"
  fi

  _repo="$1"
  _name="$(basename "${2%.*}")"
  _hash="$(docker exec "$_agent" git hash-object "$2")"

  printf "%s:%s-%s" "$_repo" "$_name" "$_hash"
}

yml_docker_build() {
  if [ $# != 2 ] ; then
    fail "usage: $0 yml docker-build REPOSITORY YAML"
  fi

  _agent=$(agent_id)
  _tag=$(yml_docker_show_tag "$@")-$(docker_arch)
  _tmpdir=$(docker exec "$_agent" mktemp -d)

  docker exec --interactive "$_agent" \
    linuxkit build $LINUXKIT_BUILD_FLAGS \
       -format tar-kernel-initrd -dir "$_tmpdir" -name "build" "$2"

  docker exec "$_agent" docker import "${_tmpdir}/build-initrd.tar" "$_tag"
  docker exec "$_agent" rm -rf "${_tmpdir}"
}

yml_rpi3_squashfs_build() {
  _output="sdcard.img"
  if getopts "o:" _arg ; then
    case "$_arg" in
      "o") _output="$OPTARG"; shift 2 ;;
      "?") return 1 ;;
    esac
  fi

  if [ $# != 1 ] ; then
    fail "usage: $0 yml rpi3-squashfs-build [-o FILE] YAML"
  fi

  _agent=$(agent_id)
  docker exec --interactive "$_agent" \
    linuxkit build $LINUXKIT_BUILD_FLAGS -format tar -o - "$1" | \
    docker run --rm --interactive \
      "${MKIMAGE_RPI3_SQUASHFS_IMAGE}:${MKIMAGE_RPI3_SQUASHFS_TAG}" > "$_output"
}

yml() {
  if [ $# -lt 1 ]; then
    fail \
      "usage: $0 yml [build|docker-show-tag|docker-build|rpi3-squashfs-build]"
  fi

  _cmd="$1"
  shift 1
  case "$_cmd" in
    build)
      yml_build "$@" ;;
    docker-show-tag)
      yml_docker_show_tag "$@" ;;
    docker-build)
      yml_docker_build "$@" ;;
    rpi3-squashfs-build)
      yml_rpi3_squashfs_build "$@" ;;
    *)
      fail "'$_cmd' is not a valid subcommand" ;;
  esac
}

save() {
  _dir="."
  if getopts "d:" _arg; then
    case "$_arg" in
      "d") _dir="$OPTARG"; shift 2 ;;
      "?") return 1
    esac
  fi

  if [ $# != 1 ] ; then
    fail "usage: $0 save [-d] TAG"
  fi

  _targets=""
  _archs=""
  for _arch in amd64 arm64 s390x ; do
    _target="${1}-${_arch}"
    if [ -z "$(docker images -q "$_target")" ] ; then
      printf "image '%s' not found. skipping save.\n" "$_target" 2>&1
    else
      _targets="${_targets} ${_target}"
      _archs="${_archs} ${_arch}"
    fi
  done

  if [ -n "$_targets" ] ; then
    _path="$_dir/$(printf '%s' $1 | tr '/:' '-')$(printf '-%s' $_archs).tar"
    printf "Saving '%s'\n" "$_path"
    mkdir -p "$_dir"
    docker save -o "$_path" $_targets
  fi
}

push() {
  if [ $# != 1 ] ; then
    fail "usage: $0 push TAG"
  fi

  _agent=$(agent_id)

  # make sure to push all arch-specific images
  _tag="$1"
  for _arch in amd64 arm64 s390x ; do
    _target="${_tag}-${_arch}"
    if
      [ -n "$(docker images -q "$_target")" ] && \
      ! docker_manifest_exists "$_target"
    then
      docker push "$_target"
      _update_manifest="yes"
    fi
  done

  # create or update the multiarch manifest 
  if
    [ "${_update_manifest:-no}" = "yes" ] || \
    ! docker_manifest_exists "$_tag"
  then
    docker exec --tty "$_agent" \
      /usr/local/bin/push-manifest.sh "$_tag"
  fi
}

case "${1:-help}" in
  agent|pkg|push|save|yml)
    "$@" ;;
  help)
    printf "usage: $0 SUBCOMMAND\n"
    printf "\n"
    printf "subcommands:\n"
    printf "  agent start or stop build agent container\n"
    printf "  pkg   build packages\n"
    printf "  push  push docker images with multi-arch manifests\n"
    printf "  save  save arch-specific docker images to file\n"
    printf "  yml   build images from yml files\n"
    ;;
  *)
    fail "'$1' is not a valid subcommand" ;;
esac
