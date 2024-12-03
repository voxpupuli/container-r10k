FROM alpine:3.20

ARG APK_GIT=2.45.2-r0
ARG RUBYGEM_R10K=4.1.0

LABEL org.label-schema.maintainer="Voxpupuli Team <voxpupuli@groups.io>" \
      org.label-schema.vendor="Voxpupuli" \
      org.label-schema.url="https://github.com/voxpupuli/container-r10k" \
      org.label-schema.name="Vox Pupuli r10k" \
      org.label-schema.license="AGPL-3.0-or-later" \
      org.label-schema.vcs-url="https://github.com/voxpupuli/container-r10k" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.dockerfile="/Dockerfile" \
      org.label-schema.version="$RUBYGEM_R10K"

# in alpine 3.20 "ping" is the group of id 999
RUN adduser -G ping -D -u 999 puppet

RUN apk update \
    && apk upgrade \
    && apk add --no-cache \
      gcc \
      git=${APK_GIT} \
      libssh2 \
      make \
      musl-dev \
      openssh-client \
      ruby \
      ruby-dev \
      ruby-rugged

RUN gem install --no-doc r10k:"$RUBYGEM_R10K"

USER puppet
WORKDIR /home/puppet

COPY Dockerfile /

ENTRYPOINT ["/usr/bin/r10k"]
CMD ["help"]
