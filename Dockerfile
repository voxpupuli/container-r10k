ARG RUBYGEM_R10K=5.0.0
ARG RUBYGEM_OPENVOX=8.21.1

FROM docker.io/library/alpine:3.22 AS builder
ARG RUBYGEM_R10K
ARG RUBYGEM_OPENVOX

WORKDIR /build
RUN apk add --no-cache gcc make musl-dev ruby-dev

RUN gem install --no-doc r10k:"${RUBYGEM_R10K}" \
    && gem install --no-doc openvox:"${RUBYGEM_OPENVOX}" \
    && gem install --no-doc toml rexml syslog


FROM docker.io/library/alpine:3.22
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
      org.label-schema.dockerfile="/Dockerfile" \
      org.label-schema.version="$RUBYGEM_R10K"

RUN apk update && apk upgrade \
    && apk add --no-cache git libssh2 musl openssh-client ruby ruby-rugged \
    && rm /var/cache/apk/*

COPY r10k/docker-entrypoint.d /docker-entrypoint.d
COPY r10k/docker-entrypoint.sh Dockerfile /
COPY --from=builder /usr/lib/ruby/gems /usr/lib/ruby/gems

RUN mkdir -p /etc/puppetlabs/r10k /opt/puppetlabs/bin /opt/puppetlabs/puppet/cache/r10k /etc/puppetlabs/code/environments \
    && chown puppet: /opt/puppetlabs/puppet/cache/r10k /etc/puppetlabs/code/environments \
    && ln -s "/usr/lib/ruby/gems/3.4.0/gems/r10k-${RUBYGEM_R10K}/bin/r10k" /usr/local/bin/r10k \
    && ln -s "/usr/lib/ruby/gems/3.4.0/gems/puppet-${RUBYGEM_OPENVOX}}/bin/puppet" /opt/puppetlabs/bin/puppet \
    && chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["help"]
