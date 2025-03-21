ARG RUBYGEM_R10K=5.0.0
ARG RUBYGEM_PUPPET=8.10.0

FROM docker.io/library/alpine:3.21 AS builder
ARG RUBYGEM_R10K
ARG RUBYGEM_PUPPET

WORKDIR /build
RUN apk add --no-cache gcc make musl-dev ruby-dev

RUN gem install --no-doc r10k:"${RUBYGEM_R10K}" \
    && gem install --no-doc puppet:"${RUBYGEM_PUPPET}" \
    && gem install --no-doc toml rexml


FROM docker.io/library/alpine:3.21
ARG RUBYGEM_R10K
ARG RUBYGEM_PUPPET

ARG PUPPET_CONTROL_REPO="https://github.com/voxpupuli/controlrepo.git"
ENV PUPPET_CONTROL_REPO=$PUPPET_CONTROL_REPO

ARG UID=999
ARG GID=ping   # in alpine 3.20 "ping" is the group of id 999

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

RUN apk add --no-cache git libssh2 musl openssh-client ruby ruby-rugged

COPY r10k/docker-entrypoint.d /docker-entrypoint.d
COPY r10k/docker-entrypoint.sh Dockerfile /
COPY --from=builder /usr/lib/ruby/gems /usr/lib/ruby/gems

RUN mkdir -p /etc/puppetlabs/r10k /opt/puppetlabs/bin /opt/puppetlabs/puppet/cache/r10k /etc/puppetlabs/code/environments \
    && chown puppet: /opt/puppetlabs/puppet/cache/r10k /etc/puppetlabs/code/environments \
    && ln -s "/usr/lib/ruby/gems/3.3.0/gems/r10k-${RUBYGEM_R10K}/bin/r10k" /usr/local/bin/r10k \
    && ln -s "/usr/lib/ruby/gems/3.3.0/gems/puppet-${RUBYGEM_PUPPET}/bin/puppet" /opt/puppetlabs/bin/puppet \
    && chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["help"]
