#!/bin/sh
set -o errexit

: ${KERNEL:=/dockerd/dockerd-kernel}
: ${INITRD:=/dockerd/dockerd-initrd.img}
: ${CMDLINE:=`cat /dockerd/dockerd-cmdline`}
: ${CPUS:=`nproc`}
: ${MEM:=2147483648}
: ${MEM_LIMIT:=`cat /sys/fs/cgroup/memory/memory.limit_in_bytes`}
: ${PORT:=2375}
: ${CACHE:=/cache}
: ${CACHE_FILE:="${CACHE}/cache.img"}
: ${CACHE_SIZE:=25G}
: ${CACHE_SWAP_FILE:="${CACHE}/swap.img"}
: ${CACHE_SWAP_SIZE:=4G}
: ${METADATA_ISO:="metadata.iso"}
: ${DOCKER_CONF:="/etc/docker/daemon.json"}

# create metadata iso file for dockerd config
mkdir -p $(dirname "${DOCKER_CONF}")
[ -f "${DOCKER_CONF}" ] || echo '{"bip":"172.19.0.1/16","debug":true}' > "${DOCKER_CONF}"
jq '{"docker":{"entries":{"daemon.json":{"content":tojson}}}}' ${DOCKER_CONF} > /dockerd/config
genisoimage -quiet -output "${METADATA_ISO}" -volid config -joliet -rock /dockerd/config

# configure vm memory and disk resources
[ -d "${CACHE}" ] || { echo "error: volume ${CACHE} does not exist!"; exit 1; }
[ -f "${CACHE_FILE}" ] || qemu-img create -f qcow2 "${CACHE_FILE}" "${CACHE_SIZE}"
[ -f "${CACHE_SWAP_FILE}" ] || { fallocate -l "${CACHE_SWAP_SIZE}" ${CACHE_SWAP_FILE}; mkswap -L "swap" ${CACHE_SWAP_FILE}; }
[ "${MEM}" -lt "${MEM_LIMIT}" ] || MEM="${MEM_LIMIT}"

exec /usr/bin/qemu-system-aarch64 \
      -smp "${CPUS}" -cpu cortex-a57 -machine virt \
      -m `expr "${MEM}" / 1048576` \
      -kernel "${KERNEL}" -initrd "${INITRD}" \
      -append "${CMDLINE}" \
      -object rng-random,id=rng0,filename=/dev/urandom \
      -device virtio-rng-pci,rng=rng0 \
      -device "virtio-net-pci,netdev=net0" \
      -drive "file=${CACHE_FILE},media=disk" \
      -drive "file=${CACHE_SWAP_FILE},media=disk,format=raw" \
      -drive "file=${METADATA_ISO},media=cdrom" \
      -netdev "user,id=net0,hostfwd=tcp::${PORT}-:2375" \
      -nographic
