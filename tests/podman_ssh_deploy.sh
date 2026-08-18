#!/bin/sh
# End-to-end test: r10k deploys from a git-over-SSH control repo under Podman.
#
# This covers deployment shapes the plain `docker run … deploy environment`
# smoke test does not:
#
#   1. Podman as the runtime, with key material mounted into the container
#      user's home. Podman differs from Docker in one important way: when the
#      running UID has no /etc/passwd entry in the image, Podman injects one
#      before the entrypoint runs, with home dir "/". OpenSSH resolves ~/.ssh
#      via getpwuid(), not $HOME, so an uncorrected entry makes ssh search
#      /.ssh for keys and known_hosts and the deploy fails.
#   2. A Puppetfile module sourced from git over SSH (the Forge-module path
#      is covered by the docker smoke test, the git-module path is not).
#   3. generate_types output, via a dummy custom type in the module.
#   4. A second deploy against a warm cache after the control repo advances.
#   5. A scheduled deploy through supercronic.
#
# The SSH server runs in a second container on a shared Podman network, so
# the test behaves identically on Linux CI runners and on macOS podman
# machine.
#
# Usage: tests/podman_ssh_deploy.sh <image> [uid[:gid]]
#
# With no uid argument the image's default USER is tested. Pass an arbitrary
# uid (e.g. "4321:0") to test OpenShift-style random-UID execution on images
# that support it.
set -eu

IMAGE="${1:?usage: $0 <image> [uid[:gid]]}"
RUN_UID="${2:-}"
NET=r10k-e2e-net
SERVER=r10k-e2e-gitserver
CRON=r10k-e2e-cron

# extra args for `podman run`
set --
if [ -n "$RUN_UID" ]; then
	set -- --user "$RUN_UID"
fi

WORKDIR="$(mktemp -d)"
cleanup() {
	podman rm -f "$CRON" "$SERVER" >/dev/null 2>&1 || true
	podman network rm -f "$NET" >/dev/null 2>&1 || true
	rm -rf "$WORKDIR"
}
trap cleanup EXIT

# clear leftovers from a previous aborted run
podman rm -f "$CRON" "$SERVER" >/dev/null 2>&1 || true
podman network rm -f "$NET" >/dev/null 2>&1 || true

# In CI the image is built into the Docker daemon; copy it into podman
# storage if podman does not have it yet.
if ! podman image exists "$IMAGE"; then
	podman pull "docker-daemon:${IMAGE}"
fi

# Home directory the container user expects; ssh material goes to $HOME/.ssh
TARGET_HOME="$(podman run --rm "$@" --entrypoint /bin/sh "$IMAGE" -c 'echo "$HOME"')"
if [ -z "$TARGET_HOME" ] || [ "$TARGET_HOME" = "/" ]; then
	echo "ERROR: could not determine a usable \$HOME for image '$IMAGE' (got '${TARGET_HOME}')" >&2
	exit 1
fi

podman network create "$NET" >/dev/null

# --- seed repos, authored on the host ----------------------------------------
mkdir -p "$WORKDIR/seed-module/manifests" "$WORKDIR/seed-module/lib/puppet/type" \
	"$WORKDIR/seed-control/manifests"

cat > "$WORKDIR/seed-module/manifests/init.pp" << 'EOF'
class testmodule {}
EOF
cat > "$WORKDIR/seed-module/lib/puppet/type/testmodule_marker.rb" << 'EOF'
Puppet::Type.newtype(:testmodule_marker) do
  @doc = 'dummy type so `r10k … generate_types` has something to generate'
  newparam(:name, namevar: true)
end
EOF

cat > "$WORKDIR/seed-control/Puppetfile" << EOF
mod 'testmodule',
  :git => 'ssh://git@${SERVER}/home/git/testmodule.git',
  :ref => 'master'
EOF
touch "$WORKDIR/seed-control/manifests/site.pp"

# --- git-over-SSH server container ------------------------------------------
podman run -d --name "$SERVER" --network "$NET" \
	docker.io/library/alpine:3.22 sleep infinity >/dev/null

ssh-keygen -q -t ed25519 -N '' -f "$WORKDIR/client_key"

podman exec "$SERVER" sh -ec '
	apk add --no-cache openssh git >/dev/null
	# throwaway fixture: repos are chowned to git but driven by root execs
	git config --global --add safe.directory "*"
	ssh-keygen -A
	adduser -D git
	# unlock the account; pubkey-only auth is still enforced
	sed -i "s/^git:!/git:*/" /etc/shadow
	mkdir -p /home/git/.ssh
