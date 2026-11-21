# Fork build 2.0.5 — 适配 DSH 0.2.2-rc.5

## 基线

上游 GitHub 仓库（`WSL043/dsh-chat-manager`）已被删除（HTTP 404），npm 上仍在发版。
本构建取自 npm **`dsh-chat-manager@2.0.4`**（`registry.npmjs.org` 官方 tarball，带 npm provenance），
该版本声明支持 `0.2.2-rc.3 || 0.2.2-rc.4`。

## 改动（仅元数据，运行逻辑未改）

| 文件 | 改动 |
| --- | --- |
| `package.json` | `version` `2.0.4` → `2.0.5`；7 个 `@deepseek-ai/dsh-client-*` peer 从 `0.2.2-rc.4 \|\| 0.2.2-rc.3` 扩展为 `0.2.2-rc.5 \|\| 0.2.2-rc.4 \|\| 0.2.2-rc.3` |
| `compatibility.json` | `releaseTargets` 增加 `0.2.2-rc.5`，`latestTested` 改为 `0.2.2-rc.5`，新增 rc.5 的 upstream 完整性记录；移除只供上游自动跟随用的 `autoFollowFrom` |
| 其余源码 `src/`、`lib/client.js`、`locale/`、`assets/` | 原样保留（与 2.0.4 逐字节一致） |

## 为什么只需要改 peer 声明

`docs/upgrade-guide`（随 rc.5 安装包发布）中，`v0.2.2-rc.4` 一节只有一项变更：
「DeepSeek 模型上的网页搜索默认改用旧版 Messages 搜索」——与本插件的 slot、服务、持久化 API 无关。
`v0.2.2-rc.3` 一节只有 DeepSeek 拒答错误码变更。`v0.2.2-rc.1` 一节的条目经核对也不涉及本插件使用的
`workspaceRegistry` / `sessionPersistence` / `webServer` / `connection` / `sessionQuery` /
`contextMenus` / `settings.section` / `shell.overlay` 接口（其中「自定义 Client 浮层须声明窗口区域」仅影响 macOS）。

安装后实测：插件在 rc.5 宿主上正常挂载，两条 HTTP 路由均通过认证门禁（401），未知路径 405。

## 安装 / 卸载

```powershell
$dsh = 'D:\Program Files\DSH\resources\runtime\cli\bin\dsh.cmd'
& $dsh plugin --profile desktop add 'file:E:\DeepSeekRuntime\APP\builds\2.0.5\dsh-chat-manager-2.0.5.tgz'
& $dsh plugin --profile desktop remove dsh-chat-manager
```

## 与 2.0.0-alpha.2 的行为差异（上游 2.0.x 自身的改进）

- 删除入口从「侧栏会话菜单项」改为官方 **会话右键菜单**（`ctx.contextMenus.register({ target: 'session' })`，
  配 `contextMenu.icon` 槽注册图标），只对**已归档**会话出现。
- 删除请求新增 `expectedArchived` 校验；宿主侧用 `ctx.waterfall('workspace/session-activity')`
  询问其它组件该会话是否仍活跃，再做一次“归档状态已变即中止”的复核。
- 归档标记的收尾改为 `reconcileDeletedArchive`（同时处理置顶状态），失败时如实报错。
- 请求边界抽到 `src/host/plugin-request.mjs`。

## 已知限制

- 「设置 → 归档清理」页挂在 `settings.section` 槽上，而本机 profile 把
  `@deepseek-ai/dsh-client-ui-settings` 设成了 `enabled: false`，该页不会渲染；
  需要时改 `cordis.patch.yml` 那一行为 `true` 再重载。
- 永久删除不可撤销，且不是安全擦除；仅接受「已归档 + 未加载 + 当前格式」的本机 JSONL 会话。
