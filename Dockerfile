FROM ubuntu:24.04

LABEL maintainer="https://github.com/cloudfreexiao"

RUN apt update
RUN apt install -y make build-essential cmake gcc g++ git sudo
RUN apt install -y zlib1g-dev libbz2-dev libreadline-dev llvm libfaketime libcapstone-dev libelf-dev
RUN apt install -y rlwrap curl wget valgrind zip unzip
RUN apt upgrade -y
RUN apt autoremove
RUN apt-get clean

ENV RuntimeDir=/opt/workspace
ENV BuildDir=/tmp/pluto

RUN mkdir -p ${BuildDir}
RUN mkdir -p ${RuntimeDir}

COPY . ${BuildDir}
WORKDIR ${BuildDir}
RUN sh build.sh
RUN cp -rf build/pluto ${RuntimeDir}
RUN rm -rf ${BuildDir}

WORKDIR ${RuntimeDir}/pluto
CMD ["sh", "-c", "skynet example/config"]

#打包镜像
# docker build . -t plu
# 删除所有 容器和镜像 
# docker system prune --all --force
# docker-compose up -dV
# docker exec -it pluto bash