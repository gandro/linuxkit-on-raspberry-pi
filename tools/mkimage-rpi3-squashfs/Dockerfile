FROM linuxkit/alpine:6ed32ba2b29a12b3d75f3d5b9be1b4ac00e7d479

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

ENV RPI_COMMIT=9ce09b817068671faddc56b5400c1b33232eabcf
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
