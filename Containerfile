ARG RUBYGEM_R10K=5.0.0
ARG RUBYGEM_OPENVOX=8.21.1

FROM docker.io/library/alpine:3.24 AS builder
ARG RUBYGEM_R10K
ARG RUBYGEM_OPENVOX

WORKDIR /build
RUN apk add --no-cache gcc make musl-dev ruby-dev

RUN gem install --no-doc r10k:"${RUBYGEM_R10K}" \
    && gem install --no-doc openvox:"${RUBYGEM_OPENVOX}" \
    && gem install --no-doc toml rexml syslog

###############################################################################

FROM docker.io/library/alpine:3.24
ARG RUBYGEM_R10K
ARG RUBYGEM_OPENVOX

ARG PUPPET_CONTROL_REPO="https://github.com/voxpupuli/controlrepo.git"
ENV PUPPET_CONTROL_REPO=$PUPPET_CONTROL_REPO

ARG UID=999
ARG GID=ping   # in alpine 3.x "ping" is the group of id 999

RUN adduser -G $GID -D -u $UID puppet

LABEL org.label-schema.maintainer="Voxpupuli Team <voxpupuli@groups.io>" \
      org.label-schema.vendor="Voxpupuli" \
      org.label-schema.url="https://github.com/voxpupuli/container-r10k" \
      org.label-schema.name="Vox Pupuli r10k" \
      org.label-schema.license="AGPL-3.0-or-later" \
      org.label-schema.vcs-url="https://github.com/voxpupuli/container-r10k" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.dockerfile="/Containerfile" \
      org.label-schema.version="$RUBYGEM_R10K"

RUN apk update && apk upgrade \
    && apk add --no-cache git libssh2 musl openssh-client ruby ruby-rugged curl \
    && rm /var/cache/apk/*

COPY container-entrypoint.d /container-entrypoint.d
COPY container-entrypoint.sh Containerfile /
COPY --from=builder /usr/lib/ruby/gems /usr/lib/ruby/gems

RUN mkdir -p /etc/puppetlabs/r10k /opt/puppetlabs/bin /opt/puppetlabs/puppet/cache/r10k /etc/puppetlabs/code/environments /home/puppet/.ssh \
    && chown puppet: /etc/puppetlabs/r10k /opt/puppetlabs/puppet/cache/r10k /etc/puppetlabs/code/environments /home/puppet/.ssh \
    && ln -s "/usr/lib/ruby/gems/3.4.0/gems/r10k-${RUBYGEM_R10K}/bin/r10k" /usr/local/bin/r10k \
    && ln -s "/usr/lib/ruby/gems/3.4.0/gems/openvox-${RUBYGEM_OPENVOX}/bin/puppet" /opt/puppetlabs/bin/puppet \
    && chmod +x /container-entrypoint.sh /container-entrypoint.d/*.sh

ARG SUPERCRONIC_VERSION=v0.2.45
ARG SUPERCRONIC_BASE_URL=https://github.com/aptible/supercronic/releases/download

RUN set -eux; \
    ARCH="${TARGETARCH:-$(uname -m)}"; \
    case "${ARCH}" in \
      amd64|x86_64) \
        SUPERCRONIC_BIN="supercronic-linux-amd64"; \
        SUPERCRONIC_SHA1SUM="e894b193bea75a5ee644e700c59e30eedc804cf7"; \
        ;; \
      arm64|aarch64) \
        SUPERCRONIC_BIN="supercronic-linux-arm64"; \
        SUPERCRONIC_SHA1SUM="20ce6dace414a64f0632f4092d6d3745db6085ad"; \
        ;; \
      *) \
        echo "Unsupported architecture: ${ARCH}"; \
        exit 1; \
        ;; \
    esac; \
    curl -fsSLO "${SUPERCRONIC_BASE_URL}/${SUPERCRONIC_VERSION}/${SUPERCRONIC_BIN}" \
    && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC_BIN}" | sha1sum -c - \
    && chmod +x "${SUPERCRONIC_BIN}" \
    && mv "${SUPERCRONIC_BIN}" "/usr/local/bin/${SUPERCRONIC_BIN}" \
    && ln -s "/usr/local/bin/${SUPERCRONIC_BIN}" /usr/local/bin/supercronic

USER puppet

ENTRYPOINT ["/container-entrypoint.sh"]
CMD ["help"]
