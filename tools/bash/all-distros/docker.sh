#!/usr/bin/env bash

# 停止并删除所有容器
docker rm -f $(docker ps -aq)

# 删除所有镜像
docker rmi -f $(docker images -q)

# 删除未使用的网络和卷
docker network prune -f
docker volume prune -f

echo "所有容器和镜像已删除!"

# docker-compose up -dV

# echo "容器已启动!"


