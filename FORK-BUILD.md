# Fork build 2.1.1 — macOS / DSH 0.2.2-rc.5 兼容改造

## 基线

- 上游仓库 `WSL043/dsh-chat-manager` 已删除（HTTP 404），npm 上仍有 `dsh-chat-manager@2.0.4`。
- 本仓库 2.0.5 取自该 npm tarball，仅把 7 个 `@deepseek-ai/dsh-client-*` peer 扩到 `0.2.2-rc.5 || 0.2.2-rc.4 || 0.2.2-rc.3`。
- 本机目标：**macOS 26.6.2 / DeepSeekRuntime 0.2.2-rc.5**（`dsh --version` 与
  `app.asar/dsh/package.json` 一致），profile `~/.dsh/profiles/desktop`。

## 本轮兼容性核查（对 0.2.2-rc.5 逐项对齐，均为只读证据）

| 插件用到的接口 | rc.5 中的实际定义 | 结论 |
| --- | --- | --- |
| `ctx.contextMenus.register({ target: 'session' })` | `dsh-client-ui-context-menu/src/client/types.ts`：`ContextMenuTargetMap.session = { sessionId, displayTitle }`，`resolve(target, signal)`，`MenuAction` 支持 `danger / afterContent / icon / run` | 一致 |
| `contextMenu.icon` 键控图标槽 | 官方 `dsh-client-ui-context-menu` 以 `children: { 'contextMenu.icon': { kind: 'keyed', scope: 'root', inline: true } }` 声明 | 一致 |
| `shell.overlay` / `settings.section` 槽 | 两槽在 rc.5 均存在（settings 由 `dsh-client-ui-settings` 提供） | 一致 |
| 根 props `useSessions` / `useWorkspaces` | `ctx.slots.provideRoot({ hooks: { sessions } })`（ui-session）、`{ hooks: { workspaces } }`（ui-workspace） | 无需显式 inject |
| `sessionPersistence.stat / open('write') / resolveCurrentLog`、`config.root` | `dsh-session-persistence-jsonl/src/index.ts` 同名方法与 `formatStatus` / `header` / `location` 快照字段未变 | 一致 |
| `workspaceRegistry.archivedSessionIds / unarchiveSession / unpinSession` | `dsh-workspace/src/index.ts` 同名公开方法 | 一致 |
| `ctx.waterfall('workspace/session-activity')` | `dsh-workspace/src/index.ts` 同名 waterfall | 一致 |
| `sessionQuery.searchSessions / filterEvents`、`SESSION_QUERY_SEARCH_DISABLED` | `dsh-session-query` 同名 API 与错误码 | 一致 |
| `ctx.webServer.register({ kind: 'exact', path, handler })` | 未变，插件挂载后两条路由返回 401（认证门禁），未知路由 405 | 一致 |
| `dsh.client.inject` 中 `@deepseek-ai/dsh-client-ui-primitives` | 该包不随 app.asar 发布，由浏览器模块表提供；加载器对 `inject` 中**不在图里的**包直接跳过（`dsh-client-modules/src/client/system.ts`） | 不会因缺包失败 |

对照包（rc.4 与 rc.5 的 `dsh-client-ui-context-menu`、`dsh-client-ui-slots`、`dsh-session-query`、
`dsh-session-persistence-jsonl`、`dsh-workspace`）tarball 字节完全一致，说明 rc.5 没有改动本插件依赖的 API。

## 2.1.0 的改动

| 文件 | 改动 |
| --- | --- |
| `lib/client.js` | 新增 **归档清理…** 会话菜单项 + `shell.overlay` 面板（`dsh-chat-manager.archive-panel`），复用既有 `ArchiveSettings` 主体（`compact` 模式隐藏重复标题） |
| `package.json` | `version` `2.0.5` → `2.1.0`；peer 范围不变（仍为 rc.5 / rc.4 / rc.3） |
| `README*.md` | 安装版本改为 `2.1.0`，补充新入口说明 |
| `RELEASE-NOTES-v2.1.0.md` | 新增双语发布说明 |
| `scripts/release.sh` | 新增 POSIX 发布脚本（macOS/Linux），兼容原有 PowerShell 版本 |
| `FORK-BUILD.md` | 本文件，记录 macOS + rc.5 核查结论 |

