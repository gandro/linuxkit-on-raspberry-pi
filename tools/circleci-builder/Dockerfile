FROM alpine:3.9

# required tools according to https://circleci.com/docs/2.0/custom-images
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    git \
    gzip \
    openssh-client \
    tar

# install docker client
ARG DOCKER_VERSION="18.09.3"
RUN curl -L "https://download.docker.com/linux/static/stable/$(uname -m)/docker-${DOCKER_VERSION}.tgz" | \
    tar -zx -C /usr/local/bin --strip-components=1 docker/docker

# custom helpers for the dockerd-on-arm64 image
ENV DOCKER_HOST="localhost:2375"
ADD run-if-changed /usr/local/bin
ADD wait-for-dockerd /usr/local/bin
