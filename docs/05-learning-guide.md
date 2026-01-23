
---

## 3.2 `docs/05-learning-guide.md`（完整替换）

```md
# 05 - Learning Guide（脚本阅读地图）

这份文档帮助你快速理解 HX-WRT 的启动链路、存储架构与 OpenClash 初始化。

## 1. 启动链路（与本项目相关的关键点）

### 1.1 preinit：准备数据盘（ubi1 → /mnt/hx-data）

文件：`overlay/lib/preinit/79_hx_disk_ready`

职责：

1. 找到 MTD 分区名为 `ubi1`
2. `ubiattach`（不会自动格式化）
3. 确保 UBI 卷 `hx_data` 存在（不存在则创建）
4. 写入 `fstab.hxdata`：`ubiX:hx_data` → `/mnt/hx-data`

> 目标：**不扩 overlay**。数据盘作为持久化存储，系统盘保持干净。

---

### 1.2 init.d：兜底挂载与路径收敛

文件：`overlay/etc/init.d/hx-storage`

职责：

- 兜底挂载 `/mnt/hx-data`
- 创建数据目录：
  - `/mnt/hx-data/openclash/core`
  - `/mnt/hx-data/openclash/geo`
  - `/mnt/hx-data/openclash/rule_provider`
  - `/mnt/hx-data/openclash/state`
- 将 OpenClash 的重数据路径统一软链到数据盘：
  - `/etc/openclash/core` → data disk
  - `/etc/openclash/rule_provider` → data disk
  - `/etc/openclash/GeoIP.dat`、`GeoSite.dat`、`Country.mmdb` → data disk
  - `/etc/openclash/cache` → `/tmp/openclash/cache`

---

### 1.3 OpenClash 初始化（下载 core + GEO）

文件：`scripts/openclash/hx-openclash-init-run`

职责：

- 等待 `/mnt/hx-data` 挂载
- 强制要求 `/etc/openclash/core` 是软链（避免写 overlay）
- 下载 core 到数据盘
- 下载 GEO 到数据盘
- 写入 marker：`/mnt/hx-data/openclash/state/hx-openclash-init.done`

---

## 2. 为什么不扩 overlay？

overlay 是系统状态层，适合存放：

- UCI 配置
- 小型默认文件
- LuCI 相关少量自定义

不适合存放：

- Clash core
- GEO 数据
- 大规则列表（rule_provider）
- 缓存

将重数据放数据盘能带来：

- **升级稳定**
- **重置简单**
- **坏了好救**
- **写 flash 更少**

---

## 3. 常用排查命令

### 3.1 数据盘是否挂载

```sh
mount | grep hx-data
df -h | grep hx-data
uci show fstab | grep -A6 hxdata