'
podman cp "$WORKDIR/client_key.pub" "$SERVER:/home/git/.ssh/authorized_keys"
podman cp "$WORKDIR/seed-module" "$SERVER:/tmp/seed-module"
podman cp "$WORKDIR/seed-control" "$SERVER:/tmp/seed-control"
podman exec "$SERVER" sh -ec '
	chmod 700 /home/git/.ssh
	chmod 600 /home/git/.ssh/authorized_keys

	git init -q --bare --initial-branch=master /home/git/testmodule.git
	git init -q --bare --initial-branch=production /home/git/controlrepo.git

	cd /tmp/seed-module
	git init -q .
	git add -A
	git -c user.name=ci -c user.email=ci@invalid commit -qm "seed module"
	git push -q /home/git/testmodule.git HEAD:master

	cd /tmp/seed-control
	git init -q .
	git add -A
	git -c user.name=ci -c user.email=ci@invalid commit -qm "seed control repo"
	git push -q /home/git/controlrepo.git HEAD:production

	chown -R git:git /home/git
	/usr/sbin/sshd
'

# --- ssh material the r10k container expects in $HOME/.ssh -------------------
mkdir "$WORKDIR/dot_ssh" "$WORKDIR/environments" "$WORKDIR/cache"
cp "$WORKDIR/client_key" "$WORKDIR/dot_ssh/id_ed25519"
chmod 600 "$WORKDIR/dot_ssh/id_ed25519"
podman exec "$SERVER" cat /etc/ssh/ssh_host_ed25519_key.pub |
	awk -v h="$SERVER" '{print h, $1, $2}' > "$WORKDIR/dot_ssh/known_hosts"

deploy() {
	# :U chowns the mounts to the container user
	podman run --rm --network "$NET" "$@" \
		-v "$WORKDIR/dot_ssh:${TARGET_HOME}/.ssh:U" \
		-v "$WORKDIR/environments:/etc/puppetlabs/code/environments:U" \
		-v "$WORKDIR/cache:/opt/puppetlabs/puppet/cache/r10k:U" \
		-e PUPPET_CONTROL_REPO="ssh://git@${SERVER}/home/git/controlrepo.git" \
		"$IMAGE" deploy environment production -mv
}

commit_marker() {
	podman exec "$SERVER" sh -ec "
		cd /tmp/seed-control
		touch $1
		git add -A
		git -c user.name=ci -c user.email=ci@invalid commit -qm 'add $1'
		git push -q /home/git/controlrepo.git HEAD:production
	"
}

# --- 1+2+3: deploy over SSH, including a git module and generated types ------
deploy "$@"
test -f "$WORKDIR/environments/production/Puppetfile"
test -f "$WORKDIR/environments/production/modules/testmodule/manifests/init.pp"
test -d "$WORKDIR/environments/production/.resource_types"
echo "OK: initial deploy with git-over-SSH module and generated types"

# --- 4: second deploy against the warm cache after the control repo moved ----
commit_marker second_deploy_marker
deploy "$@"
test -f "$WORKDIR/environments/production/second_deploy_marker"
test -d "$WORKDIR/environments/production/.resource_types"
echo "OK: warm-cache redeploy picked up new commit"

# --- 5: scheduled deploy through supercronic ---------------------------------
commit_marker cron_deploy_marker
# seven-field crontab: run every 5 seconds
echo '*/5 * * * * * * /usr/local/bin/r10k deploy environment production' \
	> "$WORKDIR/crontab"
podman run -d --name "$CRON" --network "$NET" "$@" \
	-v "$WORKDIR/dot_ssh:${TARGET_HOME}/.ssh:U" \
	-v "$WORKDIR/environments:/etc/puppetlabs/code/environments:U" \
	-v "$WORKDIR/cache:/opt/puppetlabs/puppet/cache/r10k:U" \
	-v "$WORKDIR/crontab:/crontab:ro" \
	-e PUPPET_CONTROL_REPO="ssh://git@${SERVER}/home/git/controlrepo.git" \
	--entrypoint /bin/sh "$IMAGE" \
	-c 'for f in /container-entrypoint.d/*.sh; do "$f"; done; exec supercronic /crontab' \
	>/dev/null

tries=0
until [ -f "$WORKDIR/environments/production/cron_deploy_marker" ]; do
	tries=$((tries + 1))
	if [ "$tries" -gt 30 ]; then
		echo "ERROR: supercronic deploy did not happen within 60s; container logs:" >&2
		podman logs "$CRON" >&2 || true
		exit 1
	fi
	sleep 2
done
echo "OK: supercronic scheduled deploy"

echo "PASS: r10k deployed over SSH under Podman${RUN_UID:+ as UID $RUN_UID}"
