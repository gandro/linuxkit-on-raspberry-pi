FROM alpine:3.9 AS base
RUN mkdir -p /out/etc/apk && cp -r /etc/apk/* /out/etc/apk/
RUN apk add --no-cache --initdb -p /out \
    alpine-baselayout \
    chrony
RUN rm -rf /out/etc/apk /out/lib/apk /out/var/cache

FROM scratch
ENTRYPOINT []
WORKDIR /
COPY --from=base /out/ /
COPY etc/ /etc/
CMD ["/usr/sbin/chronyd", "-f", "/etc/chrony/chrony.conf", "-d", "-s"]
