```
hx-wrt/
├── README.md
├── LICENSE
├── .gitignore

├── docs/
│   ├── 00-overview.md                 # 项目介绍：定位、原则、发布流程
│   ├── 01-build-quickstart.md          # 一键构建说明
│   ├── 02-profiles.md                 # 各 profile 差异说明
│   ├── 03-upgrade-rollback.md          # 升级/回滚/救砖说明（串口/TFTP 预留）
│   └── 04-branding.md                 # 品牌信息修改点汇总

├── scripts/
│   ├── env.sh                         # 统一环境变量（路径、分支、输出目录）
│   ├── openwrt_fetch.sh               # 拉取/更新 OpenWrt 底座（支持切分支）
│   ├── prepare_tree.sh                # 把 hx-wrt 的 overlay/package 注入到 openwrt
│   ├── config_apply.sh                # 应用 configs/*.config -> .config + defconfig
│   ├── build.sh                       # 一键编译（入口）
│   ├── clean.sh                       # 清理编译产物（distclean/clean 分级）
│   ├── pack_release.sh                # 打包发布物（bin/ + sha256 + manifest）
│   └── smoke_test.sh                  # 基础自检（检查必备包/版本号/输出文件存在）

├── configs/
│   ├── wr3000k/
│   │   ├── hx-wrt-wr3000k-dev.config   # 开发版：功能全、调试多
│   │   ├── hx-wrt-wr3000k-stable.config# 稳定版：更保守
│   │   └── hx-wrt-wr3000k-lite.config  # 精简版：只保留核心代理能力
│   └── common/
│       ├── base.config                 # 所有 profile 公共的包选择（可选：合并用）
│       └── proxy.config                # 代理相关公共包选择（可选）

├── overlay/                            # 等价于 OpenWrt 的 "files/"（rootfs 覆盖层）
│   └── etc/
│       ├── banner
│       ├── openwrt_release
│       ├── os-release
│       ├── uci-defaults/
│       │   ├── 10-hx-brand-init        # 主机名/时区/版本写入等（首次启动执行）
│       │   ├── 20-hx-network-init      # LAN 默认 IP/基础网络
│       │   ├── 30-hx-firewall-init     # 代理常用防火墙基础策略（尽量保守）
│       │   ├── 40-hx-opkg-init         # 可选：默认 opkg 源、签名策略等
│       │   └── 90-hx-finish            # 写入标记文件，防止重复执行（可选）
│       ├── config/
│       │   ├── system                  # 可选：少量静态默认配置
│       │   ├── network                 # 可选：慎用，优先 uci-defaults
│       │   └── firewall                # 可选：慎用，优先 uci-defaults
│       └── hx-wrt/
│           ├── version                 # 发行版版本信息（你自己维护）
│           ├── channel                 # dev/stable 标识
│           └── build-info              # 构建信息（脚本写入：git hash/time）

├── package/                            # 你的自定义包（不要直接改上游包）
│   └── hx-brand/
│       ├── Makefile
│       └── files/
│           └── etc/
│               └── hx-wrt/
│                   └── brand.conf      # 品牌配置：名称/官网/默认说明等

├── feeds/
│   ├── feeds.conf.hx                   # 你的 feeds 定义（含 openclash/luci-app-openclash 等）
│   └── README.md                       # feeds 说明：来源、版本锁定策略

├── targets/
│   └── wr3000k/
│       ├── README.md                   # wr3000k 目标说明：固件类型/刷机注意
│       └── notes.md                    # 已知坑位/验证清单（写给未来的你）

└── releases/                           # 发布物输出目录（脚本生成，默认不入库）
    └── (empty)


```