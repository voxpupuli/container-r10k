# Vox Pupuli Test Box

[![CI](https://github.com/voxpupuli/container-r10k/actions/workflows/ci.yaml/badge.svg)](https://github.com/voxpupuli/container-r10k/actions/workflows/ci.yaml)
[![License](https://img.shields.io/github/license/voxpupuli/container-r10k.svg)](https://github.com/voxpupuli/container-r10k/blob/main/LICENSE)
[![Sponsored by betadots GmbH](https://img.shields.io/badge/Sponsored%20by-betadots%20GmbH-blue.svg)](https://www.betadots.de)

## Introduction

This container should be used to deploy code with r10k. It has the r10k gem and all dependencies installed.

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
| r10k.major    | Describes the contained major r10k version |
| r10k.minor    | Describes the contained minor r10k version |
| r10k.patch    | Describes the contained patch r10k version |
| container.major | Describes breaking changes without backward compatibility |
| container.minor | Describes new features or refactoring with backward compatibility |
| container.patch | Describes if minor changes or bugfixes have been implemented |

## How to release?

see [RELEASE.md](RELEASE.md)

## How to contribute?

see [CONTRIBUTING.md](CONTRIBUTING.md)
