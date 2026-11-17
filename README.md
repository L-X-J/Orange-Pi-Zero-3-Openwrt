# Orange-Pi-Zero-3-Openwrt

香橙派 **Orange Pi Zero 3**（全志 H618，Cortex-A53）自动云编译 OpenWrt 固件。

## 说明

- 源码：[ImmortalWrt](https://github.com/immortalwrt/immortalwrt) `openwrt-24.10` 分支（Linux 6.6 LTS）。不再跟随 6.18 的 `master`，以避开旧固件在 `S19firewall` 阶段触发的 `__slab_free` panic。
- 定位：**Orange Pi Zero 3 1GB 版专用精简代理软路由**。固件只保留代理栈、板载 Wi-Fi、iStore/quickstart、ttyd、UPnP、htop、iperf3，已剔除 Docker、Samba、aria2/AriaNg、adbyby、网易云解锁等与翻墙无关的重型套件。
- 代理插件：**只保留 OpenClash**（Clash Meta 内核），以及 `dnsmasq-full`、`ruby`、`ip-full`、nftables TProxy 等必要依赖。PassWall / PassWall2 / SSR+ / xray / sing-box 等全部移除，减少固件体积和后台进程。
- 内存优化：默认启用 `zram-swap`（`zram-swap` + `kmod-zram`），在 OpenClash 更新规则或大流量代理时以压缩内存充当 swap，降低 1GB 版 OOM 风险。
- **板载 AW859A（UWE5622）Wi-Fi**：24.10 上游并不包含 `kmod-uwe5622` / `uwe5622-firmware`。`diy-part1.sh` 会按固定 commit 拉取 [DeepAQ/openwrt-uwe5622-sunxi](https://github.com/DeepAQ/openwrt-uwe5622-sunxi) 的 24.10/6.6 驱动补丁、固件与 Zero 2/Zero 3 DTS 节点。该驱动属于第三方 backport，Wi-Fi 为尽力支持；旁路由模式下网口本身就是 LAN，Wi-Fi 不稳定时可以直接用有线。
- **iStoreOS 风格体验**：iStore 应用商店（`luci-app-store`）+ 快捷向导首页（`luci-app-quickstart`）+ 简体中文界面（`luci-i18n-base-zh-cn` / `LUCI_LANG_zh_Hans`）。商店保持空置、按需安装，不会把 Docker 等重型应用预装进 1GB 内存。
- 固件下载请前往 **Releases** 列表
- 默认管理 IP：`192.168.1.250`（**旁路由 LAN，静态**）；主路由/光猫仍然是 `192.168.1.1`

> 注意：`luci-app-store` / `luci-app-quickstart` 与 `quickstart` 来自 `kenzok8/openwrt-packages`，24.10 上游 luci 已不再提供；OpenClash 来自 24.10 luci feed。`kenzok8/small` feed 已整个移除。

## 网络拓扑（旁路由模式）

Zero 3 作为旁路由接入主网，主路由/光猫继续做 DHCP 和网关：

```text
主路由/光猫 192.168.1.1  (继续做 DHCP / 上网网关)
   ├── 电脑 / 手机       192.168.1.x
   └── Orange Pi Zero 3  192.168.1.250  (静态 IP，DHCP 关闭)
          └── Wi-Fi AP   同一个 LAN
```

- **LuCI**：`http://192.168.1.250`
- **SSH**：`ssh root@192.168.1.250`
- 首次启动会自动执行 `files/etc/uci-defaults/99-orangepi-bypass`，并把管理地址打印到串口日志
- Pi 的 DHCP 服务关闭，避免和主路由抢 DHCP；网口 `eth0` 和 Wi-Fi 都在 `br-lan`
- Pi 自己的网关/DNS 指向 `192.168.1.1`
- 已关闭 firewall 的 flow offloading，并关闭 ICMP redirect，避免客户端绕过旁路由/OpenClash
- 要让客户端走 OpenClash：把客户端的 **网关和 DNS 都设为 `192.168.1.250`**；或者在主路由的 DHCP 里下发这两个值。只改网关不改 DNS 容易 DNS 泄漏或解析失败
- 不想走代理的客户端保持网关 `192.168.1.1` 即可
- Wi-Fi SSID `ImmortalWrt`，默认无密码

如果已经刷了旧镜像、想不重刷临时改成旁路由，可在串口/SSH 执行：

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

## CPU 占用 100% 排查

固件裁剪只能减少“没在运行”的包，CPU 100% 需要先看是哪个进程/内核线程。登录后执行：

```sh
top -bn1 | head -30
ps w | grep -E 'clash|openclash|quickstart|taskd|dnsmasq|hostapd|sprdwl'
dmesg | grep -iE 'sprdwl|tx err|wcn' | tail -30
```

按结果处理：

- `ksoftirqd` / `sprdwl` 高：UWE5622 Wi-Fi 驱动在 AP 模式下忙。先用 2.4G 试试：

  ```sh
  uci set wireless.radio0.band='2g'
  uci set wireless.radio0.channel='6'
  uci set wireless.radio0.htmode='HT40'
  uci commit wireless
  wifi reload
  ```

  仍高的话，用串口执行 `wifi down` 对比 CPU；旁路由模式下有线口本身就在 LAN，可以直接用网线，不必依赖 Wi-Fi。

- `quickstart` 高：iStore 快捷向导后台（`quickstart serve`）。不用向导可以停掉：

  ```sh
  /etc/init.d/quickstart stop
  /etc/init.d/quickstart disable
  ```

- `clash` / `openclash` 高：OpenClash 已启用但规则/订阅/DNS 有环路，先在 LuCI 停止 OpenClash，或串口 `/etc/init.d/openclash stop` 对比。

- `dnsmasq` 高：通常是 OpenClash 的 DNS 劫持/上游配置成环，检查 OpenClash 的 DNS 设置。

- `taskd`/`istore`：iStore 本身很轻，但如果确认是它，下一版可以把 iStore/quickstart 一并裁掉。

## 1GB / 1.5GB 内存版（起不来先看这里）

1GB、1.5GB、2GB、4GB 是同一块板子的不同内存容量，固件是**同一份镜像**，不需要按容量选版本。
真正容易出问题的是 U-Boot 的 DRAM 探测，不是 OpenWrt 本身：

- 老 U-Boot（OpenWrt 23.05 / 24.10 用的 2024.01）经常把 **1GB 认成 2GB**，内核按 2GB 建页表，
  一碰到 1GB 以上的地址就 panic / 卡死；1.5GB 板更典型（已知问题，见 OpenWrt #18087、DietPi #7242）。
- 本仓回到 `openwrt-24.10` 后，U-Boot 由该分支的 sunxi 目标提供，仍是 **2024.01** 一代，
  因此 1GB 误判风险依然存在；**不要**把它当成"1GB 版随便刷"的保证。串口看到 `DRAM: 2048 MiB`
  而板子是 1GB 时，先加 `mem=1024M` 救急，长期方案是换用新版 U-Boot。

仍然起不来时，接串口（**115200 8N1**，Zero 3 的 debug UART 是板边 3 pin）看前几行，按现象分三类：

| 串口现象 | 结论 | 处理 |
|---|---|---|
| 完全没有输出，或只有 `U-Boot SPL 20xx.xx` 一行就停 | SPL 阶段 DRAM 初始化失败（时序/供电） | 换 5V/2A 以上电源、换卡重写；仍不行需要 720MHz 版 U-Boot（见下） |
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

## 自定义插件

Fork 后修改 `orange-pi-zero3.config` 中的 `CONFIG_PACKAGE_*` 即可。

## 致谢

- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
- [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt)
- [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
- [kenzok8/openwrt-packages](https://github.com/kenzok8/openwrt-packages)
- [DeepAQ/openwrt-uwe5622-sunxi](https://github.com/DeepAQ/openwrt-uwe5622-sunxi)（AW859A / UWE5622 的 24.10/6.6 驱动 backport）

## License

[MIT](./LICENSE)
