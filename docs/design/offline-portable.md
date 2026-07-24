# 纯净单机与便携数据

## 业务背景

原版阅读器将数据库放在 `C:\ProgramData\` 下旧目录，进度用绝对路径做键，整夹搬家或换电脑后容易丢进度。本 fork（产品名 **read-one**）改为纯净单机：拆除登录/注册/会员/支付，数据与进度跟随程序目录。

## 核心逻辑

1. `Util.GetDataPath` 固定使用 exe 目录（`DataPath=app`）。
2. `PortablePath` 将 exe 目录内书籍存为相对路径，并对相对路径计算 `FilePathMd5`。
3. 额外写入 `FileMd5`（内容哈希），路径对不上时用内容找回进度。
4. 首次启动若本地无库而 ProgramData 有 `db5.data`，复制并规范化路径。
5. 书架扫描由 `BookLibraryScanner` 统一实现（exe 目录、`books`、`txt小说`/`txt留档` 等）。
6. 启动：`EnsurePortableDatabase` → `CreateDB` → `EnsureSchema`（`user_version` 迁移链）→ `ConfigUtil.EnsureFactoryDefaultsApplied` → 路径规范化。

## 关联影响

- 右键菜单新增：书架、最近阅读、主题、字号/行距、书签、编码重载。
- 登录/注册/会员/支付/应用中心相关源码已删除；会话仅 `OfflineSession`。
- 关于窗口不再下载支付二维码。

## 边界与异常

- 书在 exe 目录外：仍存绝对路径，换盘符可能丢进度（可用内容哈希兜底；仅打开单本时才算内容哈希，书架批量加载只用路径键以免卡顿）。
- 同内容不同文件：内容哈希可能合并进度，属预期兜底行为。
- 书架：后台扫描 + 一次读历史表；显示文本预计算并开启列表虚拟化，减轻打开与滚动卡顿。

## 外部依赖

无服务器会员依赖。可选频道仍会访问第三方公开 API；本地阅读不依赖网络。
