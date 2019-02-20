FROM alpine:3.9
RUN apk add --no-cache qemu-img qemu-system-aarch64

# The dockerd LinuxKit files are built on an arm64 machine with `linuxkit build dockerd.yml`
WORKDIR /dockerd
EXPOSE 2375
COPY dockerd-cmdline dockerd-initrd.img dockerd-kernel ./

# See script for configurable environment variables
COPY run-qemu.sh /
CMD ["/run-qemu.sh"]
