#!/bin/bash

cat > /etc/puppetlabs/r10k/r10k.yaml << EOF
---
pool_size: 8
deploy:
  generate_types: true
  exclude_spec: true
  incremental: true
  purge_levels: [ 'deployment', 'environment', 'puppetfile' ]
cachedir: "/opt/puppetlabs/puppet/cache/r10k"
sources:
  puppet:
    basedir: "/etc/puppetlabs/code/environments"
    remote: ${PUPPET_CONTROL_REPO:=$DEFAULT_CONTROL_REPO}
EOF
