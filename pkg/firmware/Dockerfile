FROM linuxkit/alpine:86cd4f51b49fb9a078b50201d892a3c7973d48ec AS build

ENV FW_REPO=https://github.com/RPi-Distro/firmware-nonfree
ENV FW_COMMIT=b518de45ced519e8f7a499f4778100173402ae43

ENV BT_REPO=https://github.com/RPi-Distro/bluez-firmware
ENV BT_COMMIT=96eefffcccc725425fd83be5e0704a5c32b79e54

WORKDIR /out/lib/firmware/brcm
RUN wget ${FW_REPO}/raw/${FW_COMMIT}/brcm/brcmfmac43430-sdio.txt && \
    wget ${FW_REPO}/raw/${FW_COMMIT}/brcm/brcmfmac43455-sdio.bin && \
    wget ${FW_REPO}/raw/${FW_COMMIT}/brcm/brcmfmac43455-sdio.clm_blob && \
    wget ${FW_REPO}/raw/${FW_COMMIT}/brcm/brcmfmac43455-sdio.txt && \
    wget ${BT_REPO}/raw/${BT_COMMIT}/broadcom/BCM43430A1.hcd && \
    wget ${BT_REPO}/raw/${BT_COMMIT}/broadcom/BCM4345C0.hcd 

FROM scratch
WORKDIR /
ENTRYPOINT []
COPY --from=build /out/lib/ /lib/
