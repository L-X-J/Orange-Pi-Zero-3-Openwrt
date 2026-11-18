# Orange-Pi-Zero-3-Openwrt

香橙派 **Orange Pi Zero 3**（全志 H618，Cortex-A53）自动云编译 OpenWrt 固件。

## 这个版本是什么

- **定位**：1GB 内存版 Orange Pi Zero 3 专用的**精简旁路由 / 科学上网固件**
- **源码**：[ImmortalWrt](https://github.com/immortalwrt/immortalwrt) `openwrt-24.10` 分支，Linux 6.6 LTS
- **代理**：只保留 **OpenClash**（Clash Meta 内核），PassWall / PassWall2 / SSR+ / xray / sing-box 全部移除
- **网络角色**：默认旁路由（静态 `192.168.1.250`，自身 DHCP 关闭）；也可切换为主路由模式（`eth0=WAN`、Wi-Fi=LAN、`192.168.44.1`、DHCP 开启）
- **当前实测**：1GB 版本、OpenClash 正常运行时（旁路由/路由模式），**CPU 占用低于 30%**
- **旁路由模式**下，使用 OpenClash 的客户端必须把 DNS 改成 `192.168.1.250`（网关也要改）；**路由模式**由 Pi 的 DHCP 自动下发 `192.168.44.1`，不用手动改
- **默认管理地址**：旁路由 `http://192.168.1.250`；路由模式 `http://192.168.44.1`

## 版本特点

| 项目 | 说明 |
|---|---|
| 目标硬件 | Orange Pi Zero 3（H618），**当前按 1GB 版本裁剪和验证**；同一镜像也可用于 1.5GB / 2GB / 4GB |
| 内核 | ImmortalWrt `openwrt-24.10` / Linux 6.6 LTS，避开旧 6.18 固件在 `S19firewall` 的 `__slab_free` panic |
| 代理插件 | **OpenClash only**，以及 `dnsmasq-full`、`ruby`、`ip-full`、nftables TProxy 等必要依赖 |
| 网络模式 | 默认旁路由：`eth0` + Wi-Fi 都在 `br-lan`，静态 `192.168.1.250/24`，DHCP/RA 关闭；可切换主路由模式（`eth0=WAN`、Wi-Fi=LAN、`192.168.44.1`、DHCP 开启） |
| 内存优化 | `zram-swap` + `kmod-zram`，减轻 OpenClash 更新规则/大流量时的 OOM 风险 |
| Wi-Fi | 板载 AW859A / UWE5622，通过 24.10/6.6 backport 驱动；Wi-Fi 为尽力支持 |
| 管理工具 | iStore（`luci-app-store`）、quickstart、ttyd、UPnP、htop、iperf3、简体中文 |
| 已剔除 | Docker、Samba、aria2/AriaNg、adbyby、网易云解锁、USB 打印、ZeroTier、WOL 等重型/无关套件 |
| 构建校验 | workflow 会检查代理栈、LuCI Lua 运行库、自定义脚本的 UCI 引号，以及精简包是否被重新拉回 |

> 目前 CPU 占用低于 30% 是 1GB 版本在 OpenClash 正常运行时（旁路由/路由模式）的实测结果；大流量、规则集很多或 Wi-Fi 驱动异常时仍可能升高，排查见下文。
>
> iStore/quickstart 来自 `kenzok8/openwrt-packages`（24.10 上游 luci 已不再提供）；OpenClash 来自 24.10 luci feed；`kenzok8/small` feed 已移除。

## 当前适配硬件

- **Orange Pi Zero 3 1GB**：当前固件就是按这个容量做的裁剪和验证
- 1.5GB / 2GB / 4GB 使用同一镜像，不需要按容量选版本
- 板载 AW859A（UWE5622）Wi-Fi：24.10 上游不包含该驱动，`diy-part1.sh` 会拉取固定 commit 的 24.10/6.6 backport
- 旁路由模式下网口本身就是 LAN，Wi-Fi 不稳定时可以直接用有线

## 快速开始

> 下面默认按**旁路由模式**写；如果已经切到路由模式，访问 `http://192.168.44.1`，电脑保持 DHCP 即可。

1. 刷入 Releases 里的镜像（建议 4GB 以上 SD 卡）
2. 网线接主路由/交换机，确保电脑也在 `192.168.1.0/24`
3. 浏览器打开 `http://192.168.1.250`，SSH 用 `ssh root@192.168.1.250`
4. 要让某台设备走 OpenClash：**网关和 DNS 都必须改成 `192.168.1.250`**；只改网关不够，DNS 会绕过 OpenClash
5. 不想走代理的设备保持网关 `192.168.1.1` 即可

默认 Wi-Fi：SSID `ImmortalWrt`，无密码；旁路由模式下 Wi-Fi 客户端从主路由拿 DHCP。

## 旁路由模式下：使用 OpenClash 必须改电脑的 DNS

> 如果你已经切到**主路由模式**（LAN `192.168.44.1`、Pi 自己发 DHCP），电脑保持 DHCP 即可，不需要手动改 DNS；本节只适用于旁路由模式。

旁路由模式下，OpenClash 只能接管“经过它”的流量和 DNS。电脑如果还使用主路由下发的 DNS（`192.168.1.1`），DNS 查询会直接在同网段发给 `192.168.1.1`，根本不经过 `192.168.1.250`，OpenClash 看不到，也就无法做 Fake-IP、分流和防污染。

所以，**要走 OpenClash 的电脑/手机必须同时改这两项**：

| 设置 | 值 |
|---|---|
| 网关 / 路由器 | `192.168.1.250` |
| DNS | `192.168.1.250` |

- **只改 DNS 不改网关**：流量不经过 Pi，OpenClash 不生效
- **只改网关不改 DNS**：DNS 仍然直连 `192.168.1.1`，OpenClash 的 DNS 劫持/Fake-IP 不生效，容易出现 DNS 污染、分流错误、部分网站打不开
- **DNS 和网关都改**：才是完整的旁路由 + OpenClash 用法

### macOS 设置

系统设置 → 网络 → Wi-Fi → 详细信息：

- **TCP/IP**：配置 IPv4 选“手动”，IP 填 `192.168.1.x`（不要用 250，避免和 Pi 冲突），子网掩码 `255.255.255.0`，路由器填 `192.168.1.250`
- **DNS**：只保留/添加 `192.168.1.250`，并拖到第一位
- 点“好”保存

如果只想先测 DNS，也可以保留 DHCP，只在 **DNS** 里加 `192.168.1.250`；但网关仍是 `192.168.1.1` 时 OpenClash 不会接管流量。

### Windows 设置

设置 → 网络和 Internet → Wi-Fi/以太网 → 硬件属性 → DNS 服务器分配 → 编辑 → 手动：

- 打开 IPv4
- 首选 DNS：`192.168.1.250`

然后在网卡的 IPv4 属性里，把**默认网关**也改成 `192.168.1.250`。

### iPhone / Android 设置

Wi-Fi → 当前网络 → 配置 IP → 手动：

- IP：`192.168.1.x`
- 路由器/网关：`192.168.1.250`
- DNS：`192.168.1.250`

### 验证 DNS 是否生效

在电脑上执行：

```sh
nslookup www.baidu.com 192.168.1.250
```

macOS 也可以：

```sh
scutil --dns | grep nameserver
dig @192.168.1.250 www.baidu.com
```

然后在 OpenClash 的“日志”里应该能看到对应的 DNS 查询；如果看不到，说明电脑的 DNS 还没指到 `192.168.1.250`。

### 更省事的做法

如果主路由的 DHCP 支持自定义网关/DNS，直接把下发的值改成：

- 网关：`192.168.1.250`
- DNS：`192.168.1.250`

这样所有设备自动生效，不用逐台改；不想走代理的设备再单独设回 `192.168.1.1`。

## 网络拓扑（旁路由模式）

主路由/光猫继续做 DHCP 和上网网关，Zero 3 作为同网段的旁路由：

```text
主路由/光猫 192.168.1.1  (DHCP / 上网网关)
   ├── 电脑 / 手机       192.168.1.x
   └── Orange Pi Zero 3  192.168.1.250  (静态 IP，DHCP 关闭)
          └── Wi-Fi AP   同一个 LAN
```

- **LuCI**：`http://192.168.1.250`
- **SSH**：`ssh root@192.168.1.250`
- 首次启动自动执行 `files/etc/uci-defaults/99-orangepi-bypass`，串口会打印管理地址
- Pi 的 DHCP 服务关闭，避免和主路由抢 DHCP；`eth0` 和 Wi-Fi 都在 `br-lan`
- Pi 自己的网关/DNS 指向 `192.168.1.1`
- 已关闭 firewall flow offloading 和 ICMP redirect，避免客户端绕过 OpenClash
- **客户端必须把网关 + DNS 都设为 `192.168.1.250`**；只改网关不改 DNS 会绕过 OpenClash 的 DNS 劫持/Fake-IP
- 主路由的 DHCP 池如果包含 `192.168.1.250`，请把 250 排除/保留

## 手动改成旁路由（旧镜像）

如果已经刷了旧镜像、暂时不想重刷，可在串口/SSH 执行：

```sh
i=0
while uci -q get network.@device[$i] >/dev/null; do
  if [ "$(uci -q get network.@device[$i].name)" = "br-lan" ]; then
    uci -q delete network.@device[$i].bridge_empty
    ports="$(uci -q get network.@device[$i].ports)"
    case " $ports " in *" eth0 "*) ;; *) uci add_list network.@device[$i].ports=eth0;; esac
  fi
  i=$((i+1))
done
uci set network.lan.device=br-lan
uci set network.lan.proto=static
uci set network.lan.ipaddr=192.168.1.250
uci set network.lan.netmask=255.255.255.0
uci set network.lan.gateway=192.168.1.1
uci set network.lan.dns=192.168.1.1
uci -q delete network.lan.ifname
uci -q delete network.lan.type
uci -q delete network.lan.ip6assign
uci -q delete network.wan
uci -q delete network.wan6
uci set dhcp.lan.ignore=1
uci set firewall.@defaults[0].flow_offloading=0
uci set firewall.@defaults[0].flow_offloading_hw=0
uci commit network
uci commit dhcp
uci commit firewall
/etc/init.d/network restart
wifi reload
```

## 切换到路由模式（主路由）

默认固件是旁路由；如果你想让 Pi 自己做 NAT/DHCP、光猫只做 WAN 上游，按下面切。

切换后：

- `eth0` = WAN（接光猫/主路由 LAN）
- Wi-Fi = LAN，`192.168.44.1/24`
- Pi 开 DHCP，客户端自动拿 `192.168.44.x`，网关/DNS 自动 `192.168.44.1`
- 管理地址变成 `192.168.44.1`
- 网口变成 WAN，电脑要连 Pi 的 Wi-Fi（或外接 USB 网卡）才能进 LAN

> 切换会改管理 IP，SSH 会断；最好用串口执行。
>
> 手动切换只在当前系统生效；重新刷机会再次执行 `99-orangepi-bypass` 回到旁路由。要默认路由模式，需要改这个脚本或加切换脚本。

切换前先确认防火墙是干净的：

```sh
fw4 print 2>&1 | grep -E 'invalid|skipped' || echo 'firewall clean'
```

### 第 1 步：把 eth0 从 LAN 桥移出，br-lan 只留给 Wi-Fi

```sh
i=0; while uci -q get "network.@device[$i]" >/dev/null 2>&1; do [ "$(uci -q get "network.@device[$i].name")" = "br-lan" ] && { uci -q delete "network.@device[$i].ports"; uci set "network.@device[$i].bridge_empty=1"; }; i=$((i+1)); done
```

### 第 2 步：LAN 改成 192.168.44.1，去掉 LAN 的网关/DNS

```sh
uci set network.lan.device=br-lan; uci set network.lan.proto=static; uci set network.lan.ipaddr=192.168.44.1; uci set network.lan.netmask=255.255.255.0; uci set network.lan.ip6assign=60; uci -q delete network.lan.gateway; uci -q delete network.lan.dns; uci -q delete network.lan.ifname; uci -q delete network.lan.type; uci -q delete network.lan.ports
```

### 第 3 步：eth0 改成 WAN，走光猫 DHCP

```sh
uci -q delete network.wan; uci set network.wan=interface; uci set network.wan.device=eth0; uci set network.wan.proto=dhcp; uci -q delete network.wan6; uci set network.wan6=interface; uci set network.wan6.device=eth0; uci set network.wan6.proto=dhcpv6
```

### 第 4 步：打开 LAN DHCP/RA

```sh
uci set dhcp.lan.ignore=0; uci set dhcp.lan.dhcpv4=server; uci set dhcp.lan.dhcpv6=server; uci set dhcp.lan.ra=server; uci set dhcp.lan.start=100; uci set dhcp.lan.limit=150; uci set dhcp.lan.leasetime=12h
```

### 第 5 步：关闭 flow offloading（OpenClash 需要）

```sh
uci set firewall.@defaults[0].flow_offloading=0; uci set firewall.@defaults[0].flow_offloading_hw=0
```

### 第 6 步：提交配置

```sh
uci commit network; uci commit dhcp; uci commit firewall
```

### 第 7 步：重启网络和 Wi-Fi

```sh
/etc/init.d/network restart; wifi reload
```

> 执行后管理地址从 `192.168.1.250` 变成 `192.168.44.1`，SSH 会断。
>
> `wifi reload` 偶尔报 `Command failed: Not found`，只要 `phy0-ap0` 还在 forwarding 就可以忽略；必要时再执行 `/sbin/wifi reload`。

### 第 8 步：重新连上后验证

```sh
ip -4 addr show br-lan; ip -4 addr show eth0; uci show network | grep -E 'lan\.(ipaddr|proto|device)|wan\.(proto|device)'
```

预期：

- `br-lan` 是 `192.168.44.1/24`
- `eth0` 从光猫拿到 `192.168.1.x`
- 电脑访问 `http://192.168.44.1`、`ssh root@192.168.44.1`
- 路由模式下 DHCP 自动下发 `44.1` 作为网关/DNS，电脑不用再手动改 DNS

切回旁路由用上面的“手动改成旁路由”一节；管理地址会回到 `192.168.1.250`。

## 防火墙 LAN zone 修复

如果 `fw4 print` 出现：

```text
Section @zone[0] (lan) option 'input' specifies invalid value ''ACCEPT''
Section @zone[0] (lan) skipped due to invalid options
```

说明 `lan` zone 的 `input/output/forward` 被写成了带单引号的 `'ACCEPT'`，整个 LAN zone 会被跳过，表现就是 **Pi 能 ping 电脑、电脑访问不了 Pi**。修复：

```sh
uci set firewall.@zone[0].input=ACCEPT
uci set firewall.@zone[0].output=ACCEPT
uci set firewall.@zone[0].forward=ACCEPT
uci commit firewall
fw4 reload
```

先确认 `@zone[0]` 是 `lan`；不是的话把下标换成对应 zone。

## CPU 占用与异常排查

当前 1GB 版本在 OpenClash 正常运行时（旁路由/路由模式）**实测 CPU 占用低于 30%**。如果出现持续高位，先看是谁在跑：

```sh
top -bn1 | head -30
ps w | grep -E 'clash|openclash|quickstart|taskd|dnsmasq|hostapd|sprdwl'
dmesg | grep -iE 'sprdwl|tx err|wcn' | tail -30
```

按结果处理：

- `ksoftirqd` / `sprdwl` 高：UWE5622 Wi-Fi 驱动在 AP 模式下忙。先切 2.4G：

  ```sh
  uci set wireless.radio0.band='2g'
  uci set wireless.radio0.channel='6'
  uci set wireless.radio0.htmode='HT40'
  uci commit wireless
  wifi reload
  ```

  仍高的话用串口 `wifi down` 对比；旁路由模式下有线口本身在 LAN，可以直接用网线。

- `quickstart` 高：iStore 快捷向导后台。不用向导可以停掉：

  ```sh
  /etc/init.d/quickstart stop
  /etc/init.d/quickstart disable
  ```

- `clash` / `openclash` 高：规则/订阅/DNS 有环路。先在 LuCI 停止 OpenClash，或串口 `/etc/init.d/openclash stop` 对比。

- `dnsmasq` 高：通常是 OpenClash DNS 劫持/上游成环，检查 OpenClash 的 DNS 设置。

- `taskd` / `istore`：iStore 本身很轻；如果确认是它，下一版可以把 iStore/quickstart 一并裁掉。

## 常见问题

### 打开 LuCI 报 `module 'luci.cbi.datatypes' not found`

这是 LuCI 的 Lua 兼容层缺失（`luci-compat` / `luci-lua-runtime`）。SSH 执行：

```sh
opkg update
opkg install luci-compat luci-lua-runtime
rm -rf /tmp/luci-*
/etc/init.d/uhttpd restart
```

最新固件已经显式包含这两个包，并在构建后校验 rootfs 里的 `luci/cbi/datatypes.lua` 和 `luci/model/uci.lua`。

### `fw4 print` 提示 `lan` zone 的 `input` 值是 `''ACCEPT''`

见上面的“防火墙 LAN zone 修复”。

## 1GB 启动与刷写注意

本固件针对 **1GB 版本** 裁剪和验证，但同一镜像也适用于 1.5GB / 2GB / 4GB。真正容易出问题的是 U-Boot 的 DRAM 探测，不是 OpenWrt 本身：

- 老 U-Boot（OpenWrt 23.05 / 24.10 用的 2024.01）经常把 **1GB 认成 2GB**，内核按 2GB 建页表，
  一碰到 1GB 以上的地址就 panic / 卡死；1.5GB 板更典型（已知问题，见 OpenWrt #18087、DietPi #7242）。
- 本仓回到 `openwrt-24.10` 后，U-Boot 由该分支的 sunxi 目标提供，仍是 **2024.01** 一代，
  因此 1GB 误判风险依然存在；**不要**把它当成"1GB 版随便刷"的保证。串口看到 `DRAM: 2048 MiB`
  而板子是 1GB 时，先加 `mem=1024M` 救急，长期方案是换用新版 U-Boot。

仍然起不来时，接串口（**115200 8N1**，Zero 3 的 debug UART 是板边 3 pin）看前几行：

| 串口现象 | 结论 | 处理 |
|---|---|---|
| 完全没有输出，或只有 `U-Boot SPL 20xx.xx` 一行就停 | SPL 阶段 DRAM 初始化失败（时序/供电） | 换 5V/2A 以上电源、换卡重写；仍不行需要 720MHz 版 U-Boot |
| 打印 `DRAM: 2048 MiB` 而板子是 1GB | 容量仍是误判 | 用新版 U-Boot；临时可在 bootargs 里加 `mem=1024M` 救急 |
| 打印 `DRAM: 1024 MiB` 后卡住 | 不是内存问题 | 见下面三条刷写错误 |

刷写最常见的三个错：

1. **没解压**：直接把 `.img.gz` 写进卡（要写解压后的 `.img`）。
2. **卡太小**：镜像是 16MB FAT + 2GB rootfs，原始大小约 2.1GB，**2GB 卡写一半就断**，用 4GB 以上。
3. **写错文件**：`initramfs-kernel.bin` 是内存运行镜像，不是 SD 镜像，写了也起不来。

## 自动编译

- 源码有更新时每 18 小时自动检查并触发编译（Update Checker）
- 也可在 Actions 页面手动运行 `Build OpenWrt Zero 3`
- 编译完成后自动上传 Release（仅编译成功才发布），自动保留最近 3 个版本
- 构建时会校验代理栈、`luci-compat` / `luci-lua-runtime`、自定义 UCI 脚本引号和精简包是否被重新拉回

## 自定义插件

Fork 后修改 `orange-pi-zero3.config` 中的 `CONFIG_PACKAGE_*` 即可。

1GB 版本请谨慎增加常驻服务，新增插件会直接占用内存和 CPU。

## 致谢

- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
- [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt)
- [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
- [kenzok8/openwrt-packages](https://github.com/kenzok8/openwrt-packages)
- [DeepAQ/openwrt-uwe5622-sunxi](https://github.com/DeepAQ/openwrt-uwe5622-sunxi)（AW859A / UWE5622 的 24.10/6.6 驱动 backport）

## License

[MIT](./LICENSE)
