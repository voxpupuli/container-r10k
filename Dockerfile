FROM alpine:3.20

ARG APK_GIT=2.45.2-r0
ARG RUBYGEM_R10K=5.0.0
ARG RUBYGEM_PUPPET=8.10.0

ARG PUPPET_CONTROL_REPO="https://github.com/voxpupuli/controlrepo.git"
ENV PUPPET_CONTROL_REPO=$PUPPET_CONTROL_REPO

ARG UID=999
# in alpine 3.20 "ping" is the group of id 999
ARG GID=ping

LABEL org.label-schema.maintainer="Voxpupuli Team <voxpupuli@groups.io>" \
      org.label-schema.vendor="Voxpupuli" \
      org.label-schema.url="https://github.com/voxpupuli/container-r10k" \
      org.label-schema.name="Vox Pupuli r10k" \
      org.label-schema.license="AGPL-3.0-or-later" \
      org.label-schema.vcs-url="https://github.com/voxpupuli/container-r10k" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.dockerfile="/Dockerfile" \
      org.label-schema.version="$RUBYGEM_R10K"

RUN adduser -G $GID -D -u $UID puppet

RUN apk update \
    && apk upgrade \
    && apk add --no-cache \
      bash \
      gcc \
      git=${APK_GIT} \
      libssh2 \
      make \
      musl-dev \
      openssh-client \
      ruby \
      ruby-dev \
      ruby-rugged

COPY r10k/docker-entrypoint.d /docker-entrypoint.d/
COPY r10k/docker-entrypoint.sh Dockerfile /

RUN mkdir -p /etc/puppetlabs/r10k /opt/puppetlabs/bin /opt/puppetlabs/puppet/cache/r10k /etc/puppetlabs/code/environments \
    && chown -R puppet: /etc/puppetlabs/r10k /opt/puppetlabs/bin /opt/puppetlabs/puppet/cache/r10k /etc/puppetlabs/code/environments \
    && chmod +x /docker-entrypoint.sh \
    && mkdir -p /home/puppet \
    && chown -R puppet: /home/puppet

USER puppet
WORKDIR /home/puppet

ENV PATH="/home/puppet/.local/share/gem/ruby/3.3.0/bin:${PATH}"
RUN gem install --no-doc r10k:"$RUBYGEM_R10K" --user-install \
    && gem install --no-doc puppet:"$RUBYGEM_PUPPET" --user-install \
    && gem install --no-doc toml rexml --user-install \
    && ln -s /home/puppet/.local/share/gem/ruby/3.3.0/bin/puppet /opt/puppetlabs/bin/puppet

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["help"]
