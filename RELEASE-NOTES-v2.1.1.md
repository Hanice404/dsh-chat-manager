# dsh-chat-manager 2.1.1

修复 2.1.0 中「归档清理…」点击后不出现面板的问题。

## 根因

`shell.overlay` 注册的组件是**槽位条目本身**，根标准数据源（`useSessions` / `useWorkspaces`，
由 ui-session 与 ui-workspace 通过 `slots.provideRoot({ hooks })` 提供）只作为**条目组件自己的
props** 传入。2.1.0 的 `ArchivePanel` 渲染 `ArchiveSettings` 时只传了 `compact`，没有转发这些
hooks，于是 `ArchiveSettings` 里第一行 `useSessions(s => s)` 抛 `TypeError`；React 渲染失败后
overlay 层什么都不画，表现就是「菜单项在、点了没反应」。

`settings.section` 那条入口没有这个问题，因为 `ArchiveSettings` 直接就是条目组件。

## 改动

- `ArchivePanel(props)` 现在把 `{ ...props, compact: true }` 转发给 `ArchiveSettings`。
- 新增 `PanelBoundary` 错误边界：面板渲染异常时在弹窗里显示
  「归档面板渲染失败：<原因>」，不再静默空白。
- 版本 `2.1.0 → 2.1.1`；README 中的安装版本同步。

## 验证方式（无需人工点击也能复现）

用真实 React 18.3.1 + `react-dom/server` 直接渲染槽位条目，模拟宿主传入的 props：

| 场景 | 2.1.0 | 2.1.1 |
| --- | --- | --- |
| 面板未打开（`open=false`） | `""` | `""` |
| 打开 + 转发 hooks | `THREW: useSessions is not a function` | 正常渲染出搜索框、归档会话行、取消归档/永久删除按钮 |

脚本与结论见 [FORK-BUILD.md](FORK-BUILD.md)。

---

# dsh-chat-manager 2.1.1 (English)

Fixes the 2.1.0 bug where selecting **Archive cleanup…** opened nothing.

## Root cause

A `shell.overlay` registration *is* the slot entry, so the root standard sources
(`useSessions` / `useWorkspaces`, published through `slots.provideRoot({ hooks })` by
ui-session and ui-workspace) arrive only as that entry component's own props. The 2.1.0
`ArchivePanel` rendered `ArchiveSettings` with just `compact`, so its first line
`useSessions(s => s)` threw a `TypeError`; a failed React render draws nothing, which
looks exactly like an unresponsive menu item.

The `settings.section` entry point was unaffected because there `ArchiveSettings` is the
entry component itself.

## Changes

- `ArchivePanel(props)` now forwards `{ ...props, compact: true }` to `ArchiveSettings`.
- New `PanelBoundary`: a render failure inside the overlay now shows
  `Archive panel failed to render: <reason>` in the dialog instead of a blank layer.
- Version `2.1.0 → 2.1.1`; README install specs updated.

## How it was verified

Rendering the slot entry with real React 18.3.1 + `react-dom/server` under the props a host
passes: with hooks forwarded 2.1.0 threw `useSessions is not a function`, and 2.1.1 renders
the search field, the archived-session row and its Unarchive / Delete permanently buttons.
See [FORK-BUILD.md](FORK-BUILD.md).

## 资产校验 / Asset checksum

```
sha256  dsh-chat-manager-2.1.1.tgz  c9a80bfd4d584768f21d34684c407844dbd1af153569437467750613cf20ff30
```
