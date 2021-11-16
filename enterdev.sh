#!/bin/bash
set -o errexit -o noclobber -o nounset

opts="$(getopt -o n:i:d -l name:,image:,detach,hostbin --name "$0" -- "$@")"
eval set -- "$opts"

NAME="dev"
IMAGE=""
DETACH=false
HOSTBIN=false
while true
do
  case "$1" in
    -n|--name)
      NAME=$2
      shift 2
      ;;
    -i|--image)
      IMAGE=$2
      shift 2
      ;;
    -d|--detach)
      DETACH=true
      shift
      ;;
    --hostbin)
      HOSTBIN=true
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

if [ ! $(docker ps -q -f name="^${NAME}$") ]; then
  if [ -z "$IMAGE" ]; then
    IMAGE="enterdev/dev:latest"
    if [ ! $(docker images -q "$IMAGE") ]; then
      pushd "$(dirname "$0")"
      docker build -t "$IMAGE" -f dev.Dockerfile .
      popd
    fi
  fi

  USER_FLAGS="-u $(id -u):$(id -g) -v ${HOME}:${HOME}"
  for grp in $(id -G); do USER_FLAGS="${USER_FLAGS} --group-add $grp"; done

  ETC_MOUNT_FLAGS=""
  for f in "group" "gshadow" "inputrc" "localtime" "passwd" "shadow" "subgid" "subuid" "sudoers"; do
    ETC_MOUNT_FLAGS="${ETC_MOUNT_FLAGS} -v /etc/$f:/etc/$f:ro"
  done

  SUDO_FLAGS=""
  if [ "$HOSTBIN" = true ]; then
    SUDO_FLAGS="-v /usr/bin/sudo:/usr/bin/sudo:ro -v /usr/lib/sudo:/usr/lib/sudo:ro"
  fi

  SSS_FLAGS=""
  if [ -f "/var/lib/sss" ]; then
    SSS_FLAGS="-v /var/lib/sss:/var/lib/sss:ro"
  fi

  NET_FLAGS="--network host --add-host ${NAME}:127.0.0.1"
  IPC_FLAGS="--ipc host --pid host"
  X11_FLAGS=""
  if [ "${DISPLAY:-}" ]; then
    X11_FLAGS="-v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=${DISPLAY}"
  fi
  NVIDIA_FLAGS=""
  if [[ $(docker run --rm --runtime=nvidia ${IMAGE} bash -c "exit 0" 2>/dev/null ; echo $? ) == 0 ]]; then
    NVIDIA_FLAGS="--runtime=nvidia"
  elif [[ $(docker run --rm --gpus=all ${IMAGE} bash -c "exit 0" 2>/dev/null ; echo $? ) == 0 ]]; then
    NVIDIA_FLAGS="--gpus=all"
  fi
  DOCKER_FLAGS="-v /var/run/docker.sock:/var/run/docker.sock"
  if [ "$HOSTBIN" = true ]; then
    DOCKER_FLAGS="${DOCKER_FLAGS} -v /usr/bin/docker:/usr/bin/docker:ro"
  fi

  docker run --rm -it -d --privileged \
    --name $NAME \
    -h $NAME \
    $USER_FLAGS \
    $ETC_MOUNT_FLAGS \
    $SUDO_FLAGS \
    $SSS_FLAGS \
    $NET_FLAGS \
    $IPC_FLAGS \
    $X11_FLAGS \
    $NVIDIA_FLAGS \
    $DOCKER_FLAGS \
    $@ \
    $IMAGE bash
fi

if [ "$DETACH" = false ]; then
  docker exec -it -w "${PWD}" $NAME bash
fi
