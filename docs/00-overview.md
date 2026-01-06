# HX-WRT

HX-WRT 是一个基于 OpenWrt 的“品牌固件发行版层”（distribution layer），目标是：
- 可持续产出固件（dev/stable）
- 可升级、可回滚（不改分区/不改设备身份）
- 可批量定制默认配置（overlay + uci-defaults）
- 可随时切换 OpenWrt 底座分支（openwrt-23.05 / main）

当前首发目标设备：**Tenbay WR3000K（mediatek/filogic, MT7981）**。  
OpenWrt 已支持该设备，生成的 sysupgrade 固件文件名会包含 `tenbay_wr3000k-squashfs-sysupgrade.bin`。

> 定位：路由 + 科学上网  
> 方案：LuCI + OpenClash（核心使用 clash_meta）+ xray-core + 常用工具/依赖

---

## 目录结构

- `overlay/`：刷入固件的 rootfs 覆盖层（等价 OpenWrt 的 `files/`）
  - `overlay/etc/uci-defaults/*`：首次启动初始化（只执行一次）
- `configs/`：各机型/档位的 `.config`（用于批量构建）
- `package/`：自定义包（品牌信息等）
- `feeds/`：额外 feeds（例如 OpenClash）
- `scripts/`：一键构建脚本（拉底座、注入 overlay、编译、打包）

---

## 工作目录约定（推荐）

把 `hx-wrt` 和 `openwrt` 放在同级目录，便于脚本管理：

