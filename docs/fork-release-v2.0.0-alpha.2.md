# DSH Chat Manager v2.0.0-alpha.2 · DSH 0.2.2-rc.1 兼容验证版

基于 [WSL043/dsh-chat-manager](https://github.com/WSL043/dsh-chat-manager) `main` 分支
commit `7b96955`（未发布的 v2 候选 `2.0.0-alpha.1`）做的个人 fork 版本，仅做版本推进与本机兼容性验证。

## 本版改动 / What changed

- 版本号 `2.0.0-alpha.1` → **`2.0.0-alpha.2`**，同步 `README.md`、`README.en.md`、`AGENTS.md`、
  `docs/UNRELEASED-v2.md` 与 `tests/package-contract.test.mjs` 的版本断言。
- **未改动运行逻辑**：上游 v2 分支的 `peerDependencies` 本来就精确对准
  `@deepseek-ai/dsh-client-*` `0.2.2-rc.1` 与 `@deepseek-ai/cordis` `4.1.0`，
  与本版目标运行时完全一致。
- 新增 [`FORK-NOTES.md`](FORK-NOTES.md)：改动清单、本机安装/卸载命令、发布流程、风险说明。
- 新增 `scripts/publish-fork-release.ps1`：无需 git，通过 GitHub REST API 完成
  commit + tag + Release + 资产上传。

## 兼容性核对 / Compatibility checked

目标运行时：DeepSeekRuntime Desktop **0.2.2-rc.1**（Cordis **4.1.0**，Node 24.21.0）。

宿主侧 API 逐条只读核对通过（依据 asar 内编译后的 `lib/index.js`）：

| 契约 | 位置 | 结论 |
| --- | --- | --- |
| `workspaceRegistry.archivedSessionIds` / `unarchiveSession(id)` | `dsh-workspace/lib/index.js:506`、`:553` | 存在 |
| JSONL 后端 `stat` / `open` / `resolveCurrentLog` / `config.root` | `dsh-session-persistence-jsonl/lib/index.js:2407`、`:2488`、`:2570`、`:2902` | 存在，`stat()` 返回结构与插件预期一致 |
| `connection.requestRejection(req)` | `dsh-client-connection/lib/index.js:736` | 存在，同步返回 `undefined`/状态码 |
| `webServer.register({kind:'exact',…})` 返回 disposer | `dsh-host-webserver/lib/index.js:375` | 存在 |
| `sessionQuery.filterEvents` / `searchSessions` | `dsh-session-query/lib/index.js:1152`、`dsh-session-query-sqlite/lib/index.js:537` | 存在（检索依赖 SQLite 查询后端） |
| 客户端公共 slot 层 | `@deepseek-ai/dsh-client-ui-slots@0.2.2-rc.1` | 存在（rc.1 新增） |

安装验证（本机 `desktop` profile）：

- `dsh plugin --profile desktop add file:…tgz` 退出码 0，宿主未报兼容性拒绝；
- 两条 HTTP 路由已注册并通过认证门禁：`POST /plugins/dsh-session-delete/archive-search` 与
  `/delete` 均返回 `401 {"error":{"code":"forbidden"}}`（未知路径返回 `405`，可排除假阳性）。

## 安装 / Install

```powershell
# 从本 Release 资产安装
& "<DSH>\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop add "file:<下载路径>\dsh-chat-manager-2.0.0-alpha.2.tgz"
```

卸载：

```powershell
& "<DSH>\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop remove dsh-chat-manager
```

## 功能 / Features

- **归档内容搜索**：设置页「归档清理」，先限定归档会话 ID 再限制结果数量（最多 20 条），
  全文索引关闭时回退到受限并发的事件扫描。
- **已归档会话永久删除**：会话右键菜单「永久删除」+ 带会话名称的二次确认。
  仅接受「已归档 + 宿主未加载 + 当前格式 + 本机 JSONL」的会话，并在删除期间持有官方独占写入句柄。

## 风险 / Risks

- **永久删除不可撤销**，且不是安全擦除：不覆盖外部附件、缓存、日志、备份、云端副本、非 JSONL 存储。
- 未完成的清理会把会话目录保留在 `<session-root 同级>/.dsh-session-delete-*` 隔离区，需人工处理。
- 上游仅完成「隔离开窗 + 生成夹具」的 RC1 UI 验收；本 fork 额外在真实 `desktop` profile 验证了
  宿主侧加载与认证门禁，**未执行任何真实删除**。日常使用请自行评估。

## 上游与许可 / Upstream & license

- Fork of [WSL043/dsh-chat-manager](https://github.com/WSL043/dsh-chat-manager)，MIT License。
- 非官方社区插件，与 DeepSeek 无隶属或背书关系。
- 上游稳定线（npm `latest` = 1.5.21）目前只覆盖到 `0.2.2-alpha.3`，在 `0.2.2-rc.1` 上安装会被宿主拒绝
  （见上游 issue #38、#40）；本 fork 使用其未发布的 v2 候选来解决这一点。
