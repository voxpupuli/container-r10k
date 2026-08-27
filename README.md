# Vox Pupuli R10K

[![CI](https://github.com/voxpupuli/container-r10k/actions/workflows/ci.yaml/badge.svg)](https://github.com/voxpupuli/container-r10k/actions/workflows/ci.yaml)
[![License](https://img.shields.io/github/license/voxpupuli/container-r10k.svg)](https://github.com/voxpupuli/container-r10k/blob/main/LICENSE)
[![Sponsored by betadots GmbH](https://img.shields.io/badge/Sponsored%20by-betadots%20GmbH-blue.svg)](https://www.betadots.de)

## Introduction

This container is designed for deploying Puppet code using r10k. It includes the r10k gem along with all necessary dependencies pre-installed, ensuring a seamless deployment process.

## Usage

To run r10k, simply execute the container.
The r10k binary is set as the default entrypoint.
The container runs with group 0 (GID 0) and works under any UID; the default
UID is 64604. Mounted volumes must be writable by group 0
(`chgrp -R 0 <dir> && chmod -R g+rwX <dir>`; on Kubernetes, `fsGroup: 0` does
this for you). The UID of mounted files does not matter.

In order to use git over SSH: mount the private key in `/home/puppet/.ssh/`
either owned by the running UID and mode 0600, or owned by another UID and group-0 readable
(e.g. a Kubernetes secret mounted with `fsGroup: 0`).
Provide a `known_hosts` file in `/home/puppet/.ssh/`.

You can use a shared volume with a Puppet server and mount it at `/etc/puppetlabs/code/environments`.

```shell
podman run -it --rm -v code_dir:/etc/puppetlabs/code/environments:Z ghcr.io/voxpupuli/r10k:latest deploy environment -mv
```

```yaml
services:
  r10k:
    image: ghcr.io/voxpupuli/r10k:5.0.0-latest
    environment:
      - PUPPET_CONTROL_REPO=https://github.com/my-org/control-repo.git
    volumes:
      - puppetserver-code-dir:/etc/puppetlabs/code/environments:Z
    entrypoint: ["/container-entrypoint.sh"]
    command: ["deploy", "environment", "-mv"]
```

### Environment Variables

| Name | Description |
| --- | --- |
| `PUPPET_CONTROL_REPO` | The control repo url to get the Puppetfile from. Defaults to <https://github.com/voxpupuli/controlrepo.git> |

## Build

### Build Arguments

| Name | Description |
| --- | --- |
| `RUBYGEM_R10K` | The r10k version to install |
| `RUBYGEM_OPENVOX` | The openvox version to install |
| `PUPPET_CONTROL_REPO` | The control repo url to get the Puppetfile from. Defaults to <https://github.com/voxpupuli/controlrepo.git> |

## Version Schema

The version schema has the following layout:

```text
<r10k.major>.<r10k.minor>.<r10k.patch>-v<container.major>.<container.minor>.<container.patch>
<r10k.major>.<r10k.minor>.<r10k.patch>-latest
latest
```

Example usage:

```shell
docker pull ghcr.io/voxpupuli/r10k:4.1.0-v1.2.3
docker pull ghcr.io/voxpupuli/r10k:4.1.0-latest
docker pull ghcr.io/voxpupuli/r10k:latest
```

| Name | Description |
| --- | --- |
| r10k.major | Describes the contained major r10k version |
| r10k.minor | Describes the contained minor r10k version |
| r10k.patch | Describes the contained patch r10k version |
| container.major | Describes breaking changes without backward compatibility |
| container.minor | Describes new features or refactoring with backward compatibility |
| container.patch | Describes if minor changes or bugfixes have been implemented |

## How to release?

see [RELEASE.md](RELEASE.md)

## How to contribute?

see [CONTRIBUTING.md](CONTRIBUTING.md)
