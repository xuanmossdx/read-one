# read-one

本地隐蔽阅读器：看书、听书、本地视频小窗、B 站小窗，以及可选的 AI 助手。

**当前版本：1.0**（一键安装脚本已就绪；有新版本时请看 Releases）

## 一键安装（推荐，无需安装 Node 等任何开发工具）

只用 **Windows 自带的 PowerShell**。打开要安装的文件夹，地址栏输入 `powershell` 回车，粘贴下面命令：

```powershell
irm https://raw.githubusercontent.com/xuanmossdx/read-one/main/install.ps1 | iex
```

国内若直连慢，可先试镜像（镜像站不稳定时请改用上面的直连）：

```powershell
irm https://ghfast.top/https://raw.githubusercontent.com/xuanmossdx/read-one/main/install.ps1 | iex
```

若提示执行策略，用这一整行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/xuanmossdx/read-one/main/install.ps1 | iex"
```

安装位置：当前目录下的 `read-one\`。装完后运行 `read-one\Start.bat`。

脚本会自动下载最新 Release 主包，并检查 .NET Framework 4.7.2（已有则跳过安装）。

## 手动下载与安装

请到本仓库 **[Releases](https://github.com/xuanmossdx/read-one/releases)** 下载最新压缩包。

1. 下载主程序压缩包并解压到任意文件夹  
2. 若首次运行提示缺少运行库，再下载并安装同版本的「运行库」压缩包  
3. 解压后双击启动脚本或主程序即可使用  

程序数据（阅读进度、书库等）保存在解压目录内，整夹可随身拷贝。

## 主要功能

- **阅读**：支持常见电子书格式；书架、最近阅读、章节目录、书签；单行 / 多行显示；主题、字号、行距可调；老板键一键隐藏  
- **听书**：朗读当前书籍；独立听书操作台（语速、暂停、换行）；可设定定时自动停止  
- **本地视频**：小窗播放本地视频，可选目录连续播放，与阅读窗互不干扰  
- **B 站**：独立小窗浏览与播放，可登录，支持稍后再看与历史记录  
- **AI 助手**：可选，需自行配置 DeepSeek 密钥后使用  

听书或打开视频小窗时，可自动静音系统扬声器，避免办公外放（耳机等其它设备仍可正常出声）。

## 更新说明

- 新版本请仍从 [Releases](https://github.com/xuanmossdx/read-one/releases) 下载，或使用上方一键安装覆盖程序文件  
- 更新时用新程序文件覆盖旧程序即可，**保留**自己的阅读进度与书籍目录  
- 不要把已用过、含个人进度的整个文件夹当作「干净安装包」再发给别人  
- QQ 群（获取最新版）：**1109580513**

更细的功能介绍见 [docs](docs/README.md)；各版本变更见 [更新日志](docs/tech/changelog.md)。
