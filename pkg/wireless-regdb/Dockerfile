FROM linuxkit/alpine:86cd4f51b49fb9a078b50201d892a3c7973d48ec AS build
RUN apk add --no-cache git

ENV REGDB_URL=https://kernel.googlesource.com/pub/scm/linux/kernel/git/sforshee/wireless-regdb
ENV REGDB_COMMIT=215fc67bbfb6f75eea164b654de3be30f9270f40
WORKDIR /
RUN git clone ${REGDB_URL} && \
    cd /wireless-regdb && \
    git checkout --detach ${REGDB_COMMIT}

RUN mkdir -p /out/lib/firmware && \
    cp -a /wireless-regdb/regulatory.db /out/lib/firmware && \
    cp -a /wireless-regdb/regulatory.db.p7s /out/lib/firmware && \
    mkdir -p /out/usr/lib/crda/pubkeys && \
    cp -a /wireless-regdb/regulatory.bin /out/usr/lib/crda/ && \
    cp -a /wireless-regdb/sforshee.key.pub.pem /out/usr/lib/crda/pubkeys

FROM scratch
WORKDIR /
ENTRYPOINT []
COPY --from=build /out/ /
