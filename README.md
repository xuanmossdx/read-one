# read-one

纯本地隐蔽阅读器（支持 txt / epub / mobi），可选 DeepSeek AI 助手与 B 站小窗。

**当前版本：1.0.6**

## 下载与安装

1. 从 [Releases](https://github.com/xuanmossdx/read-one/releases) 下载最新 zip  
2. 解压到任意文件夹  
3. **推荐双击 `Start.bat` 启动**（若本机缺少运行库，会自动安装 .NET Framework 4.7.2，可能弹出管理员确认；装好后若提示重启，重启后再开一次即可）

也可以直接运行 `read-one.exe`；若打不开，可先运行 `Install-Runtime.bat`，或仍用 `Start.bat`。

阅读进度、书签等会保存在程序所在目录。

## 主要功能

- 书架、最近阅读、章节目录、书签  
- 单行 / 多行模式，主题、字号、行距  
- 听书语速调节  
- 启动续读、自动存进度  
- AI 助手（需自行填写 DeepSeek API Key）  
- **B 站视频小窗**（需本机安装 [WebView2 Runtime x86](https://developer.microsoft.com/microsoft-edge/webview2/)）：整体缩小视野、滚轮可上下滚动、快捷键拖动、老板键联动暂停  
- 听书 / 小窗时可静音指定扬声器，防外放  

## 更新

覆盖解压新版本到原程序目录即可；请保留同目录下的数据文件（书籍、进度等）以免丢失。

## 使用说明

见 [docs/](docs/)。
