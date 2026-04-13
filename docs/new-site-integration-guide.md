# New Site Integration Guide

本文基于 `116pan-vip` 的接入和问题修复经验，总结后续新增站点时的解析、登录、下载流程。目标是让新站点先有可验证的规则契约，再进入客户端 UI、发布和真实环境验证。

## 116pan 经验总结

### 1. 规则包是解析入口的源头

`116pan-vip` 不是硬编码站点逻辑，而是进入默认规则目录：

- 默认目录由 `auth-workflows.bundle.json` 和 `auth-sites.bundle.json` 合并。
- 默认目录版本需要唯一，例如本次新增并修复 Koolaayun 后 `RuleBundleFixtures.defaultBundle` 使用 `2026.04.13.catalog.koolaayun.3`；后续每次发布都应递增到新的唯一版本。
- provider family 使用 `116pan-vip`，账号作用域是 `providerFamily`。
- matcher 覆盖 `www.116pan.xyz`、`116pan.xyz`、`www.116pan.com`、`116pan.com`，但只匹配 canonical `/f/<token>` 形态。
- 旧形态 `viewfile.php?file_id=<id>` 没有被验证，不能因为 host 相同就自动放进同一 workflow。

经验：新增站点时，先把 host 和 path shape 拆清楚。补 host 只能解决“进不进 provider”的问题，不能证明下载 workflow 适用于这个 host。

### 2. 登录流程要按真实浏览器会话建模

116pan 登录流程是 Laravel/Inertia + captcha：

1. 从输入 URL 计算 `pageOrigin`。
2. GET `{{pageOrigin}}/login`，保存 cookie。
3. 从登录页提取 CSRF meta token 和 Inertia version。
4. GET `{{pageOrigin}}/captcha/20`，带同一 cookie jar。
5. 调用 `captcha.ocr` 得到验证码。
6. 从 cookie 中读取并 percent-decode `XSRF-TOKEN`。
7. POST `{{pageOrigin}}/login`，body 为 username/password/captcha JSON，并带 `X-CSRF-TOKEN`、`X-XSRF-TOKEN`、`X-Inertia`、`X-Inertia-Version`、`X-Requested-With`。
8. GET `{{pageOrigin}}/dashboard` 作为登录成功确认。
9. 只把必要的 session value 存入 auth session，例如 username、csrfToken；cookie 由 auth session 持有。

经验：成功标准不要只看登录 POST 200。SPA/Inertia 站点可能返回登录页组件或空错误页，必须用 dashboard/auth user/VIP 状态等后验页面确认。

### 3. Captcha 重试策略要先 probe

116pan probe 证明同一登录页 cookie 和 CSRF 下，可以重复拉 `/captcha/20` 并提交最新验证码，所以配置：

- `captchaRetryPolicy.mode = refreshCaptcha`
- `startAtOutput = captchaImage`
- `maxAttempts = 50`

这让 resolver 在验证码失败时保留当前 auth runtime，从 `captchaImage` 步骤重跑，而不是重新 GET 登录页。

经验：新增验证码站点必须先判断 captcha 是否绑定登录页/cookie。

- 同 session 刷新可用：用 `refreshCaptcha`，允许更高重试预算。
- 必须刷新登录页/cookie：用 `fullWorkflow` 或不配置 retry policy，重试预算要保守。
- OCR 调优不要靠反复打真实站点；需要样本时用受控 debug 目录，样本和凭据不能进源码。

### 4. 下载 workflow 不能信任输入 host

116pan 的 `.com` 问题证明了一个关键点：matcher 命中 `.com` 后，workflow 仍然可能需要使用 `.xyz` 的 canonical 页面。

116pan 下载流程目前是：

