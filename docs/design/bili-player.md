# B 站小窗播放器

## 业务背景

在隐蔽阅读的同时，需要一个可登录、可缩到极小的 B 站小窗，与阅读窗分离，并共用老板键。

## 核心逻辑

1. 右键菜单「B站」打开/控制独立非透明窗 `BiliPlayerWindow`（WebView2）。
2. 用户数据目录：`exe目录\webview-bili\`，用于持久化 Cookie / 登录态（便携，不进干净正式包）。
3. 链接规范化：`BiliUrlHelper.Normalize`（完整链接 / 短链 / BV / AV）；无地址栏时可通过顶条右键「粘贴并打开」或 Ctrl+V。
4. **整体缩小（默认）**：CDP 固定大屏**宽度**（约 1280）再缩小进小窗；高度随可见区域，**可用滚轮上下滚动**看更多内容；不是窄视口裁切。
5. **原尺寸模式**：清除设备模拟，按真实小窗尺寸排版。
6. **纯净窗体 / 拖动快捷键 / 新窗拦截 / 老板键暂停 / 扬声器静音**：同前。
7. **菜单列表**：
   - 「首页」→ 小窗打开 B 站首页（只有这一项会跳首页）。
   - 「稍后再看 / 历史记录」→ 小窗跳到对应列表页，并用登录 Cookie 拉官方 JSON 填三级菜单（稍后全部、历史最多 10 条）。
   - 列表缓存在进程内（`BiliListCache`）：软件不关即可在右键菜单点标题切换视频，无需反复打开网页挑片。

## 关联影响

- 依赖本机 **Microsoft Edge WebView2 Runtime（x86）**。
- 不嵌入透明主阅读窗（与 WebView2 HWND 冲突）。
- 正式包附带 WebView2 DLL；排除 `webview-bili\`。
- 稍后/历史依赖用户已在小窗登录；未登录时菜单提示去登录。

## 边界与异常

| 场景 | 处理 |
|------|------|
| 无 WebView2 Runtime | 状态文案提示安装 |
| `target=_blank` | 本窗打开 |
| 老板键暂停失败 | 仍隐藏窗口；记日志；部分特殊播放器可能仍响 |
| Esc / 顶条右键关闭 | 关闭小窗 |
| 未登录拉列表 | 菜单显示「请先在小窗登录 B 站」 |
| 历史非视频项 | 跳过（仅 archive/pgc 等视频） |
| 已缓存列表 | 展开子菜单直接显示标题，点标题切换播放 |

## 外部依赖

- `Microsoft.Web.WebView2` NuGet、本机 Runtime、网络访问 bilibili.com / api.bilibili.com
- `BiliListHelper` 解析官方 JSON；Cookie 取自 `CoreWebView2.CookieManager`；`BiliListCache` 进程内缓存
