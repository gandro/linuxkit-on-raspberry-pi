FROM linuxkit/alpine:4768505d40f23e198011b6f2c796f985fe50ec39 AS kernel-build
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
    libressl \
    libressl-dev \
    linux-headers \
    mpc1-dev \
    mpfr-dev \
    ncurses-dev \
    patch \
    sed \
    squashfs-tools \
    tar \
    xz \
    xz-dev \
    zlib-dev

ENV KERNEL_SOURCE=https://github.com/raspberrypi/linux.git
ENV KERNEL_BRANCH=rpi-4.19.y

# Fetch source
RUN git clone --depth=1 -b ${KERNEL_BRANCH} ${KERNEL_SOURCE} /linux
WORKDIR /linux

# Save kernel source
RUN mkdir -p /out/src
RUN tar cJf /out/src/linux.tar.xz /linux

# enable squashfs (for rootfs) and options recommended by moby's check-config.sh
RUN ./scripts/config --file arch/arm64/configs/bcmrpi3_defconfig \
    --enable CONFIG_SQUASHFS \
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
    --enable CONFIG_CGROUP_PIDS \
    --enable CONFIG_MEMCG_SWAP \
    --enable CONFIG_MEMCG_SWAP_ENABLED \
    --enable CONFIG_BLK_CGROUP \
    --enable CONFIG_BLK_DEV_THROTTLING \
    --enable CONFIG_IOSCHED_CFQ \
    --enable CONFIG_CFQ_GROUP_IOSCHED \
    --enable CONFIG_CGROUP_PERF \
    --enable CONFIG_CGROUP_HUGETLB \
    --enable CONFIG_NET_CLS_CGROUP \
    --enable CONFIG_CGROUP_NET_PRIO \
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

# Kernel config
RUN make bcmrpi3_defconfig

# Kernel
RUN make -j "$(getconf _NPROCESSORS_ONLN)" KCFLAGS="-fno-pie" && \
    cp arch/arm64/boot/Image.gz /out/kernel && \
    cp System.map /out

# Modules and Device Tree binaries
RUN make INSTALL_MOD_PATH=/tmp/kernel-modules modules_install && \
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

RUN printf "KERNEL_SOURCE=${KERNEL_SOURCE}\n" > /out/kernel-source-info

FROM scratch
ENTRYPOINT []
CMD []
WORKDIR /
COPY --from=kernel-build /out/* /
