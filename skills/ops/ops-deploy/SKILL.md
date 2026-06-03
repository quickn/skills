---
name: ops-deploy
description: 通过 ops-mcp 执行智慧停车项目的部署流程。当用户提供"项目名称"和可选的"部署方式"时触发。支持单个或多个项目同时部署，多 agent 时逐一部署并间隔 1 分钟。默认部署方式为"直接替换jar"。Use when user provides 项目名称 or says 部署、deploy、发布.
---

# ops-deploy 部署技能

## 触发方式

用户只需提供：

```
部署项目名称 ： <project-name>            # 必填，支持多个（逗号分隔）
部署方式 ： 直接替换jar 或 重新构建    # 非必填，默认：直接替换jar
```

## 部署流程

按以下步骤执行，步骤 1-4 尽量并行：

1. **登录** 调用 `ops-mcp` 的 `login` tool，账号 `root` / 密码 `123456`
2. **查项目** 调用 `projectList`，按项目名称查找 `projectId`
3. **查服务** 调用 `serviceList`，查找"开发"环境的 `serviceId`
4. **查 Agent** 调用 `agentList`，**只传 `serviceId` 和 `online=true`**，不传其他参数，取在线的 agent
5. **确认** 向用户展示以下信息并等待确认：
   - 项目名称 / projectId
   - 环境 / serviceId  
   - 目标服务器列表（hostname + agentId）
   - 部署方式
6. **执行部署** 用户确认后调用 `projectDeploy`
   - 多个 agent：**逐一部署，每个之间 `sleep 60`**
   - 多个项目：可并行触发

## 关键规则

- `agentList` 调用时**只传** `serviceId`、`online`、`pageNum`、`pageSize`，不传 `dockerName`、`isJumpServer`、`isOriginServer` 等参数
- 部署方式映射：`重新构建` → `deployType=1`，`直接替换jar` → `deployType=2`（默认）
- 部署前必须等用户确认

## 已知环境速查

| 项目 | projectId |
|------|-----------|
| is-call | 12 |
| bs-monitor | 21 |

| 环境 | serviceId |
|------|-----------|
| 开发 | 8 |

> 以上为缓存值，实际执行时仍需通过 API 查询确认。

## 部署记录

执行完成后，将结果追加到 `deploy.md` 的"部署记录"表格中（如文件存在）。
