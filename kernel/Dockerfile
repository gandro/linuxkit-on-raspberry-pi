FROM linuxkit/alpine:6ed32ba2b29a12b3d75f3d5b9be1b4ac00e7d479 AS kernel-build
RUN apk add \
    argp-standalone \
    automake \
    bash \
    bc \
    binutils-dev \
    bison \
    build-base \
    curl \
    diffutils \
    flex \
    git \
    gmp-dev \
    gnupg \
    installkernel \
    kmod \
    libelf-dev \
    linux-headers \
    mpc1-dev \
    mpfr-dev \
    ncurses-dev \
    openssl \
    openssl-dev \
    patch \
    sed \
    squashfs-tools \
    tar \
    xz \
    xz-dev \
    zlib-dev

ENV KERNEL_COMMIT=3667ae0605bfbed9e25bd48365457632cf660d78
ENV KERNEL_SHA256="b868127a4e8a38d5f9433ddfb7628078a98ffacb042b545e93984f3460d17c8e"
ENV KERNEL_URL=https://github.com/raspberrypi/linux/archive/${KERNEL_COMMIT}.tar.gz

ENV WIREGUARD_VERSION=0.0.20190227
ENV WIREGUARD_SHA256="fcdb26fd2692d9e1dee54d14418603c38fbb973a06ce89d08fbe45292ff37f79"
ENV WIREGUARD_URL=https://git.zx2c4.com/WireGuard/snapshot/WireGuard-${WIREGUARD_VERSION}.tar.xz

ARG AARCH64_CROSS_COMPILE
ENV AARCH64_CROSS_GCC_VERSION=8.3.0
ENV AARCH64_CROSS_GCC_TARGET=linux-musl

# Install AArch64 toolchain for cross-compilation
ENV ARCH=${AARCH64_CROSS_COMPILE:+arm64}
ENV CROSS_COMPILE=${AARCH64_CROSS_COMPILE:+aarch64-${AARCH64_CROSS_GCC_TARGET}-}
RUN if [ -n "${AARCH64_CROSS_COMPILE}" ]; then \
         curl -fsSL "https://more.musl.cc/${AARCH64_CROSS_GCC_VERSION}/$(uname -m)-linux-musl/${CROSS_COMPILE}cross.tgz" | \
         tar -C /usr/local --strip-components=2 --warning=no-unknown-keyword -xz \
    ; fi

# Fetch source
WORKDIR /linux
RUN curl -fsSL -o /linux.tar.gz "${KERNEL_URL}" && \
    echo "${KERNEL_SHA256}  /linux.tar.gz" | sha256sum -c - && \
    tar --strip-components=1 -xzf /linux.tar.gz

