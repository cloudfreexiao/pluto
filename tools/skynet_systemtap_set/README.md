Introduction
============
[Skynet](https://github.com/cloudwu/skynet/) a lightweight online game framework with customize lua vm. The lua proto is in SharedProto. This script extract skynet's customize lua vm stack by systemtap. It can print logs to draw flamegraph.

Skynet是一个在线游戏框架，为了节省内存占用使用了共享proto的lua vm。这个工具利用systemtap抓取lua栈，分析函数代码的热路径。可以根据skynet里的服务id来单独看一个服务的lua栈。

Usage
=====
usermod -G stapusr,stapdev xxxx
newgrp stapusr
newgrp xxxx
newgrp stapdev
newgrp xxxx

=====
 ```shell
 #change the skynet bin source to your path, and add -g to 3rd/lua Makefile in skynet project
./monitor_skynet_and_gen_svg.sh skynet_pid skynet_bin_path serviceid_in_decimal seconds proj_path
 ```
# dump_lua_function

Convert lua stack backtrace file from filename:lineno to filename:funcname. Fail on nested function definition.

Usage:
======
```lua
lua dump.lua project_src_dir your_lua_bt_file | tee new_bt_filename
```
