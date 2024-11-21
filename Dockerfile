FROM ubuntu:24.04

LABEL maintainer="https://github.com/cloudfreexiao"

RUN apt update
RUN apt install -y make build-essential cmake gcc g++ git sudo
RUN apt install -y zlib1g-dev libbz2-dev libreadline-dev llvm libfaketime libcapstone-dev libelf-dev
RUN apt install -y rlwrap golang-go curl wget valgrind zip unzip
RUN apt upgrade -y
RUN apt autoremove
RUN apt-get clean

RUN curl -fsSL https://bun.sh/install | bash

ENV RuntimeDir=/opt/workspace
ENV BuildDir=/tmp/pluto

RUN mkdir -p ${BuildDir}
RUN mkdir -p ${RuntimeDir}

COPY . ${BuildDir}
WORKDIR ${BuildDir}
RUN sh build.sh
RUN cp -rf build/pluto ${RuntimeDir}
RUN cp -rf pluto/tools ${RuntimeDir}
RUN rm -rf ${BuildDir}

WORKDIR ${RuntimeDir}/pluto
CMD ["sh", "-c", "skynet example/config"]

#打包镜像:版本号保持与skynet一致
# docker build . -t pluto:1.7.0
# docker run -it --rm pluto
# docker exec -it pluto bash
# 删除所有 容器和镜像 
# docker system prune --all --force