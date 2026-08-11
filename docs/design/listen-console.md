# 听书操作台小窗

## 业务背景

听书（SAPI）进行中需要独立透明操作台：语速、行跳转、暂停/继续，而不必每次打开主窗右键菜单。与阅读窗、B 站小窗一样支持老板键伴生隐藏与移开藏控件。

## 核心逻辑

1. 右键「听书 → 打开操作台 / 关闭操作台」控制 `ListenConsoleWindow`（不自动开始听书）。
2. 底栏按钮：语速±、上一行、暂停/继续、下一行、关闭操作台。
3. 背景与主阅读窗一致（`ThemeService.CreateBackgroundBrush` + `StyleBackGroundAtpa`）；按钮透明度 = `StyleFontAtpa/100`。
4. **移开藏控件**：与「移开藏字」同配置（`HideTextWhenMove` + `ShowTextWhenMoveKey`）；隐藏时保留 `hitPlate` 命中层。
5. **老板键**：藏主窗时一并藏操作台；**听书不暂停、不停止**（仅藏 UI）。
6. **行同步**：读完一行 → `SpvCallBack(completeFlag)` → `currentLine++` → `ReadLine`；手动上一行/下一行或翻页前 `PrepareListenLineJump()` 取消当前句再读新行。
7. **暂停**：仅菜单、**Alt+P**、操作台按钮触发；续播从 SAPI 暂停位置继续。

## 快捷键（设置页可改）

| 默认 | 作用 |
|------|------|
| Alt+V | 开始/停止听书（整段会话；藏窗后仍可用） |
| Alt+P | 暂停/继续（须已在听书中；藏窗后仍可用） |

## 关联影响

- 依赖 Windows SAPI（`Constants.ReadMod=1`）
- `InitStyle` 结束时 `SyncListenConsoleTheme()`
- 窗口位置持久化：`ListenConsoleWidth/Height/Left/Top`

## 边界与异常

| 场景 | 处理 |
|------|------|
| 未开始听书点暂停/行跳 | 提示先开始听书 |
| 老板键隐藏 | 藏操作台；SAPI 继续；**Alt+P / Alt+V 仍响应**（不要求主窗可见） |
| 关闭操作台 | 不停听书 |
| 定时关闭听书 | 仍 `CloseVoice()`；操作台可仍打开 |

## 外部依赖

无（纯 WPF + 既有 `SpVoiceUtil`）
