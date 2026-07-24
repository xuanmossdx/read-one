# 正式版发布与体积

## 版本

当前产品版本：**1.0**（`Constants.ProductVersion` / `AssemblyVersion 1.0.0.0`）。产品名：**read-one**。

## 仓库结构

| 路径 | 内容 |
|------|------|
| 源码仓 [read](https://github.com/xuanmossdx/read) | 可编译工程与完整设计文档；含正式包目录 `read-one\` |
| 发行仓 [read-one](https://github.com/xuanmossdx/read-one) | 用户向 README + 文档摘录；**正式包 zip 挂在 Releases** |
| `dist\` | 本地缓存（gitignore） |
| `D:\read` | 作者自用安装目录（**不在本仓**） |

发行：本地 `publish.bat` 后，用 `gh release create` 上传 `read-one-vX.Y.zip` 即可。

## 命令

```bat
build.bat                 rem → dist\read-one\
publish.bat               rem → 仓库根\read-one\ 与 dist\read-one-formal\
tools\update-d-read.bat   rem 更新 D:\read 程序，保留数据
```

## 干净包必须排除

- `db5.data`、书库、`log.txt`、`ai-presets-custom.json`（用户自建 AI 预设；内置预设随程序）
- `*.pdb`、`*.xml`、`c.db`、`QRCoder.dll`、`Upgrade.exe`
- 重复的 `System.Data.SQLite`（只放 `lib\`）

体积约 **3.4 MB**。

## 更新 D:\read

只替换 `read-one.exe`、`*.config`、`System.*.dll`、`lib\*`。  
**不要删/覆盖** `db5.data`、`books\`、书库目录。  
`FactoryDefaultsRevision` 未改时，启动不会用出厂设置覆盖用户配置。
