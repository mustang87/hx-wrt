# HX-WRT 快速参考

## 🔑 关键概念速查

### OpenWrt 核心概念

| 概念 | 说明 | 相关文件 |
|------|------|----------|
| **overlay** | 可写层，覆盖在只读 rootfs 上 | `/overlay` |
| **extroot** | 把 overlay 挂到外部存储（扩容） | `79_hx_disk_ready` |
| **uci** | 统一配置接口 | `uci get/set/commit` |
| **uci-defaults** | 首次启动初始化脚本 | `overlay/etc/uci-defaults/` |
| **init.d** | 服务管理脚本 | `overlay/etc/init.d/` |
| **procd** | 进程管理守护进程 | `USE_PROCD=1` |

### 文件系统层次

```
刷机后的实际文件系统：
/rom          ← 只读 rootfs（固件原始内容）
/overlay      ← 可写层（用户配置、安装的包）
/             ← overlayfs 合并 /rom + /overlay
```

### 启动阶段

| 阶段 | 时机 | 可写性 | 关键脚本 |
|------|------|--------|----------|
| **preinit** | rootfs 挂载前 | 只读 | `79_hx_disk_ready` |
| **init** | rootfs 挂载后 | 可写 | `hxwrt-bootlog` |
| **uci-defaults** | 首次启动 | 可写 | `90-*.sh` ~ `99-*.sh` |

---

## 📁 关键文件位置

### 构建相关
```
scripts/build.sh              # 构建入口
scripts/prepare_tree.sh       # 注入 overlay/package
scripts/config_apply.sh       # 应用 .config
configs/wr3000k/*.config      # 编译配置
```

### 运行时相关
```
overlay/etc/uci-defaults/     # 首启脚本（按数字顺序执行）
overlay/etc/init.d/           # 服务脚本
overlay/lib/preinit/          # preinit 阶段脚本
overlay/usr/lib/hxwrt/log.sh  # 日志库
```

### 日志位置
```
/tmp/.hxwrt/uci-defaults/     # 首启日志
/tmp/.hxwrt/boot.log          # 启动日志
/tmp/.hxwrt/openclash/        # OpenClash 日志
```

---

## 🔧 常用命令

### 构建
```bash
./scripts/build.sh build hx-wrt-wr3000k-dev    # 构建
./scripts/build.sh status                     # 查看状态
./scripts/build.sh tail                        # 查看日志
```

### 设备上调试
```bash
# 查看日志
cat /tmp/.hxwrt/uci-defaults/99-hx-finish.log

# 检查服务
/etc/init.d/uhttpd status
/etc/init.d/dropbear status

# 检查挂载
mount | grep overlay
df -h

# 检查分区
cat /proc/mtd
ubinfo -a

# 手动执行服务
/etc/init.d/uhttpd restart
```

### UCI 配置
```bash
# 查看配置
uci show network.lan
uci show firewall

# 修改配置
uci set network.lan.ipaddr='192.168.1.1'
uci commit network

# 应用配置
/etc/init.d/network restart
```

---

## 🎯 代码阅读顺序

### 新手路径（按此顺序阅读）

1. **项目结构** → `README.md`
2. **构建流程** → `scripts/build.sh` → `scripts/lib/build_main.sh`
3. **注入机制** → `scripts/prepare_tree.sh`
4. **首启流程** → `overlay/etc/uci-defaults/90-*.sh`（按数字顺序）
5. **日志系统** → `overlay/usr/lib/hxwrt/log.sh`
6. **扩容机制** → `overlay/lib/preinit/79_hx_disk_ready`
7. **服务管理** → `overlay/etc/init.d/hx-storage`

### 进阶路径

1. **品牌注入** → `scripts/brand_identity.sh`
2. **功能开关** → `scripts/features.sh`
3. **OpenClash 初始化** → `scripts/openclash/hx-openclash-init-run`
4. **存储服务** → `overlay/etc/init.d/hx-storage`
5. **重置机制** → `overlay/usr/sbin/system_reset`

---

## 🐛 常见问题定位

### Web 无法访问
1. 检查 `uhttpd` 是否运行：`/etc/init.d/uhttpd status`
2. 查看日志：`/tmp/.hxwrt/uci-defaults/99-hx-finish.log`
3. 检查防火墙：`uci show firewall`

### SSH 无法登录
1. 检查 `dropbear` 是否运行：`/etc/init.d/dropbear status`
2. 检查是否启用：`ls -l /etc/rc.d/S*dropbear`
3. 查看日志：`/tmp/.hxwrt/uci-defaults/99-hx-finish.log`

### 磁盘未扩容
1. 检查 extroot 是否配置：`cat /etc/config/fstab | grep overlay`
2. 检查实际挂载：`mount | grep overlay`
3. 查看 preinit 日志：`cat /tmp/.hxwrt/boot.log | grep disk_ready`

### 首启脚本未执行
1. 检查是否已执行：`ls /etc/uci-defaults/`（应该为空）
2. 手动执行测试：`cd /etc/uci-defaults && ./90-hx-brand-init`
3. 查看日志：`/tmp/.hxwrt/uci-defaults/*.log`

---

## 📝 代码模式

### uci-defaults 脚本模板
```bash
#!/bin/sh
set -e

. /usr/lib/hxwrt/log.sh
hx_log_redirect "uci-defaults" "XX-your-script.log"

log() { echo "[$(date '+%F %T')] $*"; }

log "script start"

# 你的逻辑
uci set something.key='value'
uci commit something

log "script done"
exit 0
```

### init.d 服务模板
```bash
#!/bin/sh /etc/rc.common
START=50
STOP=90
USE_PROCD=1

start_service() {
  procd_open_instance
  procd_set_param command /path/to/your/script
  procd_set_param respawn 0 0 0
  procd_close_instance
}
```

### 日志使用模板
```bash
. /usr/lib/hxwrt/log.sh

# 方式1：重定向整个脚本输出
hx_log_redirect "uci-defaults" "my-script.log"

# 方式2：使用日志函数
hx_log_init "my-component" "my.log"
hx_log I "info message"
hx_log E "error message"
```

---

## 🔗 相关链接

- [OpenWrt 官方文档](https://openwrt.org/docs/start)
- [UCI 配置系统](https://openwrt.org/docs/guide-user/base-system/uci)
- [UBI/UBIFS 文档](https://www.kernel.org/doc/html/latest/filesystems/ubifs.html)
- [Shell 脚本教程](https://www.shellscript.sh/)

---

**快速查找：用 `grep` 或 IDE 搜索功能定位代码位置！**
