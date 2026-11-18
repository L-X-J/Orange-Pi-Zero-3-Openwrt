# OPi-Mini (Orange Pi Zero 3 · ImmortalWrt)

香橙派 **Orange Pi Zero 3**（全志 H618，Cortex-A53）自动云编译的 **1GB 版专用精简软路由固件**。

固件名：`immortalwrt-opi-mini-openclash-sunxi-cortexa53-xunlong_orangepi-zero3-squashfs-sdcard.img`

## 这个版本是什么

- **定位**：1GB 内存版 Orange Pi Zero 3 的**路由模式**（主路由）固件，自带 OpenClash
- **源码**：[ImmortalWrt](https://github.com/immortalwrt/immortalwrt) `openwrt-24.10`，Linux 6.6 LTS
- **代理**：**只保留 OpenClash**，并**内置 Clash Meta 内核**，刷完不用再下载内核
- **网络模式**：路由模式 —— `eth0` 做 WAN，Wi-Fi 做 LAN，`192.168.44.1`，自带 DHCP
- **Wi-Fi**：SSID `OPi-Mini`，密码 `aa88888888`，2.4GHz / WPA2
- **当前实测**：1GB 版本 + OpenClash 正常运行时，**CPU 占用低于 30%**

## 版本特点

| 项目 | 说明 |
|---|---|
| 目标硬件 | Orange Pi Zero 3（H618），**按 1GB 版本裁剪和验证**；同一镜像也可用于 1.5 / 2 / 4GB |
| 内核 | ImmortalWrt `openwrt-24.10` / Linux 6.6 LTS，避开旧 6.18 固件在 `S19firewall` 的 `__slab_free` panic |
| 网络模式 | 路由模式：`eth0` = WAN（DHCP），Wi-Fi = LAN `192.168.44.1/24`，LAN DHCP/RA 开启 |
| Wi-Fi | 板载 AW859A / UWE5622，24.10/6.6 backport 驱动；默认 **2.4GHz** 以兼容手机/电脑 |
| Wi-Fi 账号 | SSID `OPi-Mini` / 密码 `aa88888888`（WPA2-PSK） |
| 代理插件 | **OpenClash only**，外加 `dnsmasq-full`、`ruby`、`ip-full`、nftables TProxy 等必要依赖 |
| Clash 内核 | **内置** OpenClash Meta 内核（`/etc/openclash/core/clash_meta`，aarch64 预编译） |
| 内存优化 | `zram-swap` + `kmod-zram`，降低 OpenClash 更新规则/大流量时的 OOM 风险 |
| 管理工具 | iStore（`luci-app-store`）、quickstart、ttyd、UPnP、htop、iperf3、简体中文 |
| 已剔除 | PassWall / PassWall2 / SSR+ / xray / sing-box、Docker、Samba、aria2、adbyby、网易云解锁、USB 打印、ZeroTier、WOL |
| 构建校验 | workflow 校验代理栈、内置内核、LuCI Lua 运行库、UCI 引号、固件文件名 |

> CPU 低于 30% 是 1GB 版本 + OpenClash 正常运行的实测结果；大流量、规则集过多或 Wi-Fi 驱动异常时仍可能升高，排查见下文。

## 网络拓扑（路由模式）

Pi 自己做 NAT/DHCP，光猫/上游只提供 WAN：

```text
光猫 / 上游路由器
   └── eth0 (WAN, DHCP 客户端)
         Orange Pi Zero 3   192.168.44.1
           └── Wi-Fi AP     OPi-Mini / aa88888888
                  ├── 电脑   192.168.44.x
                  └── 手机   192.168.44.x
```

- **LuCI**：`http://192.168.44.1`
- **SSH**：`ssh root@192.168.44.1`
- 客户端连 `OPi-Mini` 后自动拿 `192.168.44.x`，网关/DNS 自动是 `192.168.44.1`
- **路由模式不需要手动改电脑 DNS**，所有 LAN 客户端默认走 OpenClash

## 刷机与首次启动

1. 下载 Releases 里的 `.img`（已解压；`.img.gz` 需先解压，建议 4GB 以上 SD 卡）
2. 用 balenaEtcher 或 `dd` 写入 SD 卡
3. 网线接 Pi 的 `eth0`（接光猫/上游 LAN）
4. 上电，等待 1～2 分钟
5. 电脑/手机连 Wi-Fi `OPi-Mini`，密码 `aa88888888`
6. 浏览器打开 `http://192.168.44.1`

首次启动会执行 `files/etc/uci-defaults/99-orangepi-router`：

- `eth0` 移出 LAN 桥，作为 WAN
- LAN 改成 `192.168.44.1/24`，开启 DHCP/RA
- Wi-Fi 固定为 `OPi-Mini` / `aa88888888`，2.4GHz
- 关闭 flow offloading（OpenClash 需要），LAN 防火墙 `input/forward ACCEPT`
- 串口打印管理地址和 Wi-Fi 账号

## 使用 OpenClash

内核已经内置，不用再下载：

```sh
ls -lh /etc/openclash/core/clash_meta
```

只需：

1. 打开 LuCI → 服务 → OpenClash
2. **配置文件订阅**：添加你的 Clash 订阅链接并更新
3. 选中该配置
4. **全局设置**：代理模式选「规则」，启用「DNS 劫持」，局域网客户端选「代理」
5. 保存并启动

> 如果之前点过「检查更新」把插件升级到镜像版，插件版本可能和固件不匹配；建议只在 LuCI 里更新**内核**，不要更新插件本体，插件要升级请重新打包固件。

## 切换到旁路由模式（可选）

默认是路由模式。若想让上游继续做 DHCP、Pi 只做旁路由：

```sh
i=0; while uci -q get "network.@device[$i]" >/dev/null 2>&1; do [ "$(uci -q get "network.@device[$i].name")" = "br-lan" ] && { uci -q delete "network.@device[$i].ports"; uci add_list "network.@device[$i].ports=eth0"; uci -q delete "network.@device[$i].bridge_empty"; }; i=$((i+1)); done; uci set network.lan.proto=static; uci set network.lan.ipaddr=192.168.1.250; uci set network.lan.gateway=192.168.1.1; uci set network.lan.dns=192.168.1.1; uci -q delete network.lan.ip6assign; uci -q delete network.wan; uci -q delete network.wan6; uci set dhcp.lan.ignore=1; uci commit network; uci commit dhcp; /etc/init.d/network restart
```

旁路由模式下管理地址变成 `192.168.1.250`。**这时要用 OpenClash 的客户端必须手动把网关和 DNS 都改成 `192.168.1.250`**：

- 只改 DNS 不改网关 → 流量不经过 Pi，OpenClash 不生效
- 只改网关不改 DNS → DNS 直连 `192.168.1.1`，Fake-IP / 分流失效，容易出现 DNS 污染、部分网站打不开

### macOS

系统设置 → 网络 → Wi-Fi → 详细信息：

- **TCP/IP**：手动，IP `192.168.1.x`（不要用 250），掩码 `255.255.255.0`，路由器 `192.168.1.250`
- **DNS**：只保留 `192.168.1.250`

### Windows

网卡 IPv4 属性：默认网关 `192.168.1.250`；DNS 首选 `192.168.1.250`。

### iPhone / Android

配置 IP → 手动：IP `192.168.1.x`，路由器 `192.168.1.250`，DNS `192.168.1.250`。

验证：

```sh
nslookup www.baidu.com 192.168.1.250
```

## 改 Wi-Fi 名称 / 密码

在 LuCI 里：网络 → 无线 → 编辑 → 修改 SSID 和密码；或串口/SSH：

```sh
uci set wireless.default_radio0.ssid='OPi-Mini'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='aa88888888'
uci commit wireless
/sbin/wifi down; sleep 2; /sbin/wifi up
```

> 改完让手机「忽略此网络」再重连，否则会一直用缓存里的旧密码。
> 密码建议 8 位以上、纯 ASCII；改完可以确认：`grep wpa_passphrase /var/run/hostapd-phy0.conf`

## 常见问题

### 打开 LuCI 报 `module 'luci.cbi.datatypes' not found`

LuCI 的 Lua 兼容层缺失（`luci-compat` / `luci-lua-runtime`）：

```sh
opkg update
opkg install luci-compat luci-lua-runtime
rm -rf /tmp/luci-*
/etc/init.d/uhttpd restart
```

最新固件已内置这两个包，并在构建后校验 `luci/cbi/datatypes.lua`、`luci/model/uci.lua`。

### 手机提示 Wi-Fi 密码错误

先确认路由器上的密码真的写进去了：

```sh
uci get wireless.default_radio0.key
grep -E 'ssid|wpa_passphrase|wpa_key_mgmt|wpa_pairwise' /var/run/hostapd-phy0.conf
```

- 若 `wpa_passphrase` 与 UCI 不一致：`/sbin/wifi down; sleep 2; /sbin/wifi up`
- 若日志出现 `AP-STA-POSSIBLE-PSK-MISMATCH`：让手机「忽略此网络」后重连
- 仍失败：先用另一台设备验证；都失败则临时改成 `encryption='none'` 排除 PSK 问题，或改回 2.4GHz

### 防火墙提示 `invalid value ''ACCEPT''`

`lan` zone 的 ACL 被写成了带单引号的 `'ACCEPT'`，整个 LAN zone 会被跳过（现象：Pi 能 ping 电脑，电脑访问不了 Pi）：

```sh
uci set firewall.@zone[0].input=ACCEPT
uci set firewall.@zone[0].output=ACCEPT
uci set firewall.@zone[0].forward=ACCEPT
uci commit firewall
fw4 reload
```

先确认 `@zone[0]` 是 `lan`。

## CPU 占用排查

当前 1GB 版本在 OpenClash 正常运行时**实测 CPU 低于 30%**。若持续高位：

```sh
top -bn1 | head -30
ps w | grep -E 'clash|openclash|quickstart|taskd|dnsmasq|hostapd|sprdwl'
dmesg | grep -iE 'sprdwl|tx err|wcn' | tail -30
```

- `ksoftirqd` / `sprdwl` 高：UWE5622 Wi-Fi 驱动。可切 2.4GHz，或 `wifi down` 对比；有线上网更稳
- `quickstart` 高：不用 iStore 向导可停用 `/etc/init.d/quickstart stop; /etc/init.d/quickstart disable`
- `clash` / `openclash` 高：规则/订阅/DNS 成环，先 `/etc/init.d/openclash stop` 对比
- `dnsmasq` 高：检查 OpenClash 的 DNS 劫持与上游设置

## 1GB 启动与刷写注意

本固件针对 **1GB 版本** 裁剪和验证，同一镜像也适用于 1.5 / 2 / 4GB。容易出问题的是 U-Boot 的 DRAM 探测：

- 老 U-Boot（24.10 用的 2024.01 一代）有时把 **1GB 认成 2GB**，内核按 2GB 建页表，
  碰到 1GB 以上地址就 panic；1.5GB 板更典型（OpenWrt #18087、DietPi #7242）
- 串口看到 `DRAM: 2048 MiB` 而板子是 1GB 时，先加 `mem=1024M` 救急，长期方案是换新版 U-Boot

串口参数：**115200 8N1**，Zero 3 的 debug UART 是板边 3 pin（GND / RX / TX 交叉接 3.3V USB-TTL）。

| 串口现象 | 结论 | 处理 |
|---|---|---|
| 无输出，或只有 `U-Boot SPL` 一行 | SPL 阶段 DRAM 初始化失败 | 换 5V/2A 电源、换卡重写 |
| 打印 `DRAM: 2048 MiB` 而板子是 1GB | 容量误判 | 换 U-Boot，或 bootargs 加 `mem=1024M` |
| `DRAM: 1024 MiB` 后卡住 | 不是内存问题 | 见下面刷写错误 |

刷写最常见的三个错：

1. **没解压**：直接把 `.img.gz` 写进卡（要写解压后的 `.img`）
2. **卡太小**：镜像约 2.1GB 原始大小（16MB FAT + 2GB rootfs），用 4GB 以上
3. **写错文件**：`initramfs-kernel.bin` 是内存运行镜像，不是 SD 镜像

> 断电前请先 `sync; poweroff`，等串口出现 `Power down` / `System halted` 再拔电。直接拔电可能写坏 F2FS overlay，严重时需要重刷。

## 固件命名

`EXTRA_IMAGE_NAME=OPi-Mini-OpenClash`，所以产物形如：

```text
immortalwrt-opi-mini-openclash-sunxi-cortexa53-xunlong_orangepi-zero3-squashfs-sdcard.img.gz
```

Actions 里的构建产物名：`OPi-Mini_firmware_<device>_<date>`。

## 自动编译

- 源码有更新时每 18 小时自动检查并触发编译（Update Checker）
- 也可在 Actions 页面手动运行 `Build OpenWrt Zero 3`
- 编译成功后自动发 Release，保留最近 3 个版本
- 构建会校验：代理栈、内置 Clash 内核、LuCI Lua 运行库、UCI 引号、固件文件名

## 自定义插件

Fork 后修改 `orange-pi-zero3.config` 里的 `CONFIG_PACKAGE_*`。1GB 版本请谨慎增加常驻服务。

## 致谢

- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
- [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt)
- [kenzok8/openwrt-packages](https://github.com/kenzok8/openwrt-packages)
- [vernesong/OpenClash](https://github.com/vernesong/OpenClash)（插件与 Meta 内核）
- [DeepAQ/openwrt-uwe5622-sunxi](https://github.com/DeepAQ/openwrt-uwe5622-sunxi)（AW859A / UWE5622 的 24.10/6.6 驱动 backport）

## License

[MIT](./LICENSE)
