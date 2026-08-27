#!/bin/sh

# Entry in /etc/passwd for the running UID, without it openssh will fail
if ! getent passwd "$(id -u)" >/dev/null 2>&1; then
	if [ -w /etc/passwd ]; then
		echo "puppet:x:$(id -u):0:puppet container user:${HOME:-/home/puppet}:/bin/sh" >> /etc/passwd
	else
		echo "WARNING: UID $(id -u) has no passwd entry and /etc/passwd is not writable; ssh will fail" >&2
	fi
fi
