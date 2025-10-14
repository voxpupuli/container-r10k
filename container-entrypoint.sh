#!/bin/sh

set -e

find /container-entrypoint.d/ -type f -name "*.sh" -exec echo Running {} \; -exec {} \;

args="$@"
su puppet -c "exec r10k $args"