1. 从 `input.sourceURL` 提取 `sourcePath` 和 `/f/<token>` 中的 `fileShortURL`。
2. 如果输入包含 `116pan.com`，先把文件页 URL canonicalize 为 `https://www.116pan.xyz{{sourcePath}}`；否则使用输入 URL。
3. GET 文件页，附带 auth session，并保存响应 cookie。
4. 从实际响应 `filePage.url` 重新计算 `pageOrigin`，避免继续使用旧输入 origin。
5. 如果文件页 body 是 Inertia 登录组件，说明 auth 过期，进入重新认证分支。
6. 否则从文件页提取 CSRF meta token 和 `XSRF-TOKEN` cookie。
7. POST `{{pageOrigin}}/f/{{fileShortURL}}/generate-download`，body 为 VIP 下载请求 JSON，Referer 使用 `filePage.url`。
8. 从 JSON `download_url` 提取直链。
9. 用 `url.origin(downloadURL)` 做兼容性验证，避免空值落到最终 `emitRequest` 才变成低层 `Invalid emitted request URL`。
10. emit 最终 GET 请求，Referer 仍使用 canonical `filePage.url`，filename hints 标记 provider。

经验：新增站点时要把“输入 URL”“最终文件页 URL”“生成直链 endpoint origin”“最终下载 URL”分开建模。凡是发生 redirect 或跨域 canonicalize 的站点，都要以实际文件页响应 URL 作为后续 Origin/Referer 的依据。

### 5. 账号选择要按 provider family 复用

116pan 曾经出现一个任务已用 `default-116` 下载中，新增同站任务却回到 `default` 并弹出登录框。根因是 auth session key 是 `(providerFamily, accountID)`，新任务没有显式账号时 resolver 默认成 `default`，导致看不到已有 session。

客户端现在在真实 resolve 前做 provider-family scoped account selection：

1. 显式的非 `default` 行账号优先。
2. 同 provider family、同 host、运行中或已完成的可复用行账号其次。
3. 同 provider family 最新 credential reference 再次。
4. 最后才保留原行账号或交给 resolver 默认。

经验：新增登录站点时，`default` 只能是最后兜底。任何验证码成本高的站点，都必须让后续任务优先复用同 provider family 的有效账号和 session，并记录 `provider_family`、`requested_account_id`、`selected_account_id`、`selection_source`。

### 6. 下载成功以本地文件为准

116pan 大文件暴露出三类下载执行问题：

- `networkConnectionLost`：成功拿到 HTTP 200 后仍可能断线。策略是重新 resolve，拿新的签名 URL，再从 0 开始下载，最多 3 次后台重试；不使用 resume data 或 Range。
- CFNetwork 临时文件：`URLSessionDownloadDelegate.didFinishDownloadingTo` 的 location 生命周期极短，回调中第一件事必须把它 move/copy 到 app-owned callback temp URL，之后才能 trace、staging、actor 或数据库操作。
- HTML fallback：直链请求可能返回很小的 HTML 登录/错误页，不能只看 HTTP 成功。

经验：真实 E2E 的终点必须是 app-owned final file：

- 文件记录存在。
- final path 在 Downloads 目录下。
- 磁盘文件存在。
- 文件大小达到预期下限或等于预期值。
- 若有 Content-Length，磁盘大小要匹配。
- 文件前缀不能是 `<!doctype` 或 `<html`。

## Koolaayun 二次接入补充

`koolaayun-vip` 暴露的是另一类站点：无 captcha 的账号表单登录 + 登录后页面按钮 + 多段 302 下载链。它补齐了 116pan 手册里不够通用的部分。

### 1. 非 Inertia 登录必须规则化成功/失败条件

Koolaayun 登录页是普通 form：

1. GET `/account/login` 获取 `filehosting` session cookie。
2. POST `/account/login`，表单字段为 `username`、`password`、`submitme=1`。
3. 成功时 302 到 `/account`，账号页含 `account/logout`。
4. 失败时仍返回登录页，页面含 `Your username and password are invalid`。

经验：不能只靠 116pan 那类 Inertia/Dashboard 启发式。新增站点如果不是 Inertia，必须在 `authPolicy` 里配置：

- `successConditions`：例如 `accountPage.body contains account/logout`。
- `credentialRejectConditions`：例如登录响应 body 的明确错误文案。
- `captchaRejectConditions`：有验证码时同理配置。