# Apply local common patches if present
COPY patches /patches
RUN set -e && \
    if [ -d /patches ]; then \
        for patch in /patches/*.patch; do \
            echo "Applying $patch"; \
            patch -t -F0 -N -u -p1 < "$patch"; \
        done; \
    fi

# enable squashfs (for rootfs) and options recommended by moby's check-config.sh
RUN ./scripts/config --file arch/arm64/configs/bcmrpi3_defconfig \
    --undefine CONFIG_DEVTMPFS_MOUNT \
    --enable CONFIG_SQUASHFS \
    --enable CONFIG_TRANSPARENT_HUGEPAGE \
    --enable CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS \
    --enable CONFIG_TRANSPARENT_HUGE_PAGECACHE \
    --enable CONFIG_NAMESPACES \
    --enable CONFIG_NET_NS \
    --enable CONFIG_PID_NS \
    --enable CONFIG_IPC_NS \
    --enable CONFIG_UTS_NS \
    --enable CONFIG_CGROUPS \
    --enable CONFIG_CGROUP_CPUACCT \
    --enable CONFIG_CGROUP_DEVICE \
    --enable CONFIG_CGROUP_FREEZER \
    --enable CONFIG_CGROUP_SCHED \
    --enable CONFIG_CPUSETS \
    --enable CONFIG_MEMCG \
    --enable CONFIG_KEYS \
    --enable CONFIG_VETH \
    --enable CONFIG_BRIDGE \
    --enable CONFIG_BRIDGE_NETFILTER \
    --enable CONFIG_NF_NAT_IPV4 \
    --enable CONFIG_IP_NF_FILTER \
    --enable CONFIG_IP_NF_TARGET_MASQUERADE \
    --enable CONFIG_NETFILTER_XT_MATCH_ADDRTYPE \
    --enable CONFIG_NETFILTER_XT_MATCH_CONNTRACK \
    --enable CONFIG_NETFILTER_XT_MATCH_IPVS \
    --enable CONFIG_IP_NF_NAT \
    --enable CONFIG_NF_NAT \
    --enable CONFIG_NF_NAT_NEEDED \
    --enable CONFIG_POSIX_MQUEUE \
    --enable CONFIG_USER_NS \
    --enable CONFIG_SECCOMP \
    --enable CONFIG_BPF_SYSCALL \
    --enable CONFIG_CGROUP_BPF \
    --enable CONFIG_CGROUP_PIDS \
    --enable CONFIG_MEMCG_SWAP \
    --enable CONFIG_MEMCG_SWAP_ENABLED \
    --enable CONFIG_MEMCG_KMEM \
    --enable CONFIG_BLK_CGROUP \
    --enable CONFIG_CGROUP_WRITEBACK \
    --enable CONFIG_BLK_DEV_THROTTLING \
    --enable CONFIG_IOSCHED_CFQ \
    --enable CONFIG_CFQ_GROUP_IOSCHED \
    --enable CONFIG_CGROUP_PERF \
    --enable CONFIG_CGROUP_HUGETLB \
    --enable CONFIG_NET_CLS_CGROUP \
    --enable CONFIG_CGROUP_NET_PRIO \
    --enable CONFIG_SOCK_CGROUP_DATA \
    --enable CONFIG_CFS_BANDWIDTH \
    --enable CONFIG_FAIR_GROUP_SCHED \
    --enable CONFIG_RT_GROUP_SCHED \
    --enable CONFIG_IP_NF_TARGET_REDIRECT \
    --enable CONFIG_IP_VS \
    --enable CONFIG_IP_VS_NFCT \
    --enable CONFIG_IP_VS_PROTO_TCP \
    --enable CONFIG_IP_VS_PROTO_UDP \
    --enable CONFIG_IP_VS_RR \
    --enable CONFIG_EXT4_FS \
    --enable CONFIG_EXT4_FS_POSIX_ACL \
    --enable CONFIG_EXT4_FS_SECURITY \
    --enable CONFIG_VXLAN \
    --enable CONFIG_CRYPTO \
    --enable CONFIG_CRYPTO_AEAD \
    --enable CONFIG_CRYPTO_GCM \
    --enable CONFIG_CRYPTO_SEQIV \
    --enable CONFIG_CRYPTO_GHASH \
    --enable CONFIG_XFRM \
    --module CONFIG_XFRM_USER \
    --module CONFIG_XFRM_ALGO \
    --module CONFIG_INET_ESP \
    --module CONFIG_INET_XFRM_MODE_TRANSPORT \
    --enable CONFIG_IPVLAN \
    --enable CONFIG_MACVLAN \
    --module CONFIG_DUMMY \
    --enable CONFIG_NF_NAT_FTP \
    --enable CONFIG_NF_CONNTRACK_FTP \
    --enable CONFIG_NF_NAT_TFTP \
    --enable CONFIG_NF_CONNTRACK_TFTP \
    --module CONFIG_BTRFS_FS \
    --enable CONFIG_BTRFS_FS_POSIX_ACL \
    --enable CONFIG_BLK_DEV_DM \
    --enable CONFIG_DM_THIN_PROVISIONING \
    --enable CONFIG_OVERLAY_FS

RUN mkdir -p /out/

# Kernel config
RUN make bcmrpi3_defconfig

# Kernel
RUN make -j "$(getconf _NPROCESSORS_ONLN)" KCFLAGS="-fno-pie" && \
    cp arch/arm64/boot/Image.gz /out/kernel && \
    cp System.map /out

# WireGuard
RUN curl -fsSL -o /wireguard.tar.xz "${WIREGUARD_URL}" && \
    echo "${WIREGUARD_SHA256}  /wireguard.tar.xz" | sha256sum -c - && \
    tar -C / --one-top-level=wireguard --strip-components=2 -xJf /wireguard.tar.xz "WireGuard-${WIREGUARD_VERSION}/src" && \
    make -j "$(getconf _NPROCESSORS_ONLN)" M="/wireguard" modules

# Modules and Device Tree binaries
RUN make INSTALL_MOD_PATH=/tmp/kernel-modules modules_install && \
    make INSTALL_MOD_PATH=/tmp/kernel-modules M="/wireguard" modules_install && \
    ( DVER=$(basename $(find /tmp/kernel-modules/lib/modules/ -mindepth 1 -maxdepth 1)) && \
    cd /tmp/kernel-modules/lib/modules/$DVER && \
    rm build source && \
    ln -s /usr/src/linux-headers-$DVER build ) && \
    make INSTALL_DTBS_PATH=/tmp/kernel-modules/boot/dtb dtbs_install && \
    ( cd /tmp/kernel-modules && tar cf /out/kernel.tar . )

# Headers (userspace API)
RUN mkdir -p /tmp/kernel-headers/usr && \
    make INSTALL_HDR_PATH=/tmp/kernel-headers/usr headers_install && \
    ( cd /tmp/kernel-headers && tar cf /out/kernel-headers.tar usr )

# Headers (kernel development)
RUN DVER=$(basename $(find /tmp/kernel-modules/lib/modules/ -mindepth 1 -maxdepth 1)) && \
    dir=/tmp/usr/src/linux-headers-$DVER && \
    mkdir -p $dir && \
    cp /linux/.config $dir && \
    cp /linux/Module.symvers $dir && \
    find . -path './include/*' -prune -o \
           -path './arch/*/include' -prune -o \
           -path './scripts/*' -prune -o \
           -type f \( -name 'Makefile*' -o -name 'Kconfig*' -o -name 'Kbuild*' -o \
                      -name '*.lds' -o -name '*.pl' -o -name '*.sh' -o \
                      -name 'objtool' -o -name 'fixdep' -o -name 'randomize_layout_seed.h' \) | \
         tar cf - -T - | (cd $dir; tar xf -) && \
    ( cd /tmp && tar cf /out/kernel-dev.tar usr/src )

RUN printf "KERNEL_SOURCE=${KERNEL_URL}\n" > /out/kernel-source-info

FROM scratch
ENTRYPOINT []
CMD []
WORKDIR /
COPY --from=kernel-build /out/* /
