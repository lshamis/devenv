FROM nvidia/cuda:11.4.1-cudnn8-devel-ubuntu20.04

# Import NVIDIA GPG key
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A4B469963BF863CC

RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y \
        curl \
        gdb \
        git \
        python3-dev \
        python3-pip \
        sssd \
        sudo \
        valgrind \
        vim \
        wget && \
    rm -rf /var/lib/apt/lists/*

RUN curl https://get.docker.com | sh