没有明确 success condition 的普通 form 登录，容易把“只拿到匿名 session cookie”误判成登录成功。

### 2. 表单 body 要由变量绑定生成

Koolaayun 让手册明确了一点：不要把 `username={{materials.username}}&password={{materials.password}}` 当成长期标准。账号密码可能包含空格、`&`、`=` 等字符，必须 URL encode。

规则里优先使用 `payload.formURLEncoded`：

- `fields` 放常量字段，例如 `submitme=1`。
- `fieldBindings` 放运行时变量路径，例如 `username -> materials.username`、`password -> materials.password`。

只有在确认字段值不会包含特殊字符时，才允许临时使用直接 template。

### 3. 302 下载链要分段解析，避免 cookie 泄漏

Koolaayun 登录后文件页中出现按钮：

```text
window.location = 'https://koolaayun.com/<file-id>?pt=<token>'
```

点击后链路是：

1. `pt` URL，需同站登录 cookie，302 到 `?download_token=...`。
2. `download_token` URL，仍需同站登录 cookie，302 到外部 CDN，例如 `xzs2.koalaclouds.com/...`。
3. 最终 CDN URL 是直接文件响应，不应附带 Koolaayun 的登录 cookie。

经验：这类站点不要直接 emit `pt` URL 并让下载器自动跨域跟跳转，因为手工设置的 `Cookie` header 可能被重定向带到外部域。标准做法是：

- 规则 HTTP step 对同站 `pt` 和 `download_token` 请求使用 `followRedirects: false`。
- 用 `responseHeader(Location)` 逐段提取下一跳。
- 每段提取后先用 `missing` 分支兜底，再用 `url.origin` 或同类能力做 URL 合法性验证；不能把空提取值直接送进 `url.origin`，否则会在 auth-expired 判定前变成 `Invalid template`。
- 如果某段只需要 `Location`，live probe 必须分别验证 GET 和 HEAD。Koolaayun 的 `download_token` GET 会返回 302 但携带大文件长度，HTTP/2/HTTP/1.1 客户端都可能把未完成 body 当成网络错误；该段应使用 HEAD 提取 `Location`。
- 最终 `emitRequest` 只 emit 外部 CDN URL，并设置 `attachAuthSession: false`。

### 4. 探测记录必须默认脱敏

Koolaayun 接入使用了真实账号验证登录，但文档、测试、最终回复都不应记录账号密码。探测输出只保留：

- HTTP 状态、最终 URL、content type、content length。
- cookie 名称，不保留 cookie value。
- tokenized URL 只记录结构，不保留完整 token。
- fixture 使用假账号、假 token、假 cookie。

## 新增站点流程手册

### 阶段 A: 站点探测

先用最小真实样本确认以下信息：

- URL 形态：所有 host、canonical host、path pattern、是否有 legacy URL。
- redirect 链：输入 URL 最终落到哪个文件页 URL。
- 登录入口：登录页 URL、需要的材料、是否需要验证码、成功后的确认页。
- token/cookie：CSRF、XSRF、formhash、session cookie 的来源、domain 和 percent-encoding。
- SPA/框架特征：Inertia version、组件名、错误字段、成功字段。
- 下载入口：文件页如何暴露 file id/token，generate/download endpoint 如何构造。
- 跳转链：是否需要 `followRedirects=false` 读取 `Location`，同站认证跳转和外部 CDN 跳转要分开记录。
- 直链响应：JSON 字段名、错误 payload、签名 URL 有效期、是否需要 Referer/cookie。
- 文件验证：真实文件大小、Content-Type、Content-Disposition，是否容易返回 HTML fallback。

不要在探测阶段扫描大量 artifacts；只保留必要的 HTTP 片段、fixture 和结论。真实账号、密码、cookie value、完整签名 URL、tokenized URL 不进文档和 fixture。

### 阶段 B: 规则设计

在 `WebShell-SPM/Sources/WebShellEngine/Resources/RuleBundles/` 中落规则：

