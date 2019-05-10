FROM linuxkitrpi/images:dockerd-52a12d8ca8b6103703d92d82297d546571c7d5ac-arm64 AS image

FROM alpine:3.9
RUN apk add --no-cache cdrkit qemu-img qemu-system-aarch64

# The dockerd-arm64 folder is provided by `build.sh`
COPY --from=image /. /dockerd
COPY daemon.json /dockerd

# See `run-qemu.sh` script for configurable environment variables
EXPOSE 2375
COPY run-qemu.sh /
CMD ["/run-qemu.sh"]
