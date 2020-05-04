# Docker-Scripts
Scripts to manage a docker registry

## install_docker.sh
Script to install a docker registry. The user has control of the name of the container, the port of the registry, user and password to login in it. 

**User must have sudo privileges or be root of the system** because the script creates a crontab job as root to run garbage collector everyday at 0300.

## multi-archbuilder.sh
Creates a image with support by many architectures (amd64,arm64,386,arm/v7) and pushes to a private registry.

User can choose what architectures to build:
- 1 - ALL
- 2 - amd64 + arm64
- 3 - amd64
- 4 - 386
- 5 - arm64
- 6 - arm-v7

The script uses docker buildx, so a builder has to be created, and able to build each image individually.
