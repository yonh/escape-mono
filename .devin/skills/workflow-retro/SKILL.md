---
name: workflow-retro
description: 工作流复盘——当用户说「复盘/retro/优化工作流」、执行日志攒了 ~5 条未复盘、或干活时反复踩同一个坑时使用。读 docs/exec-logs/ 里的 friction 记录，回改 AGENTS.md、docs/WORKFLOW.md、.devin/skills/ 和 tools/，让下一个会话更顺。
---

# Workflow Retro

输入是 `docs/exec-logs/` 的 friction 字段；产出是对工作流自身的改动 + 一条 retro 日志。
只改「下一次会更顺」的东西：文档措辞、技能步骤、校验脚本、目录约定。不为改而改。

## 步骤

1. **圈定范围**：找 `docs/exec-logs/` 里最新的 `*-retro.md`（无则从第一条起），列出其后所有会话日志。
2. **读 friction**：逐条提取 friction/next 字段 + 各日志里反复出现的失败命令、绕路、缺文档信号。同类合并成模式。
3. **对每个模式开一处方**，落到具体文件：
   - 重复的手工步骤 → 写进 `tools/` 脚本或技能步骤。
   - 文档缺失/误导 → 改 `AGENTS.md`、`docs/WORKFLOW.md` 或对应技能（措辞收紧，别加空话）。
   - 约定被违反 → 要么加校验脚本兜底，要么承认约定不好、改约定。
   - 技能没触发/触发错 → 改该技能 description 的分支措辞。
4. **应用改动**，每条处方对应一处真实编辑；拿不准的先问用户。
5. **写 retro 日志**：`docs/exec-logs/YYYY-MM-DD-retro.md`，列出：覆盖的会话区间、发现的模式、每处改动的文件与理由。
6. **bump**：`docs/WORKFLOW.md` 顶部版本号 +1，注「经 retro YYYY-MM-DD 修订」。

## 反模式

- 把日志里没有的问题当问题改。
- 一次 retro 改超过 ~5 处——贪多会让工作流不稳定，剩下的记下 retro 日志留给下次。
- 新增 pass-through 文档（只复述别处的文档）。
