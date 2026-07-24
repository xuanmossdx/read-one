# 正式版发布与体积

## 版本

当前产品版本：**1.0**（`Constants.ProductVersion` / `AssemblyVersion 1.0.0.0`）。

## 仓库结构

| 路径 | 内容 |
|------|------|
| 源码树 | 可编译工程与设计文档 |
| `单行阅读器\` | **可提交的干净正式版**（混淆 exe + lib，无用户数据） |
| `dist\` | 本地缓存（gitignore） |
| `D:\read` | 作者自用安装目录（**不在本仓**） |

发行仓：手动拷贝 `单行阅读器\` + 用户 README。

## 命令

```bat
build.bat                 rem → dist\Read133\
publish.bat               rem → 仓库根\单行阅读器\ 与 dist\danhang\
tools\update-d-read.bat   rem 更新 D:\read 程序，保留数据
```

## 干净包必须排除

- `db5.data`、书库、`log.txt`、`ai-presets-custom.json`（用户自建 AI 预设；内置预设随程序）
- `*.pdb`、`*.xml`、`c.db`、`QRCoder.dll`、`Upgrade.exe`
- 重复的 `System.Data.SQLite`（只放 `lib\`）

体积约 **3.4 MB**。

## 更新 D:\read

只替换 `Read133.exe`、`*.config`、`System.*.dll`、`lib\*`。  
**不要删/覆盖** `db5.data`、`books\`、书库目录。  
`FactoryDefaultsRevision` 未改时，启动不会用出厂设置覆盖用户配置。
