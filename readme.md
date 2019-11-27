## 原理
通过 dns日志来获得目标，通过nf_conntrack 80/443判断是否允许httping，允许的整个域名所有ip进行httping,如果超时或者rst，将结果加入ipset gfwlist，并且重试httping，如果不可用会取消加入ipset gfwlist</br>
## 安装 
openwrt 免手动https://github.com/rufengsuixing/luci-app-autoipsetadder <br>
依赖：httping,awk,ipset,curl,tail,stdbuf
</br>
安装httping：`opkg install httping`<br>
安装stdbuf：`opkg install coreutils-stdbuf`
</br>
- 二选一设置dns服务器日志记录：
  - smartdns：
  ```
  audit-enable yes
  audit-file /var/log/smartdns-audit.log
  audit-size 64K
  ```
  - dnsmasq：</br>
  以下开启dnsmasq的dns日志,并调整到需要的详细程度
  ```
  uci set dhcp.@dnsmasq[0].logfacility='/tmp/dnsmasq.log'
  uci delete dhcp.@dnsmasq[0].logqueries
  echo log-queries >> /etc/dnsmasq.conf
  uci commit dhcp
  ```
- 对应你的dns服务程序复制autoaddlist.sh,testip.sh,delayretest.sh到/usr/bin/
- 修改权限
  ```
  chmod 755 /usr/bin/autoaddlist.sh
  chmod 755 /usr/bin/testip.sh
  chmod 755 /usr/bin/delayretest.sh
  ```
- 手动运行`/usr/bin/autoaddlist.sh &`<br>
  或者记录日志`nohup /usr/bin/autoaddlist.sh >>/tmp/nohup.out &`
- crontab备用指令：
  每小时删除日志
  ```
  0 * * * * rm -f /tmp/log/smartdns*.gz
  0 * * * * echo "" > /tmp/dnsmasq.log
  ```
  停止指令备用：
  ```
  killall tail
  killall awk
  ```
- debug用于寻找ipset gfwlist中的符合ipset china ip在/tmp/nohup.out中的日志<br>
  `debugip.sh`
### 本程序输出日志：

|输出|解释
| -|-
| `[ip] [domain] is in gfwlist pass"` | ip已经在ipset里
| `[ip] [domain] [port]` | 记录检测到的可httping
| `[浮点数值]`/`failed,` | httping得到的延迟结果，异步结果无参考价值
| `can not connect autoaddip [ip] [domain]` | 直连无回应超时
| `doname rst autoaddip [ip] [domain]` | 疑似直连rst
| `proxy can not connect autodelip [ip] [domain]` | ipset后连接无回应超时
| `doname proxy rst autodelip [ip] [domain]` | 疑似ipset后连接rst
| `direct so slow autoaddip [ip] [domain]` | 直连有回应3s超时
| `direct Connection refused autoaddip [ip] [domain]` | 直连拒绝连接
| `change back to direct [ip] [domain]` | 尝试都失败或者都3s超时
| `direct ssl so slow autoaddip [ip] [domain]` | httping超时无效bug被触发，ssl时间很久但成功了
| `pass by packets=[number] [ip] [domain]` | 实验性质，在请求前看已经发送的包的数量>12放过
| `[ip] [domain] pass by same domain ok` | 如果有一个可连接同域名ip放过
| `warning china [ip] [domain] is in gfwlist` | 检测到china ipset与gfwlist重合
| `ping packet loss autoaddip [ip] [domain]` | httping成功后，ping 5个包，返回收到1-3个包触发

注：同ip如果httping过不会重复探测，也不会有日志。</br>
[ ]httping在ssl上有问题，包括超时失效卡住和cloudflare的兼容不好，考虑之后用curl全部重写
