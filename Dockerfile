FROM ubuntu:24.04

LABEL maintainer="https://github.com/cloudfreexiao"

ENV DEBIAN_FRONTEND=noninteractive
ENV CC=/usr/bin/gcc-13
ENV CXX=/usr/bin/g++-13
ENV PYTHON_MAJOR_VERSION=13
ENV PYTHON_MINOR_VERSION=0
ENV PYTHON_DEVELOPMENT_STAGE=
ENV PYTHON_VERSION=3.${PYTHON_MAJOR_VERSION}.${PYTHON_MINOR_VERSION}${PYTHON_DEVELOPMENT_STAGE}

RUN apt update
RUN apt install -y cmake make gcc g++ valgrind git zip unzip wget sudo rlwrap
RUN apt install -y build-essential zlib1g-dev libbz2-dev libreadline-dev curl llvm libfaketime libcapstone-dev libelf-dev
RUN apt update
RUN apt upgrade -y
RUN apt autoremove

RUN wget https://github.com/python/cpython/archive/refs/tags/v${PYTHON_VERSION}.zip
RUN unzip v${PYTHON_VERSION}.zip -d python_source
RUN cd python_source/cpython-${PYTHON_VERSION} && ./configure --enable-optimizations --with-lto --with-computed-gotos --disable-gil --with-mimalloc && make altinstall
RUN update-alternatives --install /usr/bin/python3 python3 $(readlink -f $(which python3)) 0
RUN update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.${PYTHON_MAJOR_VERSION} 1
RUN update-alternatives --install /usr/bin/pip3 pip3 /usr/local/bin/pip3.${PYTHON_MAJOR_VERSION} 1
RUN update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1
RUN python3 -m pip install --upgrade pip
RUN rm -rf v${PYTHON_VERSION}.zip
RUN rm -rf python_source

ENV Pluto  /opt/pluto
ENV Pluto_Build_Dir /tmp/pluto
ENV PATH ${Pluto}/bin:${PATH}

RUN mkdir -p ${Pluto}
RUN mkdir -p ${Pluto_Build_Dir}

COPY . ${Pluto_Build_Dir}

WORKDIR ${Pluto_Build_Dir}

RUN sh build.sh && \
    cp -rf build/pluto ${Pluto} && \
    rm -rf ${Pluto_Build_Dir} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR ${Pluto}

CMD ["sh", "-c", "${Pluto}/skynet ${Pluto}/example/config"]

# 删除所有 容器和镜像 
# docker stop $(docker ps -a -q) && docker system prune --all --force