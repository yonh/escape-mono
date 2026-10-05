# escape-mono

3D 第一人称密室逃脱游戏 —— Godot 4.7 monorepo，为「Agent 长期自动化开发」而组织。

A first-person escape-room game built with Godot 4.7, structured as a
monorepo designed for long-running agent-driven development: game code,
asset pipeline, and workflow documentation evolve together, and every work
session leaves an execution log that feeds periodic workflow retrospectives.

## 布局

| 目录 | 内容 | 许可 |
|---|---|---|
| `game/` | Godot 4.7 工程（场景、脚本、可运行骨架） | MIT |
| `assets/` | 独立资产库 + `manifest.json` 资产台账 | CC0（第三方资产以 manifest 为准） |
| `docs/` | ROADMAP / DECISIONS(ADR) / WORKFLOW / `exec-logs/` 执行日志 | MIT |
| `.devin/skills/` | 仓库技能：asset-pipeline、workflow-retro、godot-playtest | MIT |
| `tools/` | 校验与自动化脚本 | MIT |

## 运行

前置：Godot 4.7+、Git LFS（`brew install git-lfs && git lfs install`，二进制资产经 LFS 存取）。

```bash
# 首次或拉取新资产后先导入
godot --path game --import
# 运行
godot --path game
```

当前骨架：一间灰盒密室，WASD 移动、鼠标视角、F 交互、Esc 释放鼠标。
门和钥匙卡是占位交互，资产走 `assets/manifest.json` 逐步替换。

## 开发方式

本项目的工作流本身就是产物之一：

- 每个开发会话按 `docs/WORKFLOW.md` 的循环进行，结束时写一条
  `docs/exec-logs/` 执行日志。
- 资产不进仓库盲区 —— 一切经过 `assets/manifest.json` 登记，
  见 `.devin/skills/asset-pipeline`。
- 定期跑 `workflow-retro` 技能，根据执行日志回改
  `AGENTS.md` / `docs/WORKFLOW.md` / `.devin/skills/` —— 工作流会被持续修订。

## License

Code: MIT — see `LICENSE`. Assets: CC0 1.0 — see `assets/LICENSE`.
