# Fork notes — 在 DSH 0.2.2-rc.1 上本地使用

本目录是 [WSL043/dsh-chat-manager](https://github.com/WSL043/dsh-chat-manager) `main` 分支
（commit `7b96955`，2026-11-06，"Qualify the narrow v2 candidate on official DSH RC1"）的 fork，
用于在本机官方 DSH Desktop `0.2.2-rc.1`（Cordis `4.1.0`）上安装验证。

## 改了什么

| 文件 | 改动 | 原因 |
| --- | --- | --- |
| `package.json` | `version` `2.0.0-alpha.1` → `2.0.0-alpha.2` | 本地重新打包需要一个新版本号，避免与上游候选混淆 |
| `tests/package-contract.test.mjs` | 同步断言版本号 | 保持 `pnpm test` 通过 |
| `README.md` / `README.en.md` / `AGENTS.md` / `docs/UNRELEASED-v2.md` | 同步版本号文案 | 同上 |
| —（无） | peer 依赖**未改** | v2 分支的 peerDependencies 本来就精确对准 `@deepseek-ai/dsh-client-*` `0.2.2-rc.1` 与 `@deepseek-ai/cordis` `4.1.0`，与本机运行时完全一致 |

宿主侧 API 已逐条核对过本机 `0.2.2-rc.1`（只读检查，依据 asar 内编译后的 `lib/index.js`）：

- `ctx.workspaceRegistry.archivedSessionIds` / `unarchiveSession(id)` — 存在（`dsh-workspace/lib/index.js:506`、`:553`）
- `ctx.sessionPersistence` JSONL 后端的 `stat` / `open` / `resolveCurrentLog` / `config.root` — 存在，`stat()` 返回结构与插件预期一致（`dsh-session-persistence-jsonl/lib/index.js:2407`、`:2488`、`:2570`、`:2902`）
- `ctx.get('connection').requestRejection(req)` — 存在，同步返回 `undefined`/状态码（`dsh-client-connection/lib/index.js:736`）
- `ctx.webServer.register({kind:'exact',path,handler})` — 存在并返回 disposer（`dsh-host-webserver/lib/index.js:375`）
- `sessionQuery.filterEvents` 存在；`searchSessions` 只在 SQLite 查询后端（本机已启用 `@deepseek-ai/dsh-experimental-session-search`）
- 客户端 `@deepseek-ai/dsh-client-ui-slots@0.2.2-rc.1` 包存在（rc.1 新增的公共 slot 注册层），插件的
  `ctx.slots.inject/register` 依赖它；其确切签名未能在宿主包外独立验证，只依赖上游 RC1 验收结论

## 本地安装（已完成，供复现）

```powershell
# 在仓库父目录执行
tar -czf dsh-chat-manager-2.0.0-alpha.2.tgz -C .pack package
& "D:\Program Files\DSH\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop add "file:E:\DeepSeekRuntime\APP\dsh-chat-manager\dsh-chat-manager-2.0.0-alpha.2.tgz"
```

卸载：

```powershell
& "D:\Program Files\DSH\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop remove dsh-chat-manager
```

## 以后要真正发布（在你有 git / npm 的机器上）

1. 先改包名：npm 上 `dsh-chat-manager` 属于上游作者 `wsl043`，无法发布同名包。二选一：
   - 发到自己的 scope：`"name": "@<你的npm用户名>/dsh-chat-manager"`；
   - 或用一个不冲突的新名字。
   改名时必须同步：`package.json#name`、`cordis.patch.yml` 里的 `name:`、
   `lib/client.js` 顶部的 `id:`、以及 `scripts/official-session-actions.mjs` 里生成该 id 的模板，
   然后 `pnpm run build` 重新生成 `lib/client.js`（CI 会校验生成的 bundle 与源码一致）。
2. 更新 `package.json#repository` 指向你的 fork。
3. 推送到 fork：
   ```bash
   git remote add mine https://github.com/<你>/dsh-chat-manager.git
   git push mine HEAD:main --tags
   ```
4. 校验后发布（预发布版本不要占用 `latest`）：
   ```bash
   pnpm install --frozen-lockfile
   pnpm test && pnpm run build && git diff --exit-code -- lib
   pnpm pack --pack-destination .artifacts
   npm publish .artifacts/dsh-chat-manager-2.0.0-alpha.2.tgz --access public --tag next
   ```
   上游的 `.github/workflows/publish.yml` 用的是 npm Trusted Publishing（OIDC，绑定上游仓库），
   fork 里需要改成 `NODE_AUTH_TOKEN`/`NPM_TOKEN` secret 才能走 CI 发布。

## 风险提示（来自上游文档，仍然适用）

- **永久删除不可撤销**，且不是安全擦除：不覆盖外部附件、缓存、日志、备份、云端副本、非 JSONL 存储。
- 只删除"已归档 + 未加载 + 当前格式"的本机会话；其余情况会拒绝，不会部分删除。
- 未完成的清理会把会话目录留在 `<session-root 同级>/.dsh-session-delete-*` 隔离区，需要人工处理。
- 该候选只在"隔离开窗 + 生成夹具"下通过过 RC1 UI 验收，**没有在真实用户日常 profile 上验证过**；
  本 fork 已按你的要求装进 `desktop` 日常 profile，一旦出现异常先执行上面的 remove 命令。
