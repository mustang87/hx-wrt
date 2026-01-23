# HX-WRT

基于 OpenWrt 的路由器固件发行版，专为 Tenbay WR3000K 等设备定制。

## 存储架构（重要）

HX-WRT 采用 **System / Data 分离**：

- **System（系统盘）**：rootfs + overlay（保持小、稳定、可升级/可重置）
- **Data（数据盘）**：使用 MTD 分区名为 `ubi1` 的 UBI，创建卷 `hx_data`，挂载到 `/mnt/hx-data`

OpenClash 的重数据全部放数据盘：

- core：`/mnt/hx-data/openclash/core/`
- geo：`/mnt/hx-data/openclash/geo/`
- rule_provider：`/mnt/hx-data/openclash/rule_provider/`
- state：`/mnt/hx-data/openclash/state/`

overlay 只保留小配置（UCI、脚本、少量默认配置）。

## 目录结构

（略：与仓库结构一致，重点文件见下）

### 关键脚本

- `overlay/lib/preinit/79_hx_disk_ready`  
  早期启动准备数据盘：确保 `ubi1:hx_data` 存在，并写入 `fstab.hxdata`
- `overlay/etc/init.d/hx-storage`  
  兜底挂载 `/mnt/hx-data`，并把 OpenClash core/geo/rule_provider 软链到数据盘
- `scripts/openclash/hx-openclash-init-run`  
  下载 OpenClash core 与 GEO 到数据盘，不占用 overlay

## 快速开始

```bash
# 构建开发版
./scripts/build.sh build hx-wrt-wr3000k-dev

# 带可选功能构建
FEATURES=argon,openclash ./scripts/build.sh build hx-wrt-wr3000k-dev
