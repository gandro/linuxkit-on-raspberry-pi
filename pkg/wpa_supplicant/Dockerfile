FROM linuxkit/alpine:9f00542b8b74b7815936affb11dedb86945fe4ac AS mirror
RUN mkdir -p /out/etc/apk && cp -r /etc/apk/* /out/etc/apk/
RUN apk add --no-cache --initdb -p /out \
    alpine-baselayout \
    wpa_supplicant \
    wireless-tools
RUN rm -rf /out/etc/apk /out/lib/apk /out/var/cache

FROM scratch
ENTRYPOINT []
CMD ["wpa_supplicant", "-D", "wext","-i", "wlan0", "-c", "/etc/wpa_supplicant/wpa_supplicant.conf"]
WORKDIR /
COPY --from=mirror /out/ /
