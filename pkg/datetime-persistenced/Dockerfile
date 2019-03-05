FROM linuxkit/alpine:9f00542b8b74b7815936affb11dedb86945fe4ac AS mirror
RUN apk add --no-cache go musl-dev
ENV GOPATH=/go PATH=$PATH:/go/bin

COPY .  /go/src/datetime-persistenced
RUN go-compile.sh /go/src/datetime-persistenced

FROM scratch
ENTRYPOINT []
CMD []
WORKDIR /
COPY --from=mirror /go/bin/datetime-persistenced /usr/bin/datetime-persistenced
CMD ["/usr/bin/datetime-persistenced"]