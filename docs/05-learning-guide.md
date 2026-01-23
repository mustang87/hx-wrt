# HX-WRT 代码学习指南

## 📚 前置基础知识

在深入代码前，建议先掌握：

### 1. Linux Shell 基础
- **bash/sh 脚本语法**：变量、函数、条件判断、循环
- **文件操作**：`mkdir`、`cp`、`mv`、`ln`（软链接/硬链接）
- **进程管理**：`exec`、`&` 后台、`||` 错误处理
- **推荐资源**：`man bash`、[Shell Scripting Tutorial](https://www.shellscript.sh/)

### 2. OpenWrt 核心概念
- **overlay 文件系统**：只读 rootfs + 可写 overlay = 完整系统
- **extroot**：把 overlay 挂到外部存储（如 UBI 分区），实现扩容
- **uci（Unified Configuration Interface）**：OpenWrt 的配置系统
- **uci-defaults**：首次启动时执行的初始化脚本（只执行一次）
- **init.d 服务**：OpenWrt 的服务管理（类似 systemd）
- **procd**：OpenWrt 的进程管理守护进程
- **推荐资源**：[OpenWrt 官方文档](https://openwrt.org/docs/guide-user/start)

### 3. UBI/UBIFS 文件系统（针对你的设备）
- **MTD**：Memory Technology Device（Flash 分区）
- **UBI**：Unsorted Block Images（在 MTD 上的卷管理层）
- **UBIFS**：UBI 上的文件系统（类似 ext4，但针对 Flash 优化）
- **推荐资源**：[UBI/UBIFS 文档](https://www.kernel.org/doc/html/latest/filesystems/ubifs.html)

---

## 🎯 学习路径（从易到难）

### 阶段 1：理解项目结构（1-2 小时）

**目标**：知道文件在哪、做什么用

#### 1.1 目录结构
```
hx-wrt/
├── scripts/          # 构建脚本（编译前）
├── overlay/          # 固件内容（刷入设备后）
├── configs/          # 编译配置
└── package/          # 自定义包
```

**动手**：
- 浏览 `README.md` 的目录结构说明
- 用 `tree` 或 `find` 查看实际目录
- 理解 `overlay/` = 刷机后的 `/`（rootfs）

#### 1.2 关键文件定位
- **构建入口**：`scripts/build.sh`
- **首启脚本**：`overlay/etc/uci-defaults/90-*.sh` ~ `99-*.sh`
- **扩容逻辑**：`overlay/lib/preinit/79_hx_disk_ready`
- **日志库**：`overlay/usr/lib/hxwrt/log.sh`

---

### 阶段 2：理解构建流程（2-3 小时）

**目标**：知道固件是怎么“组装”出来的

#### 2.1 构建主流程

**阅读顺序**：
1. `scripts/build.sh` → 入口，调用 `tmux_wrap_run`
2. `scripts/lib/build_main.sh` → 主流程
3. `scripts/openwrt_fetch.sh` → 拉取 OpenWrt 底座
4. `scripts/prepare_tree.sh` → **关键**：注入 overlay/package
5. `scripts/config_apply.sh` → 应用 `.config`

**关键理解点**：
```bash
# prepare_tree.sh 做了什么？
1. 拉第三方源码（sources.sh）
2. 注入 overlay → openwrt/files/  # 这就是刷机后的 rootfs
3. 注入 package → openwrt/package/hx/
4. 按 FEATURES 启用可选功能
```

**动手**：
- 运行一次构建，观察 `openwrt/files/` 目录变化
- 查看 `openwrt/package/hx/` 下有哪些包

#### 2.2 配置系统（.config）

**阅读**：
- `configs/wr3000k/hx-wrt-wr3000k-dev.config`
- `scripts/config_apply.sh`

**理解**：
- `.config` 决定编译哪些包（`CONFIG_PACKAGE_xxx=y`）
- `defconfig` 是默认配置模板

---

### 阶段 3：理解首启流程（3-4 小时）

**目标**：知道刷机后第一次启动发生了什么

#### 3.1 uci-defaults 执行顺序

**阅读顺序**（按文件名数字顺序）：
1. `90-hx-brand-init` → 主机名/时区/密码
2. `91-hx-network-init` → LAN IP
3. `92-hx-dhcp.sh` → DHCP 配置
4. `93-hx-wireless.sh` → WiFi 配置
5. `94-hx-firewall-lan.sh` → 防火墙
6. `95-hx-apk-mirror.sh` → 软件源镜像
7. `96-hx-storage` → 启用存储服务
8. `97-hx-ipv6-disable` → 禁用 IPv6
9. `98-hx-openclash-core-init` → OpenClash 初始化
10. `99-hx-finish` → 重启服务（网络/防火墙/uhttpd/SSH）

**关键理解**：
- 这些脚本**只在首次启动执行一次**
- 执行后会被重命名（OpenWrt 机制）
- 使用 `set -e`，任何错误都会中断

**动手**：
- 在设备上查看 `/etc/uci-defaults/`（应该为空，已执行完）
- 查看日志：`/tmp/.hxwrt/uci-defaults/*.log`

#### 3.2 日志系统

**阅读**：`overlay/usr/lib/hxwrt/log.sh`

**理解**：
- `hx_log_path()` → 根据类别返回日志路径
- `hx_log_redirect()` → 重定向 stdout/stderr 到日志文件
- 所有 uci-defaults 脚本都 `source` 这个库

**动手**：
- 修改一个 uci-defaults 脚本，加一行 `log "test"`
- 重新编译刷机，查看日志

---

### 阶段 4：理解扩容机制（4-5 小时）

**目标**：知道磁盘是怎么从 20M 扩容到 40M 的

#### 4.1 preinit 阶段

**阅读**：`overlay/lib/preinit/79_hx_disk_ready`

**关键概念**：
- **preinit**：在 rootfs 挂载前执行的阶段（此时 `/` 还是只读）
- **extroot**：把 `/overlay` 挂到外部存储（ubi1 分区）

**代码流程**：
```
1. 检查 /proc/mtd 是否有 "ubi1" 分区
2. ubiattach → 把 mtd5 挂到 ubi1
3. 检查/创建 extroot_overlay volume
4. 写 fstab.overlay → 告诉系统下次启动挂 ubi1_0 到 /overlay
5. 重启后，/overlay 就从 ubi0_2（20M）变成 ubi1_0（40M）
```

**关键函数**：
- `hx_find_ubi_by_mtdnum()` → 找 MTD 对应的 UBI 设备
- `hx_ensure_extroot_volume()` → 确保 volume 存在
- `hx_write_fstab()` → 写挂载配置

**动手**：
- 在设备上查看 `/proc/mtd`（分区表）
- 查看 `/etc/config/fstab`（挂载配置）
- 查看 `mount | grep overlay`（实际挂载）

#### 4.2 存储服务

**阅读**：`overlay/etc/init.d/hx-storage`

**理解**：
- 挂载 `/mnt/custom`（另一个 UBI 分区，用于 OpenClash core）
- 创建 OpenClash 路径软链接

---

### 阶段 5：理解服务管理（2-3 小时）

**目标**：知道服务是怎么启动/停止的

#### 5.1 init.d 服务

**阅读**：
- `overlay/etc/init.d/hx-storage`
- `overlay/etc/init.d/hxwrt-bootlog`

**理解**：
- `START=05` → 启动顺序（数字越小越早）
- `USE_PROCD=1` → 使用 procd 管理（推荐）
- `start_service()` → 服务启动函数

**对比**：
- **传统方式**：直接运行命令，进程退出服务就停止
- **procd 方式**：procd 监控进程，自动重启

#### 5.2 OpenClash 初始化

**阅读**：
- `overlay/etc/uci-defaults/98-hx-openclash-core-init` → 安装 init.d
- `scripts/openclash/hx-openclash-init-run` → 实际初始化逻辑

**理解**：
- 98 脚本创建 `/etc/init.d/hx-openclash-init`
- init.d 服务延迟 30 秒后运行 `hx-openclash-init-run`
- `hx-openclash-init-run` 下载 core/GEO 文件

---

### 阶段 6：深入定制（按需）

#### 6.1 添加新的 uci-defaults 脚本

**步骤**：
1. 在 `overlay/etc/uci-defaults/` 创建 `XX-your-script.sh`
2. 开头：`. /usr/lib/hxwrt/log.sh` + `hx_log_redirect`
3. 使用 `uci` 命令修改配置
4. `uci commit` 提交
5. 重新编译刷机

**示例**：参考 `92-hx-dhcp.sh`

#### 6.2 添加新的 init.d 服务

**步骤**：
1. 在 `overlay/etc/init.d/` 创建服务脚本
2. 设置 `START`、`USE_PROCD`
3. 实现 `start_service()`
4. 在 uci-defaults 中 `enable` 它

**示例**：参考 `hx-storage`

#### 6.3 修改扩容逻辑

**位置**：`overlay/lib/preinit/79_hx_disk_ready`

**注意**：
- preinit 阶段资源有限（无网络、工具少）
- 只能使用 busybox 命令
- 错误会导致启动失败

---

## 🔍 调试技巧

### 1. 查看日志
```bash
# 首启日志
ls -l /tmp/.hxwrt/uci-defaults/

# 启动日志
cat /tmp/.hxwrt/boot.log

# OpenClash 日志
cat /tmp/.hxwrt/openclash/hx-openclash-init-run.log
```

### 2. 手动执行 uci-defaults
```bash
# 如果脚本还没执行，可以手动跑
cd /etc/uci-defaults
./90-hx-brand-init
```

### 3. 检查服务状态
```bash
# 查看服务是否启用
ls -l /etc/rc.d/S* | grep uhttpd

# 查看服务是否运行
/etc/init.d/uhttpd status
ps | grep uhttpd
```

### 4. 检查挂载
```bash
# 查看所有挂载
mount

# 查看 overlay 挂载
mount | grep overlay

# 查看分区
cat /proc/mtd
```

---

## 📖 推荐阅读顺序

### 第 1 周：基础理解
1. ✅ 阅读 `README.md` 和 `docs/00-overview.md`
2. ✅ 理解目录结构
3. ✅ 运行一次完整构建
4. ✅ 刷机并观察首启日志

### 第 2 周：流程深入
1. ✅ 阅读 `scripts/prepare_tree.sh`（理解注入机制）
2. ✅ 阅读所有 `uci-defaults/*`（理解首启流程）
3. ✅ 阅读 `overlay/usr/lib/hxwrt/log.sh`（理解日志系统）
4. ✅ 修改一个 uci-defaults 脚本，验证效果

### 第 3 周：高级特性
1. ✅ 阅读 `79_hx_disk_ready`（理解扩容）
2. ✅ 阅读 `hx-storage`（理解存储服务）
3. ✅ 阅读 `hx-openclash-init-run`（理解动态下载）
4. ✅ 尝试添加一个新功能

---

## 🛠️ 实践项目

### 初级：修改默认配置
- 修改 WiFi 密码（`93-hx-wireless.sh`）
- 修改 LAN IP（`91-hx-network-init`）
- 添加新的日志输出

### 中级：添加新功能
- 添加一个新的 uci-defaults 脚本（如设置时区）
- 创建一个简单的 init.d 服务
- 修改日志路径到 `/overlay/hx/log/`

### 高级：修改核心逻辑
- 修改扩容逻辑（支持其他分区）
- 添加新的存储挂载点
- 实现自动更新机制

---

## 📚 延伸阅读

### OpenWrt 官方文档
- [Build System](https://openwrt.org/docs/guide-developer/build-system/start)
- [Adding Packages](https://openwrt.org/docs/guide-developer/packages)
- [UCI System](https://openwrt.org/docs/guide-user/base-system/uci)

### 相关项目
- [X-WRT](https://github.com/x-wrt/x-wrt) - 另一个 OpenWrt 发行版
- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) - OpenWrt 分支

---

## 💡 常见问题

### Q: 为什么 uci-defaults 脚本只执行一次？
A: OpenWrt 机制，执行后重命名，避免重复执行。

### Q: preinit 和 init 的区别？
A: preinit 在 rootfs 挂载前（只读），init 在 rootfs 挂载后（可写）。

### Q: overlay 和 extroot 的关系？
A: overlay 是机制，extroot 是把 overlay 挂到外部存储。

### Q: 如何调试 preinit 脚本？
A: 查看 `/tmp/.hxwrt/boot.log`，或使用 `hx_log_kmsg` 写到 dmesg。

---

## 🎓 学习检查清单

- [ ] 能说出项目的主要目录和作用
- [ ] 能独立运行一次完整构建
- [ ] 能理解 uci-defaults 的执行顺序
- [ ] 能解释扩容的工作原理
- [ ] 能修改一个 uci-defaults 脚本并验证
- [ ] 能创建一个简单的 init.d 服务
- [ ] 能看懂日志并定位问题
- [ ] 能理解 overlay/extroot 的关系

---

**祝你学习愉快！遇到问题随时查看日志和代码注释。** 🚀
