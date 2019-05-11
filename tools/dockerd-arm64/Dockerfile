FROM linuxkitrpi/images:dockerd-a611082194b869829b7be35565ce4b7461c1728b-arm64 AS image

FROM alpine:3.9
RUN apk add --no-cache cdrkit qemu-img qemu-system-aarch64

# The dockerd-arm64 folder is provided by `build.sh`
COPY --from=image /. /dockerd
COPY daemon.json /dockerd

# See `run-qemu.sh` script for configurable environment variables
EXPOSE 2375
COPY run-qemu.sh /
CMD ["/run-qemu.sh"]
