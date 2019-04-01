FROM linuxkit/alpine:6ed32ba2b29a12b3d75f3d5b9be1b4ac00e7d479 AS build
RUN apk add --no-cache git

ENV REGDB_URL=https://kernel.googlesource.com/pub/scm/linux/kernel/git/sforshee/wireless-regdb
ENV REGDB_COMMIT=15fd5b499c641fad65d2dd2e1501e8825fe90b28
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
