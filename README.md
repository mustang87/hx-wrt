# HX-WRT

基于 OpenWrt 的路由器固件发行版，专为 Tenbay WR3000K 等设备定制。

## 目录结构

```
hx-wrt/
├── README.md
├── LICENSE
├── .gitignore
├── thirdparty.lock                     # 第三方源码版本锁定

├── docs/
│   ├── 00-overview.md                  # 项目介绍：定位、原则、发布流程
│   ├── 01-build-quickstart.md          # 一键构建说明
│   ├── 02-profiles.md                  # 各 profile 差异说明
│   ├── 03-upgrade-rollback.md          # 升级/回滚/救砖说明
│   └── 04-branding.md                  # 品牌信息修改点汇总

├── scripts/
│   ├── env.sh                          # 统一环境变量（路径、分支、输出目录）
│   ├── build.sh                        # 一键编译（入口）
│   ├── openwrt_fetch.sh                # 拉取/更新 OpenWrt 底座
│   ├── prepare_tree.sh                 # 注入 overlay/package 到 openwrt
│   ├── prepare_exec.sh                 # 修复脚本执行权限
│   ├── config_apply.sh                 # 应用 configs/*.config
│   ├── config_tweak.sh                 # 配置微调
│   ├── brand_identity.sh               # 品牌标识注入
│   ├── features.sh                     # 可选功能开关（FEATURES 环境变量）
│   ├── sources.sh                      # 第三方源码拉取
│   ├── clean.sh                        # 清理编译产物
│   ├── pack_release.sh                 # 打包发布物
│   ├── smoke_test.sh                   # 基础自检
│   ├── force_rebuild_luci.sh           # 强制重编 LuCI
│   ├── lib/
│   │   ├── build_main.sh               # 构建主流程
│   │   ├── build_ctl.sh                # 构建控制（状态/停止）
│   │   ├── build_lock.sh               # 构建锁
│   │   ├── tmux_wrap.sh                # tmux 会话封装
│   │   └── diagnose.sh                 # 诊断工具
│   └── openclash/
│       └── hx-openclash-init-run       # OpenClash 初始化脚本

├── configs/
│   ├── common/
│   │   ├── base.config                 # 公共包选择
│   │   └── proxy.config                # 代理相关包选择
│   └── wr3000k/
│       └── hx-wrt-wr3000k-dev.config   # WR3000K 开发版配置

├── overlay/                            # rootfs 覆盖层（等价于 OpenWrt files/）
│   ├── etc/
│   │   ├── banner                      # 登录横幅
│   │   ├── openwrt_release             # 发行版标识
│   │   ├── os-release                  # OS 标识
│   │   ├── config/
│   │   │   ├── firewall                # 防火墙默认配置
│   │   │   ├── fstab                   # 挂载点配置
│   │   │   ├── hxwrt                   # HX-WRT 配置
│   │   │   ├── network                 # 网络配置
│   │   │   └── system                  # 系统配置
│   │   ├── hotplug.d/
│   │   │   ├── boot/10-hxwrt-log       # 启动日志 hotplug
│   │   │   └── iface/10-hxwrt-log      # 网络接口日志 hotplug
│   │   ├── init.d/
│   │   │   ├── hx-ipv6                 # IPv6 开关服务
│   │   │   ├── hx-storage              # 存储挂载服务（custom 分区 + OpenClash 路径）
│   │   │   └── hxwrt-bootlog           # 启动日志服务
│   │   ├── uci-defaults/
│   │   │   ├── 90-hx-brand-init        # 主机名/时区/密码/品牌
│   │   │   ├── 91-hx-network-init      # LAN IP
│   │   │   ├── 92-hx-dhcp.sh           # DHCP 配置
│   │   │   ├── 93-hx-wireless.sh       # WiFi 配置
│   │   │   ├── 94-hx-firewall-lan.sh   # 防火墙 zone/forwarding
│   │   │   ├── 95-hx-apk-mirror.sh     # APK 镜像源
│   │   │   ├── 96-hx-storage           # 存储服务启用
│   │   │   ├── 97-hx-ipv6-disable      # IPv6 禁用
│   │   │   ├── 98-hx-openclash-core-init # OpenClash init 服务安装
│   │   │   └── 99-hx-finish            # 首启收尾（重启服务）
│   │   └── hx-wrt/
│   │       ├── version                 # 版本号
│   │       ├── channel                 # 渠道（dev/stable）
│   │       └── build-info              # 构建信息
│   ├── lib/preinit/
│   │   ├── 79_hx_disk_ready            # extroot 准备（ubi1 分区）
│   │   └── 79-hxwrt-reset-policy.sh    # 重置策略
│   ├── usr/
│   │   ├── lib/hxwrt/
│   │   │   └── log.sh                  # 统一日志库
│   │   └── sbin/
│   │       └── system_reset            # 系统重置命令
│   └── www/luci-static/resources/view/status/include/
│       └── 15_hxwrt_contact.js         # LuCI 状态页联系信息

├── overlay-features/                   # 可选功能（通过 FEATURES 启用）
│   ├── argon/
│   │   └── uci-defaults/
│   │       └── 15-hx-luci-theme.sh     # Argon 主题设置
│   └── openclash/
│       ├── 01-feed.sh                  # OpenClash feed 配置
│       ├── 10-config.sh                # OpenClash 配置
│       ├── 20-deps.sh                  # OpenClash 依赖
│       └── 90-init.sh                  # OpenClash 初始化

├── package/                            # 自定义包
│   ├── hx-brand/
│   │   ├── Makefile
│   │   └── files/etc/hx-wrt/
│   │       └── brand.conf              # 品牌配置
│   └── luci-app-hxwrt/
│       ├── Makefile
│       └── root/
│           ├── usr/share/luci/menu.d/
│           │   └── luci-app-hxwrt.json
│           ├── usr/share/rpcd/acl.d/
│           │   └── luci-app-hxwrt.json
│           └── www/luci-static/resources/view/hxwrt/
│               └── settings.js         # LuCI 设置页面

├── targets/
│   └── wr3000k/
│       ├── README.md                   # WR3000K 目标说明
│       └── notes.md                    # 已知问题/验证清单

└── releases/                           # 发布物输出目录（不入库）
```

## 快速开始

```bash
# 构建开发版
./scripts/build.sh build hx-wrt-wr3000k-dev

# 带可选功能构建
FEATURES=argon,openclash ./scripts/build.sh build hx-wrt-wr3000k-dev

# 查看构建状态
./scripts/build.sh status

# 查看构建日志
./scripts/build.sh tail
```

## 日志路径

| 类别 | 路径 |
|------|------|
| 首启日志 | `/tmp/.hxwrt/uci-defaults/` |
| 启动日志 | `/tmp/.hxwrt/boot.log` |
| OpenClash 日志 | `/tmp/hx-openclash-init-run.log` |
| GEO 数据 | `/overlay/hx/openclash/geo/` |

## 可选功能（FEATURES）

- `argon` - Argon 主题
- `openclash` - OpenClash 代理
- `keep_firstboot_logs` - 保留首启日志到 `/overlay/hx/log/firstboot/`