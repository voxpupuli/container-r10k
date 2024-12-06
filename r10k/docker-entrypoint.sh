#!/bin/bash

set -e

find /docker-entrypoint.d/ -type f -name "*.sh" -exec echo Running {} \; -exec {} \;

exec r10k "$@"