### 为什么要加第二个入口

`~/.dsh/profiles/desktop/cordis.patch.yml` 把 `@deepseek-ai/dsh-client-ui-settings` 设成
`enabled: false`。此时 `settings.section` 槽永远不会出现，`ctx.slots.inject('settings.section', …)`
只挂起不执行 —— 归档搜索/清理页面在本机**完全不可达**（2.0.5 文档里列为“已知限制”）。
`shell.overlay` 由 `dsh-client-ui-context-menu` 无条件声明，因此把同一组件挂到 overlay、
用会话右键菜单的 **归档清理…** 打开，可以绕开设置界面的开关状态。

设置界面可用时，`settings.section` 页面依旧照常注册，两条入口并存。

## 安装 / 卸载（macOS）

```sh
APP="/Applications/DeepSeekRuntime.app"
DSH="$APP/Contents/Resources/runtime/cli/bin/dsh"

"$DSH" plugin --profile desktop add "file:$PWD/dsh-chat-manager-2.1.0.tgz"
"$DSH" plugin --profile desktop remove dsh-chat-manager
```

`plugin add` 会把包加进 profile 的 `dependencies` 与 `dsh.profile.bundles`；`patchReload: live`
会自动重载，无需重启应用。

本机 `github.com` 直连不稳定、`api.github.com` 正常；需要 git/pnpm 走外网时加代理：

```sh
export HTTPS_PROXY=http://127.0.0.1:7890
git fetch origin && git reset --hard origin/main
```

安装后自检（会话 Cookie 之外的两条路由都应返回 401，未注册路径返回 405）：

```sh
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:<port>/plugins/dsh-session-delete/delete
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:<port>/plugins/dsh-session-delete/archive-search
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:<port>/plugins/dsh-session-delete/bogus
```

## 2.1.1：面板不出现的根因与修复

`shell.overlay` 的注册项**就是槽位条目**，根标准数据源（`useSessions` / `useWorkspaces`，
由 `ui-session` / `ui-workspace` 用 `slots.provideRoot({ hooks })` 发布）只作为该条目组件
自身的 props 传入。2.1.0 的 `ArchivePanel` 渲染 `ArchiveSettings` 时只传 `compact`，
hooks 没有转发下去 → `useSessions(s => s)` 抛 `TypeError` → React 渲染失败、overlay 层空白，
表现为「菜单项在，点了没反应」。`settings.section` 那条入口不受影响，因为那里
`ArchiveSettings` 本身就是条目组件。

修复：`ArchivePanel(props)` 转发 `{ ...props, compact: true }`；另加 `PanelBoundary`
错误边界，渲染异常时在弹窗内显示原因，不再静默空白。

### 这条路径的自动化验证（不需要人工点击）

用真实 React 18.3.1 + `react-dom/server` 直接渲染槽位条目，宿主 props 用桩提供：

| 场景 | 2.1.0 | 2.1.1 |
| --- | --- | --- |
| 面板未打开 | `""` | `""` |
| 打开 + 转发 hooks | `THREW: useSessions is not a function` | 渲染出搜索框、归档会话行（标题/工作区）、取消归档与永久删除按钮、关闭按钮 |

```sh
# 复现脚本（自建临时目录，装 react/react-dom 后运行）
BUNDLE=<仓库>/lib/client.js node render-test.mjs
```

## 仍未验证 / 已知限制

- 真实浏览器点击链路仍建议人工确认一次（本机未开 CDP，无法自动驱动渲染进程）。
  上一轮用户实测：菜单项可见；本轮已用真实 React 复现并修掉渲染异常。
- 永久删除不可撤销，且不是安全擦除；仅接受「已归档 + 未加载 + 当前格式」的本机 JSONL 会话。
- 归档搜索在有全文索引时走官方查询，无索引时退化为有限并发的官方事件筛选。
