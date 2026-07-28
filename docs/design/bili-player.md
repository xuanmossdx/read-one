# B 站小窗播放器

## 业务背景

在隐蔽阅读的同时，需要一个可登录、可缩到极小的 B 站小窗，与阅读窗分离，并共用老板键。

## 核心逻辑

1. 右键菜单「视频小窗（B站）」打开独立非透明窗 `BiliPlayerWindow`（WebView2）。
2. 用户数据目录：`exe目录\webview-bili\`，用于持久化 Cookie / 登录态（便携，不进干净正式包）。
3. 链接规范化：`BiliUrlHelper.Normalize`（完整链接 / 短链 / BV / AV）；无地址栏时可通过顶条右键「粘贴并打开」或 Ctrl+V。
4. **整体缩小（默认）**：CDP 固定大屏**宽度**（约 1280）再缩小进小窗；高度随可见区域，**可用滚轮上下滚动**看更多内容；不是窄视口裁切。
5. **原尺寸模式**：清除设备模拟，按真实小窗尺寸排版。
6. **纯净窗体 / 拖动快捷键 / 新窗拦截 / 老板键暂停 / 扬声器静音**：同前。

## 关联影响

- 依赖本机 **Microsoft Edge WebView2 Runtime（x86）**。
- 不嵌入透明主阅读窗（与 WebView2 HWND 冲突）。
- 正式包附带 WebView2 DLL；排除 `webview-bili\`。

## 边界与异常

| 场景 | 处理 |
|------|------|
| 无 WebView2 Runtime | 状态文案提示安装 |
| `target=_blank` | 本窗打开 |
| 老板键暂停失败 | 仍隐藏窗口；记日志；部分特殊播放器可能仍响 |
| Esc / 顶条右键关闭 | 关闭小窗 |

## 外部依赖

- `Microsoft.Web.WebView2` NuGet、本机 Runtime、网络访问 bilibili.com
