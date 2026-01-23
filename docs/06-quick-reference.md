
---

## 3.3 `docs/06-quick-reference.md`（完整替换）

```md
# 06 - Quick Reference（速查表）

## 1) 核心路径

| 类别 | 路径 |
|------|------|
| 数据盘挂载点 | `/mnt/hx-data` |
| OpenClash core | `/mnt/hx-data/openclash/core/` |
| OpenClash geo | `/mnt/hx-data/openclash/geo/` |
| OpenClash rule_provider | `/mnt/hx-data/openclash/rule_provider/` |
| OpenClash 状态/标记 | `/mnt/hx-data/openclash/state/` |
| OpenClash cache（tmpfs） | `/tmp/openclash/cache/` |

## 2) 关键脚本

| 文件 | 作用 |
|------|------|
| `overlay/lib/preinit/79_hx_disk_ready` | 准备 `ubi1:hx_data` 并写入 `fstab.hxdata` |
| `overlay/etc/init.d/hx-storage` | 兜底挂载 `/mnt/hx-data`，并软链 OpenClash 重数据路径 |
| `scripts/openclash/hx-openclash-init-run` | 下载 core + GEO 到数据盘 |

## 3) 常用命令

### 数据盘检查
```sh
mount | grep hx-data
df -h | grep hx-data
uci show fstab | grep -A6 hxdata
