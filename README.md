# read-one · 正式版

纯本地隐蔽阅读器（txt / epub / mobi）+ 听书操作台 + 本地视频小窗 + B 站小窗 + 可选 DeepSeek AI 助手。

**当前版本：2.0.1**（混淆正式包，无用户数据）· 产品名 **read-one**

## 下载

请到本仓库 **[Releases](https://github.com/xuanmossdx/read-one/releases)** 下载最新 zip。

- `read-one-vX.Y.Z.zip`：主包（后续更新通常只下这个）
- `read-one-runtime-vX.Y.Z.zip`：`.NET Framework 4.7.2` 依赖包（仅首次缺运行库时需要）

解压主包后运行 `Start.bat`（推荐）或 `read-one.exe`。数据保存在程序同目录（便携）。

> 源码与开发文档：[xuanmossdx/read](https://github.com/xuanmossdx/read)

## 2.0.1 修复

- **目录识别**：修复 mobi（及同类粘行）章节标题与正文粘在一行时漏进目录的问题（如《蛊真人》第一百五十七节等）；并修正「落幕/风幕/序幕」等含「幕」字标题、标题内书名号、括号内句号、HTML 实体等误杀。

## 功能概要

- 书架 / 最近阅读 / 章节目录 / 书签
- 单行模式 / 多行模式、主题字号行距、听书、老板键
- 本地视频小窗、B 站小窗
- 启动续读、自动存进度
- AI 助手（需自备 DeepSeek API Key）

## 使用注意

- **不要**把含进度的整个目录当「干净包」再分发；干净包不含 `db5.data`、书库、日志、`ai-presets-custom.json`
- 更新时只替换程序文件，保留自己的 `db5.data` 与书籍
- Windows，目标 .NET Framework 4.7.2（x86）