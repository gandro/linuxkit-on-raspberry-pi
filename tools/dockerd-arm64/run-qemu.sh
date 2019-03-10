#!/bin/sh
set -o errexit

: ${KERNEL:=/dockerd/dockerd-kernel}
: ${INITRD:=/dockerd/dockerd-initrd.img}
: ${CMDLINE:=`cat /dockerd/dockerd-cmdline`}
: ${CPUS:=`nproc`}
: ${CPUS_LIMIT:=8}
: ${MEM:=2147483648}
: ${MEM_LIMIT:=`cat /sys/fs/cgroup/memory/memory.limit_in_bytes`}
: ${PORT:=2375}
: ${CACHE:=/cache}
: ${CACHE_FILE:="${CACHE}/cache.img"}
: ${CACHE_SIZE:=25G}
: ${CACHE_SWAP_FILE:="${CACHE}/swap.img"}
: ${CACHE_SWAP_SIZE:=4G}
: ${DOCKER_CONF:="/dockerd/daemon.json"}
: ${DOCKER_CONF_ISO:="dockerconf.iso"}

[ -d "${CACHE}" ] || mkdir -p "${CACHE}"
[ -f "${CACHE_FILE}" ] || qemu-img create -f qcow2 "${CACHE_FILE}" "${CACHE_SIZE}"
[ -f "${CACHE_SWAP_FILE}" ] || { fallocate -l "${CACHE_SWAP_SIZE}" ${CACHE_SWAP_FILE}; mkswap -L "swap" ${CACHE_SWAP_FILE}; }

[ "${MEM}" -lt "${MEM_LIMIT}" ] || MEM="${MEM_LIMIT}"
[ "${CPUS}" -lt "${CPUS_LIMIT}" ] || CPUS="${CPUS_LIMIT}"

genisoimage -quiet -output "${DOCKER_CONF_ISO}" -volid "dockerconf" -joliet -rock "${DOCKER_CONF}"
exec /usr/bin/qemu-system-aarch64 \
      -smp "${CPUS}" -cpu cortex-a57 -machine virt \
      -m `expr "${MEM}" / 1048576` \
      -kernel "${KERNEL}" -initrd "${INITRD}" \
      -append "${CMDLINE}" \
      -device virtio-rng-pci,rng=rng0 \
      -object rng-random,id=rng0,filename=/dev/urandom \
      -drive "file=${CACHE_FILE},media=disk" \
      -drive "file=${CACHE_SWAP_FILE},media=disk,format=raw" \
      -drive "file=${DOCKER_CONF_ISO},media=cdrom" \
      -device "virtio-net-pci,netdev=net0" \
      -netdev "user,id=net0,hostfwd=tcp::${PORT}-:2375" \
      -nographic
