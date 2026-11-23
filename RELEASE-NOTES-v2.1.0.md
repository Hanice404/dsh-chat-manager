# dsh-chat-manager 2.1.0

目标宿主：**DSH 0.2.2-rc.5**（peer 仍接受 `0.2.2-rc.5 || 0.2.2-rc.4 || 0.2.2-rc.3`）。
本次为 macOS 桌面 profile 的兼容改造，删除/归档的核心校验逻辑未改。

## 新增

- **归档清理…** 会话右键菜单项：打开 `shell.overlay` 面板，内含与「设置 → 归档清理」相同的
  归档内容搜索、取消归档与永久删除能力。
- `scripts/release.sh`：macOS/Linux 发布脚本（打包 → 提交 → 打标签 → 推送 → 建 Release）。

## 修复

- 当 profile 关闭 `@deepseek-ai/dsh-client-ui-settings` 时（本机 `~/.dsh/profiles/desktop` 即如此），
  `settings.section` 槽不会出现，归档搜索页面从此不可达。现在改由会话菜单 + overlay 进入，
  设置界面可用时两条入口并存。

## 兼容性核查

对 rc.5 逐项核对了本插件使用的公开接口（context menu target `session`、`contextMenu.icon`
键控槽、`shell.overlay` / `settings.section`、根 hooks `useSessions` / `useWorkspaces`、
`sessionPersistence`、`workspaceRegistry` 归档 API、`workspace/session-activity` waterfall、
`sessionQuery` 搜索与 `webServer.register`）。rc.4 与 rc.5 的对应官方包 tarball 字节一致，
说明 rc.5 未引入破坏性变更。详见 [FORK-BUILD.md](FORK-BUILD.md)。

---

# dsh-chat-manager 2.1.0 (English)

Target host: **DSH 0.2.2-rc.5** (peers still accept `0.2.2-rc.5 || 0.2.2-rc.4 || 0.2.2-rc.3`).
This is a compatibility pass for the macOS desktop profile; the deletion and archive
verification logic is unchanged.

## Added

- An **Archive cleanup…** entry in the session context menu that opens a `shell.overlay`
  panel hosting the same archive search, unarchive and permanent-delete actions as
  **Settings → Archive cleanup**.
- `scripts/release.sh`, a POSIX release helper (pack → commit → tag → push → release).

## Fixed

- Profiles that disable `@deepseek-ai/dsh-client-ui-settings` never mount the
  `settings.section` slot, which made the archive page unreachable. It is now reachable
  from the session menu; both entry points coexist when the settings UI is enabled.

## Compatibility review

Every public surface this plugin uses was checked against rc.5: the `session` context-menu
target, the keyed `contextMenu.icon` slot, `shell.overlay` and `settings.section`, the root
`useSessions` / `useWorkspaces` hooks, `sessionPersistence`, the workspace archive API, the
`workspace/session-activity` waterfall, `sessionQuery` search and `webServer.register`.
The rc.4 and rc.5 tarballs for those official packages are byte-identical, so rc.5 shipped no
breaking change for this plugin. See [FORK-BUILD.md](FORK-BUILD.md).

## 资产校验 / Asset checksum

```
sha256  dsh-chat-manager-2.1.0.tgz  033c533430f5c3c266bb225a687d364f05b52d69a963c402df2b90d412b456de
```
