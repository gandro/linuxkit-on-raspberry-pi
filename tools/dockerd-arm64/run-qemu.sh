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

[ -d "${CACHE}" ] || { echo "error: volume ${CACHE} does not exist!"; exit 1; }
[ -f "${CACHE_FILE}" ] || qemu-img create -f qcow2 "${CACHE_FILE}" "${CACHE_SIZE}"
[ "${MEM}" -lt "${MEM_LIMIT}" ] || MEM="${MEM_LIMIT}"

exec /usr/bin/qemu-system-aarch64 \
      -smp "${CPUS}" -m `expr "${MEM}" / 1048576` -cpu cortex-a57 -machine virt \
      -kernel "${KERNEL}" -initrd "${INITRD}" \
      -append "${CMDLINE}" \
      -object "rng-random,id=rng0,filename=/dev/urandom" \
      -device "virtio-net-pci,netdev=net0" \
      -drive "file=${CACHE_FILE},media=disk" \
      -netdev "user,id=net0,hostfwd=tcp::${PORT}-:2375" \
      -nographic
