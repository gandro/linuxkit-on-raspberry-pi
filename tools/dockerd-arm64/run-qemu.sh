#!/bin/sh

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

[ -d "${CACHE}" ] || { echo "error: volume ${CACHE} does not exist!"; exit 1; }
[ -f "${CACHE_FILE}" ] || qemu-img create -f qcow2 "${CACHE_FILE}" "${CACHE_SIZE}"
[ -f "${CACHE_SWAP_FILE}" ] || { fallocate -l "${CACHE_SWAP_SIZE}" ${CACHE_SWAP_FILE}; mkswap -L "swap" ${CACHE_SWAP_FILE}; }
[ "${MEM}" -lt "${MEM_LIMIT}" ] || MEM="${MEM_LIMIT}"

exec /usr/bin/qemu-system-aarch64 \
      -smp "${CPUS}" -m `expr "${MEM}" / 1048576` -cpu cortex-a57 -machine virt \
      -kernel "${KERNEL}" -initrd "${INITRD}" \
      -append "${CMDLINE}" \
      -device "virtio-net-pci,netdev=net0" \
      -drive "file=${CACHE_FILE},media=disk" \
      -drive "file=${CACHE_SWAP_FILE},media=disk,format=raw" \
      -netdev "user,id=net0,hostfwd=tcp::${PORT}-:2375" \
      -nographic