- 可复用认证 workflow 放 `auth-workflows.bundle.json`。
- 已验证站点 provider 和站点专属下载 workflow 放 `auth-sites.bundle.json`。
- 未验证模板放 `auth-templates.bundle.json`，不要进入默认目录。
- matcher 要窄：host 覆盖真实来源，path pattern 覆盖已验证 URL shape。
- providerFamily 要稳定，通常用 `<site>-vip` 或 `<site>-free` 区分权限路径。
- `materialKeys` 只列真实必需材料。
- `expireConditions` 要指向下载 workflow 中真实能观察到的过期页面。
- 普通 form 登录必须配置 `successConditions` 和明确的 reject conditions；不能依赖 Inertia 专用启发式。
- capability 优先使用现有能力；如果必须新增 capability，要考虑旧客户端是否能同步新规则。
- 修改默认目录后，给 `RuleBundleFixtures.defaultBundle` 一个新的唯一 catalog version。

### 阶段 C: 认证 workflow

实现认证时按浏览器状态流建模：

- 先拿登录页和初始 cookie。
- 提取 token/version，而不是硬编码。
- 表单 body 用 `payload.formURLEncoded` 这类结构化能力从 `materials` 绑定生成，避免手拼未转义字符串。
- captcha OCR 应该作为 capability，不要写进 provider 特例代码。
- 登录 POST 后必须有第二个成功确认请求或可验证的成功字段。
- 明确区分 credentials rejected、captcha rejected、auth expired、material missing。
- captcha retry policy 必须来自 probe 结论。

### 阶段 D: 下载 workflow

实现下载时按“页面解析 -> 生成直链 -> emit 下载请求”拆分：

- 从输入 URL 提取 token/path。
- 必要时 canonicalize 文件页 URL。
- 文件页请求要 attach auth session 并保存响应 cookie。
- 后续 Origin/Referer 优先来自实际文件页响应 URL。
- auth 过期分支要在 emit 前判断。
- generate response 要在 emit 前验证直链字段非空且 URL 合法。
- 多段 302 链路要按段处理：同站认证跳转可以 attach auth session，外部 CDN 最终 emit 必须关闭 `attachAuthSession`。
- 如果需要读取 `Location`，HTTP step 使用 `followRedirects: false`，再用 `responseHeader` 提取，不要把中间 URL 当最终文件。
- 所有 HTML/JSON/header 提取出的 URL 字段，在调用 `url.origin` 前都要有 `missing` 分支；缺失时可设置一个已知合法的兜底 URL 让 workflow 完成，再由 `expireConditions` 或明确错误条件接管。
- final emit request 写清 Referer、必要浏览器 header、retryHints、filenameHints。
- trace 中避免记录完整签名 URL、cookie、token、密码。

### 阶段 E: 客户端账号和队列

新增登录站点后，要补齐客户端侧行为：

- 处理任务前通过 providerContext 找到 provider family。
- 无显式账号时按 provider family 复用运行中/已完成任务账号或 credential reference。
- auth prompt 要显示选中的 provider/account，而不是盲目 `default`。
- retry/requeue 不应创建重复行，也不应丢掉已选择账号。
- terminal 行状态优先于延迟 progress snapshot，避免失败后还显示活跃进度。

### 阶段 F: 测试矩阵

至少补这些测试：

- Rule compiler：默认目录加载、provider/auth/download workflow 存在、capability refs 完整。
- Matcher：所有 canonical host/path 命中，未支持 URL shape 明确不命中。
- Resolver success fixture：登录、文件页、generate-download、最终 emit 都按预期请求。
- Canonicalization fixture：输入 host 和 canonical file page host 不一致时仍能生成正确 Origin/Referer。
- Redirect-chain fixture：`pt` / `download_token` / CDN 这类多段 302 能逐段解析；只读 `Location` 的危险跳转要覆盖具体 HTTP method，并且最终 emit 不带认证 cookie。
- Negative fixture：generate response 缺少直链字段时在 emit 前失败；多段跳转缺少 `pt`、`download_token` 或最终 `Location` 时，Swift resolver 必须返回 auth-expired/站点语义错误，不能泄漏为 `url.origin requires a valid sourceURL`。
- Auth policy fixture：普通 form 登录的 success/reject conditions 能识别成功和错误凭据。
- Auth fixture：验证码错误重试、凭据错误停止、重复空登录页有上限、重试预算耗尽有明确错误。
- Client reducer：provider-family 账号复用、credential reference 复用、retry/requeue 不重复。
- Download execution：network lost 重新 resolve，临时文件先转入 app-owned staging，最终文件存在且大小正确。

