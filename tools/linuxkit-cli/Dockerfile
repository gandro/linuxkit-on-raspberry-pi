FROM golang:1.12.0 AS builder

ENV LINUXKIT_REPO=https://github.com/linuxkit/linuxkit.git
ENV LINUXKIT_COMMIT=b5c03581e746f35d96ade3d0f77527ddab0b46b4
RUN git clone $LINUXKIT_REPO /go/src/github.com/linuxkit/linuxkit && \
    cd /go/src/github.com/linuxkit/linuxkit && \
    git checkout --detach $LINUXKIT_COMMIT && \
    make local-static

ENV MANIFEST_REPO=https://github.com/estesp/manifest-tool.git
ENV MANIFEST_COMMIT=0da654f67ac65e08a9a5b961f20123eb0e3d15e4
RUN git clone $MANIFEST_REPO /go/src/github.com/estesp/manifest-tool && \
    cd /go/src/github.com/estesp/manifest-tool && \
    git checkout --detach $MANIFEST_COMMIT && \
    make static

ENV NOTARY_REPO=https://github.com/theupdateframework/notary.git
ENV NOTARY_COMMIT=19454b59a0b22cf96079043685c6af0ac7a11a93
RUN git clone $NOTARY_REPO /go/src/github.com/theupdateframework/notary && \
    cd /go/src/github.com/theupdateframework/notary && \
    git checkout --detach $NOTARY_COMMIT && \
    make static

FROM docker:18.09
RUN apk add --no-cache expect git jq
COPY --from=builder /go/src/github.com/linuxkit/linuxkit/scripts/push-manifest.sh /usr/local/bin/
COPY --from=builder /go/src/github.com/linuxkit/linuxkit/scripts/cleanup-older-images.sh /usr/local/bin/
COPY --from=builder /go/src/github.com/linuxkit/linuxkit/bin/linuxkit /usr/local/bin/
COPY --from=builder /go/src/github.com/estesp/manifest-tool/manifest-tool /usr/local/bin/
COPY --from=builder /go/src/github.com/theupdateframework/notary/bin/static/notary /usr/local/bin

CMD ["linuxkit"]
