FROM golang:1.12.0 AS builder

ENV LINUXKIT_REPO=https://github.com/linuxkit/linuxkit.git
ENV LINUXKIT_COMMIT=8129070a90c2cff14faafd93e07c252861438d0f
RUN git clone $LINUXKIT_REPO /go/src/github.com/linuxkit/linuxkit && \
    cd /go/src/github.com/linuxkit/linuxkit && \
    git checkout --detach $LINUXKIT_COMMIT && \
    make local-static

ENV MANIFEST_REPO=https://github.com/estesp/manifest-tool.git
ENV MANIFEST_COMMIT=79bb01eb7f43af842cc1faa49ffe258477721fb3
RUN git clone $MANIFEST_REPO /go/src/github.com/estesp/manifest-tool && \
    cd /go/src/github.com/estesp/manifest-tool && \
    git checkout --detach $MANIFEST_COMMIT && \
    make static

ENV NOTARY_REPO=https://github.com/theupdateframework/notary.git
ENV NOTARY_COMMIT=8ff3ca06ec48f31e1f1d2685e3e6a9f65b6b92b5
RUN git clone $NOTARY_REPO /go/src/github.com/theupdateframework/notary && \
    cd /go/src/github.com/theupdateframework/notary && \
    git checkout --detach $NOTARY_COMMIT && \
    make static

FROM docker:18.09
RUN apk add --no-cache expect git gnupg jq
COPY --from=builder /go/src/github.com/linuxkit/linuxkit/scripts/push-manifest.sh /usr/local/bin/
COPY --from=builder /go/src/github.com/linuxkit/linuxkit/scripts/cleanup-older-images.sh /usr/local/bin/
COPY --from=builder /go/src/github.com/linuxkit/linuxkit/bin/linuxkit /usr/local/bin/
COPY --from=builder /go/src/github.com/estesp/manifest-tool/manifest-tool /usr/local/bin/
COPY --from=builder /go/src/github.com/theupdateframework/notary/bin/static/notary /usr/local/bin

CMD ["linuxkit"]