### 阶段 G: 发布和真实验证

发布顺序：

1. `WebShell-SPM` 规则资源和 default catalog version 落地。
2. 跑 `cd WebShell-SPM && swift test`。
3. 跑客户端包测试；如果改到客户端下载/并发路径，先过 concurrency preflight。
4. 跑站点专属 Swift resolver smoke；curl/browser 只能作为探测记录，不能替代 Swift resolver 验收。
5. 发布默认规则包到 Control Plane。
6. Admin 和 Client 同步规则，确认 active bundle version 是新版本。
7. 再用 Control Plane 下发后的 catalog 跑 live smoke：先 resolve，再 download。
8. 跑 UI E2E，只把下载落盘文件作为最终真相。

Koolaayun 这类大文件站点，发布前至少跑 resolve-only Swift smoke，避免完整下载 600MB+ 文件成为每次规则修复的硬成本：

```sh
cd WebShellClient-Apple/Packages/WebShellClientKit
WEBSHELL_E2E_KOOLAAYUN_URL='https://koolaayun.com/<file-id>/<filename>.zip' \
WEBSHELL_E2E_KOOLAAYUN_USERNAME='<username>' \
WEBSHELL_E2E_KOOLAAYUN_PASSWORD='<password>' \
swift run WebShellClientSmoke live-resolve-koolaayun
```

发布到 Control Plane 后，用同一个 Swift 入口验证下发后的 active bundle：

```sh
swift run WebShellClientSmoke live-resolve-koolaayun --control-plane-url http://127.0.0.1:8089
```

验收输出只允许包含 bundle version、source/resolved host、path、是否有 query、method、auth context provider；不能打印账号、密码、cookie、完整 tokenized URL 或完整签名 URL。

真实 E2E 环境变量至少需要：

- `WEBSHELL_E2E_<SITE>_URL`
- `WEBSHELL_E2E_<SITE>_USERNAME`
- `WEBSHELL_E2E_<SITE>_PASSWORD`
- `WEBSHELL_E2E_<SITE>_ACCOUNT_ID`
- `WEBSHELL_E2E_EXPECTED_MIN_BYTES`
- 可选 `WEBSHELL_E2E_EXPECTED_BYTES`

### 快速排障表

- Provider 未命中：先查 matcher host/path，不要直接改 download workflow。
- 新 host 命中但直链为空：查 canonical file page、最终响应 URL、generate endpoint、响应 body 字段。
- 反复弹登录：查 selected account 是否从 `default` 误选，auth session key 是否同 provider/account。
- 验证码耗尽：查 retry policy 是否符合 probe 结果，再看 OCR debug 样本。
- 下载小文件或 HTML：查最终直链是否返回登录/错误页，用文件前缀和大小验证。
- `networkConnectionLost`：先判断发生在 resolve 还是最终下载；如果发生在中间 302 取 `Location`，检查该段 GET 是否需要改 HEAD，再重新 resolve 全量下载，不复用旧签名 URL。
- 临时文件缺失：查 `download_callback_temp_move_completed` 是否先于 staging trace。

## 完成标准

新增站点只有同时满足以下条件，才应进入默认目录：

- 规则只覆盖已验证 host/path。
- 登录成功和失败路径都有 fixture。
- 直链生成前有 response validation。
- Swift resolver smoke 通过；真实站点不能只靠 curl/browser probe 或 JSON 结构检查验收。
- 账号复用不会退回错误的 `default`。
- 本地下载文件通过大小和 HTML fallback 检查。
- 发布后 active bundle version 可追踪。
- 真实 E2E 的最终证据是磁盘文件，而不是单个 UI 状态或 HTTP 200。
