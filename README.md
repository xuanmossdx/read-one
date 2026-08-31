# read-one

本地隐蔽阅读器：看书、听书、本地视频小窗、B 站小窗，以及可选的 AI 助手。

**当前版本：1.1.2**

## 一键安装

使用 Windows 自带的 PowerShell。打开要安装的文件夹，在地址栏输入 `powershell` 回车，粘贴：

```powershell
irm https://raw.githubusercontent.com/xuanmossdx/read-one/main/install.ps1 | iex
```

若直连较慢，可试：

```powershell
irm https://ghfast.top/https://raw.githubusercontent.com/xuanmossdx/read-one/main/install.ps1 | iex
```

若提示无法执行脚本，可用：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/xuanmossdx/read-one/main/install.ps1 | iex"
```

程序会安装到当前目录下的 `read-one\`，完成后运行 `read-one\Start.bat`。  
脚本会下载本仓库最新 Release，并在缺少 .NET Framework 4.7.2 时提示安装运行库。

## 手动下载

到 **[Releases](https://github.com/xuanmossdx/read-one/releases)** 下载压缩包：

1. 下载主程序包并解压到任意文件夹  
2. 若首次运行提示缺少运行库，再下载同版本「运行库」包并按说明安装  
3. 推荐用 `Start.bat` 启动  

阅读进度、书库等保存在解压目录内，整夹可拷贝带走。

## 功能

- **阅读**：txt / epub / mobi；书架、最近阅读、目录、书签；单行 / 多行；主题、字号、行距；老板键隐藏  
- **听书**：朗读；独立操作台（语速、暂停、换行）；可定时自动停止  
- **本地视频**：小窗播放，可选目录连播  
- **B 站**：独立小窗，可登录，支持稍后再看与历史  
- **AI 助手**：可选，需自行配置 DeepSeek 密钥  
- **自动更新**：联网时每天最多检查一次本仓库新版本；有更新会提示并自动安装重启  
- **手动更新**：设置 → 更新 →「手动检查更新」  
- **关闭外网**：设置中可关闭全部外网（更新、B 站、AI 均不可用）  

听书或打开视频 / B 站小窗时，可自动静音系统扬声器，降低办公外放（耳机等设备一般仍可正常出声）。

## 更新

- 可再次运行上方一键安装覆盖程序文件，或从 Releases 下载新主包覆盖  
- **保留**自己的阅读进度与书籍目录  
- 不要把已含个人进度的文件夹当作安装包转发给别人  

QQ 群（获取最新版 / 交流）：**1109580513**

更细说明见 [docs](docs/README.md)；版本变更见 [更新日志](docs/tech/changelog.md)。
