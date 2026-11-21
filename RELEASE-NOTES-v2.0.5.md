# dsh-chat-manager 2.0.5 · DSH 0.2.2-rc.5 兼容构建

Fork 构建，基于 npm 发布包 `dsh-chat-manager@2.0.4`。上游 GitHub 仓库（`WSL043/dsh-chat-manager`）
已不可访问，npm 为唯一可用来源。

## 相对于 2.0.4 的改动

- `version`: `2.0.4` → **`2.0.5`**
- 七个 `@deepseek-ai/dsh-client-*` peer 依赖：`0.2.2-rc.4 || 0.2.2-rc.3`
  → **`0.2.2-rc.5 || 0.2.2-rc.4 || 0.2.2-rc.3`**
- `compatibility.json`：`releaseTargets` 增加 `0.2.2-rc.5`，`latestTested` 改为 `0.2.2-rc.5`，
  记录 rc.5 安装包完整性哈希
- 运行逻辑（`src/`、`lib/client.js`、`locale/`、`assets/`）与 2.0.4 逐字节一致

## 为什么只改版本声明

rc.5 随包发布的升级指南里：

- `v0.2.2-rc.4` 一节仅一项：DeepSeek 模型上的网页搜索默认改回旧版 Messages 搜索；
- `v0.2.2-rc.3` 一节仅一项：DeepSeek 拒答错误码 `MALFORMED_RESPONSE` → `CONTENT_REFUSED`。

两者都不涉及本插件使用的 `workspaceRegistry`、`sessionPersistence`、`webServer`、`connection`、
`sessionQuery`、`contextMenus`、`settings.section`、`shell.overlay` 接口。

## 安装

```powershell
$dsh = 'D:\Program Files\DSH\resources\runtime\cli\bin\dsh.cmd'
& $dsh plugin --profile desktop add 'file:<下载路径>\dsh-chat-manager-2.0.5.tgz'
```

在官方 DSH 中也可以通过「插件 → 添加插件」粘贴本仓库 Release 资产的本地路径。

卸载：

```powershell
& $dsh plugin --profile desktop remove dsh-chat-manager
```

## 功能

- **归档内容搜索**：设置页「归档清理」，先按归档 ID 限定范围再限制结果数（最多 20 条）；
  全文索引关闭时回退到受限并发的事件扫描。
- **已归档会话永久删除**：会话右键菜单「永久删除」+ 带会话名称的二次确认。
  仅接受「已归档 + 宿主未加载 + 当前格式 + 本机 JSONL」的会话，删除期间持有官方独占写入句柄；
  宿主的 `workspace/session-activity` 扩展点会再确认一次该会话是否仍活跃。

## 验证情况

在 DSH 0.2.2-rc.5 / Cordis 4.1.0 / Windows 上：

- `dsh plugin --profile desktop add` 通过兼容性校验，无拒绝；
- 插件挂载后，`POST /plugins/dsh-session-delete/archive-search` 与 `/delete` 均返回 `401`
  （插件自身的宿主认证门禁），未知路径返回 `405`，可确认路由已注册且门禁生效；
- 未执行任何真实删除（不可逆操作，需使用者自行选择可丢弃会话）。

## 风险

- **永久删除不可撤销**，也不是安全擦除：不含外部附件、缓存、日志、备份、云端副本、非 JSONL 存储。
- 未完成的清理会把会话目录保留在 `<session-root 同级>/.dsh-session-delete-*` 隔离区。
- 本构建只做了版本声明扩展与安装/路由级验证，未在隔离 profile 重跑上游的破坏性验收用例。

---

# English summary

Fork build of `dsh-chat-manager` 2.0.5, based on the published npm package `dsh-chat-manager@2.0.4`
(the upstream GitHub repository is no longer available).

Changes versus 2.0.4: version bump, and the seven `@deepseek-ai/dsh-client-*` peer requirements
widened from `0.2.2-rc.4 || 0.2.2-rc.3` to `0.2.2-rc.5 || 0.2.2-rc.4 || 0.2.2-rc.3`; `compatibility.json`
now records `0.2.2-rc.5`. No runtime code was modified.

The rc.5 upgrade guide only lists a web-search default change for `v0.2.2-rc.4` and a DeepSeek refusal
error-code rename for `v0.2.2-rc.3`, neither of which touches the DSH surfaces this plugin uses.

Verified on DSH 0.2.2-rc.5 (Cordis 4.1.0, Windows): the plugin installs without a compatibility
rejection, both HTTP routes answer `401` behind the official Host request fence, and an unknown path
answers `405`. No real deletion was performed.

Permanent deletion is irreversible and is not secure erasure. Only an archived, unloaded,
current-format local JSONL session can be deleted.
