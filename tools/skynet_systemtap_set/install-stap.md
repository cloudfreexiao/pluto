## SystemTap 与内核符号安装指南（Ubuntu 22.04/HWE 6.8 实战）

### 一、概览
- SystemTap 用于内核/用户态动态追踪，内核态路径需要：
  - 与当前内核匹配的头文件：`linux-headers-$(uname -r)`
  - 与当前内核匹配的调试符号包：`linux-image-$(uname -r)-dbgsym` 或 `linux-image-unsigned-$(uname -r)-dbgsym`
- Ubuntu 22.04 自带的 SystemTap 旧版（4.6）对 HWE 6.8 内核不完全兼容，建议安装新版（源码安装 5.x），或切回 GA 5.15 内核配套发行版 SystemTap。

### 二、路径 A：发行版 SystemTap + 安装内核符号（适用于 GA 5.15 或兼容场景）
```
sudo apt update

# 基础依赖
sudo apt install -y systemtap systemtap-runtime linux-headers-$(uname -r) \
  build-essential elfutils dwarves systemtap-sdt-dev

# 启用 ddebs（安装内核 dbgsym）
sudo apt install -y ubuntu-dbgsym-keyring || true
echo "deb http://ddebs.ubuntu.com $(lsb_release -cs) main restricted universe multiverse" | sudo tee /etc/apt/sources.list.d/ddebs.list
echo "deb http://ddebs.ubuntu.com $(lsb_release -cs)-updates main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list.d/ddebs.list
# 注：jammy-security 在 ddebs 可能 404，可省略；若已添加但报错可忽略或删除该行
# echo "deb http://ddebs.ubuntu.com $(lsb_release -cs)-security main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list.d/ddebs.list
sudo apt update

# 安装与当前内核匹配的调试符号（两种命名，择其一存在者）
sudo apt install -y linux-image-$(uname -r)-dbgsym || \
  sudo apt install -y linux-image-unsigned-$(uname -r)-dbgsym
```

### 三、路径 B：源码安装最新 SystemTap（推荐用于 HWE 6.8 内核）
1) 安装构建依赖（含我们实战补齐的全部组件）
```
sudo apt update
sudo apt install -y git build-essential pkg-config \
  elfutils libdw-dev libelf-dev libssl-dev zlib1g-dev libsqlite3-dev \
  linux-headers-$(uname -r) gcc-12 g++-12 \
  libboost-dev \
  python3-dev python3-distutils python3-setuptools python3-wheel \
  gettext
```
说明：
- gcc-12/g++-12：与内核构建器一致，消除“compiler differs”类告警/问题。
- libboost-dev：提供 `boost/asio/thread_pool.hpp`、`boost/asio/post.hpp`（编译期必须）。
- python3-*：解决 `distutils.sysconfig`、`setuptools` 缺失等 Python 绑定构建问题。
- gettext：解决 `po` 目录生成 `.gmo` 失败（`msgfmt` 等工具）。如不需要本地化，可用 `--disable-nls` 跳过。

2) 获取并构建安装（默认安装到 `/usr/local`）
```
git clone git://sourceware.org/git/systemtap.git
cd systemtap
./configure --disable-werror   # 避免把警告当错误
# 若想跳过本地化构建，可加： --disable-nls
make -j"$(nproc)"
sudo make install

# 验证版本与安装路径优先级
/usr/local/bin/stap -V
which -a stap
```

### 四、安装内核符号（dbgsym）要点
- 需先安装 `ubuntu-dbgsym-keyring` 并添加 `ddebs` 源；`jammy-security` 通道在 ddebs 上可能不存在，可忽略。
- 按当前正在运行的内核版本安装匹配的 `-dbgsym` 包：
```
sudo apt install -y linux-headers-$(uname -r)
sudo apt install -y linux-image-$(uname -r)-dbgsym || \
  sudo apt install -y linux-image-unsigned-$(uname -r)-dbgsym
```

### 五、权限与自检
```
# 将当前用户加入 SystemTap 相关组（避免每次 sudo）
sudo usermod -aG stapusr,stapsys,stapdev $USER
# 重新登录生效，或执行 newgrp stapusr 等临时生效

# 简单自检（非 root 需在组内；或直接 sudo）
sudo stap -v -e 'probe begin { printf("hello SystemTap\n"); exit() }'
```

### 六、常见问题与排查
- 编译器不匹配告警：安装 `gcc-12 g++-12`（Ubuntu 22.04 HWE 6.8 内核常见）。
- Pass 4 大量内核 API 报错：SystemTap 旧版与 6.8 内核不兼容，改走“路径 B：源码安装 5.x”。
- Python `distutils`/`setuptools` 缺失：安装 `python3-distutils python3-setuptools python3-dev python3-wheel` 再编译。
- 缺少 Boost.Asio 头：安装 `libboost-dev`。
- `po` 生成 `.gmo` 报错：安装 `gettext`，或 `./configure --disable-nls`。
- ddebs `jammy-security` 404：可忽略或删除该源行，仅保留 `main` 与 `-updates`。
- PATH 指向旧版 `/usr/bin/stap`：优先使用 `/usr/local/bin/stap` 或调整 PATH。

### 七、可选方案：切回 GA 5.15 内核
若不想源码安装，可安装 GA 内核并重启选择 5.15：
```
sudo apt install -y linux-generic
```
使用发行版 SystemTap 即可配合 5.15 内核稳定运行。

### 八、快速清单（我们本次实际用到/建议安装的组件）
- 基础：`systemtap systemtap-runtime systemtap-sdt-dev linux-headers-$(uname -r) elfutils dwarves build-essential`
- 调试符号：`ubuntu-dbgsym-keyring` + ddebs 源 + `linux-image-$(uname -r)-dbgsym` 或 `linux-image-unsigned-$(uname -r)-dbgsym`
- 源码构建补齐：`git pkg-config libdw-dev libelf-dev libssl-dev zlib1g-dev libsqlite3-dev`
- 编译器匹配：`gcc-12 g++-12`
- Boost：`libboost-dev`
- Python：`python3-dev python3-distutils python3-setuptools python3-wheel`
- 本地化工具（可选）：`gettext`

完成后，使用 `/usr/local/bin/stap -V` 确认已是 5.x，并跑“hello SystemTap”脚本验证即可。