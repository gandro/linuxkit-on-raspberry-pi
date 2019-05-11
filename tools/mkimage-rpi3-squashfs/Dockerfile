FROM linuxkit/alpine:86cd4f51b49fb9a078b50201d892a3c7973d48ec

RUN \
  apk update && apk upgrade && \
  apk add --no-cache \
  curl \
  dosfstools \
  libarchive-tools \
  mtools \
  sfdisk \
  squashfs-tools \
  && true

ENV RPI_COMMIT=9fd387c96353dd9983aa73bd33b541926de93789
RUN mkdir -p /boot && \
    cd /boot && \
    curl -fsSLO https://github.com/raspberrypi/firmware/raw/$RPI_COMMIT/boot/bootcode.bin && \
    curl -fsSLO https://github.com/raspberrypi/firmware/raw/$RPI_COMMIT/boot/fixup_cd.dat && \
    curl -fsSLO https://github.com/raspberrypi/firmware/raw/$RPI_COMMIT/boot/fixup.dat && \
    curl -fsSLO https://github.com/raspberrypi/firmware/raw/$RPI_COMMIT/boot/fixup_x.dat && \
    curl -fsSLO https://github.com/raspberrypi/firmware/raw/$RPI_COMMIT/boot/start_cd.elf && \
    curl -fsSLO https://github.com/raspberrypi/firmware/raw/$RPI_COMMIT/boot/start.elf && \
    curl -fsSLO https://github.com/raspberrypi/firmware/raw/$RPI_COMMIT/boot/start_x.elf

COPY config.txt /boot
COPY make-rpi3-squashfs /

ENTRYPOINT [ "/make-rpi3-squashfs" ]
