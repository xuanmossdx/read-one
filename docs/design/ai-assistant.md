# AI 助手（DeepSeek 官方 API）

## 业务背景

在隐蔽单行/双行阅读形态下，用 **DeepSeek 开放平台官方 API** 提供聊天与联网搜索，不嵌入网页、不逆向网页会话（符合用户协议）。

## 核心逻辑

1. 右键「AI 助手」进入双行模式：上行显示回复，下行输入，Enter 发送  
2. 设置：**主设置窗「AI 助手」标签页**（`DeepSeek/AiSettingsPanel.xaml`）；右键「AI 设置…」亦打开同一页。  
   - **常用设置**：API Key、V4 模型、深度思考、联网搜索、人设预设  
   - **高级设置**（折叠）：Base URL、Temperature / Top P / Penalty、最大 Token、上下文轮数、联网搜索次数上限  
3. 模型：**仅 DeepSeek V4** — `deepseek-v4-flash`（默认）/ `deepseek-v4-pro`；旧版 `deepseek-chat` / `deepseek-reasoner` 及未知模型名加载时回落到 flash  
4. 深度思考（官方 [Thinking Mode](https://api-docs.deepseek.com/guides/thinking_mode)）：  
   - V4 **不再**用单独 reasoner 模型名，改为请求参数  
   - OpenAI 格式：`thinking.type`（enabled/disabled）+ `reasoning_effort`（**high** / **max**）  
   - Anthropic 格式（联网时）：`thinking.type` + `output_config.effort`（high/max）  
   - 开启思考时 Temperature 等采样参数官方约定不生效（UI 灰显）  
   - 默认关闭思考（API 默认 enabled，客户端显式传 disabled 以节省成本）  
5. 普通对话：`POST /chat/completions`（OpenAI 兼容）  
6. 联网搜索：`POST /anthropic/v1/messages` + 工具 `web_search_20250305`（`max_uses` 1–10）；仍为 DeepSeek 域名与同一 Key  
7. **内置人设**在 `AiPresetStore.CreateBuiltins()`；用户预设存 `ai-presets-custom.json`  
8. **配置生效**：进入 AI 模式、主设置保存、`OpenSettings` 后均调用 `RefreshFromDisk`（重载 Key/模型/预设；预设 ID 变更才重建会话）  
9. **人设覆盖**：`TemperatureOverride` 写入请求温度；`DefaultWebSearch == true` 时仅本请求强制联网（不改写持久 `WebSearchEnabled`）  
10. **代理**：`DeepSeekApiClient` 按 `ConfigUtil` 的 ProxyFlag/Address/Port/User/Pass 重建 `HttpClient`（改代理后下次请求生效）  
11. **StreamEnabled**：`1`（默认）流式；`0` 非流式一次返回全文（高级/库内配置，设置页无单独开关）

## 关联

- `src/DeepSeek/*`：客户端与 UI  
- `MainWindow.V2Features.cs`：模式切换与热键  
- `ConfigUtil`：与阅读器其它设置分离（AI 走 `t_KeyValue` section=`AI`）；系统代理节 `Proxy` 供 AI HTTP 使用

## 边界

- 无 Key：提示去设置，不崩溃  
- 思考模式开启时温度等参数按官方不生效（UI 灰显）  
- 老板键隐藏时取消进行中的请求并暂停听书  
- 不保证永远跟进 DeepSeek 接口改版；失败时明确错误  
- 流式输出仅展示最终 `content`，不展示 `reasoning_content` 思维链（阅读器形态下保持简洁，属有意设计）  
- 经「系统→设置」改 AI 后，若控制器已创建会 `RefreshFromDisk`；未进过 AI 则下次进入时加载  
- 列表选中人设后点确定即保存为当前（无需再点「设为当前」）  
- 自定义预设的增删改复制仅在设置窗点「确定」时写入 `ai-presets-custom.json`；取消/关窗回滚内存变更

## 依赖

- 用户自备 DeepSeek API Key  
- 本机可访问 `api.deepseek.com`（或经系统代理）  
- Newtonsoft.Json、System.Net.Http
