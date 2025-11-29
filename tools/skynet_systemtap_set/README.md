说明
============

Skynet是一个在线游戏框架，为了节省内存占用使用了共享proto的lua vm。
这个工具利用systemtap抓取lua栈，分析函数代码的热路径。可以根据skynet里的服务id来单独看一个服务的lua栈。


使用依赖
=====
skynet >= 1.4.0

lua 5.4

systemtap


使用方法
=====
```shell
./monitor_skynet_and_gen_svg.sh skynet_pid skynet_bin_path serviceid seconds proj_path
```
确保 lua 编译时，加了 -g 参数


参数说明
=====
| 字段 | 说明 |
| ---- | ---- |
| skynet_pid | skynet进程id |
| skynet_bin_path | skynet程序地址 |
| serviceid | skynet服务id（10进制）|
| seconds | 数据采集时间 |
| proj_path | 项目路径 |

