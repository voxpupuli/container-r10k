#!/bin/sh

set -e

for f in /container-entrypoint.d/*.sh; do
	echo "Running $f"
	"$f"
done

args="$@"
su puppet -c "exec r10k $args"
