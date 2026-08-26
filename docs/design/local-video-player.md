# 本地视频小窗

## 业务背景

在隐蔽阅读的同时，需要一个可播本地 MP4（等）的小窗，形态与 B 站小窗一致：可极小、置顶、不进任务栏，并共用老板键。与「书架选书」类似，可选择一个目录中的多集视频连续播放。

## 核心逻辑

1. 主窗右键「本地视频」：**打开小窗 / 关闭小窗 / 选择目录**。
2. 播放器：WPF `MediaElement`（零额外依赖）；**整窗仅视频画面**，无常驻按钮、无软件音量（走系统音量）。
3. **交互**：
   - 左键点击画面 → 播放/暂停
   - 鼠标移到底部热区 → 半透明进度条 + 时间（无文件名）；移开或约 3 秒无操作后自动隐藏
   - 右键菜单：播放/暂停、上一集、下一集、选择目录、播放列表、关闭小窗
   - 拖动：与 B 站相同，按住设置里的**拖动快捷键** + 左键拖动整窗（`BiliDragMoveKey`）
   - Esc 关闭；空格播放/暂停；双击恢复默认大小
4. **选目录**：`FolderBrowserDialog` → `LocalVideoLibraryScanner.ScanFolder` 扫描 `*.mp4`（顺带 `*.mkv`/`*.avi`，含子目录）→ 按文件名排序 → 从上次索引或第一集开播。
5. **播完自动下一集**；到末尾停住并暂停，不循环。
6. **老板键**：可见则 `Pause` + `Hide`；主窗已藏、仅再藏本小窗时同样先 `Pause` 再 `Hide`；恢复只 `Show`，**不自动续播**（防外放）。
7. 扬声器静音：打开小窗 → `SpeakerMuteController.SetLocalVideoActive(true)`；与听书/B 站共用规则。`MediaElement` 固定 `Volume=1`、`IsMuted=false`，响度只跟**系统音量 / 当前默认输出设备**；「静音扬声器」只静音配置的扬声器端点，耳机等其它设备应仍有声。
8. 配置（`Other`）：窗位宽高、上次目录、上次列表索引；负坐标副屏可保存；恢复时夹到虚拟桌面可见区。不写入干净正式包。

## 关联影响

- 与 B 站小窗、听书操作台并列 companion；可同时打开。
- 不依赖 WebView2；编码失败时提示并可手动下一集。
- 拖动快捷键与 B 站共用 `BiliDragMoveKey` / `ModifierHotkeyHelper.IsBiliDragComboPressed`。

## 边界与异常

| 场景 | 处理 |
|------|------|
| 目录无视频 | 居中状态文案提示 |
| `MediaFailed`（缺解码器等） | 提示「无法播放…可试下一集」；不自动跳 |
| 列表末尾播完 | 暂停，提示「列表播放完毕」 |
| Esc / 右键关闭 | 关窗停播并清 Source |
| 老板键隐藏 | 暂停后 Hide；恢复不 Resume |
| 进度条热区 | 与条高同为 28px；热区内左键不播/暂停 |
| 拖进度松在窗外 | `LostMouseCapture` / 窗 `PreviewMouseLeftButtonUp` 结束 seek |
| 副屏负坐标 | 允许保存；恢复夹到 `VirtualScreen` |
| 播放列表过长 | 右键子菜单最多显示 40 项 |

## 外部依赖

- WPF `MediaElement`（系统解码器）、`System.Windows.Forms.FolderBrowserDialog`
- 无 LibVLC / 无额外 NuGet
