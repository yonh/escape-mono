# AGENTS.md

面向长期自动化开发的密室逃脱 monorepo（Godot 4.7）。规则少而硬，细节走指针。

## 布局

- `game/` — Godot 工程（`--path game`）。代码 MIT。
- `assets/` — 独立资产库，一切经 `manifest.json` 登记。CC0。
- `docs/` — `ROADMAP.md` 目标，`DECISIONS.md` ADR，`WORKFLOW.md` 开发循环，`exec-logs/` 执行日志。
- `.devin/skills/` — 仓库技能：asset-pipeline、workflow-retro、godot-playtest。
- `tools/` — `check_manifest.py`（台账校验）、`sync_assets.py`（资产入工程）、`retro_due.py`（复盘触发器）。

## 每个会话的循环

入口：跑 `python3 tools/retro_due.py` —— 输出 `RETRO_DUE` 就先执行 `workflow-retro`
技能再干活 → 读 `docs/ROADMAP.md` 当前里程碑 + 最新一条 `docs/exec-logs/` → 干活 →
收尾写执行日志（模板 `docs/exec-logs/TEMPLATE.md`）。完整循环见 `docs/WORKFLOW.md`。

## 硬规则

- 资产不裸放：任何 `game/` 里的非代码资源必须能在 `assets/manifest.json` 追到来历与 license。改动资产走 `asset-pipeline` 技能。
- 收尾三件套：跑通 `python3 tools/check_manifest.py`、`godot --path game --import` 无 SCRIPT ERROR、写 exec log。
- 测试/游玩验证走 `godot-playtest` 技能（本机合成输入有坑，技能里有绕法）。
- 感觉到工作流摩擦（重复步骤、文档缺失、命令易错）：写进 exec log 的 friction 字段；定期由 `workflow-retro` 技能回改本文件与技能。

## 验证命令

```bash
python3 tools/check_manifest.py
godot --path game --import   # 导入 + 编译检查（Godot 4.7，PATH 中）
godot --path game --resolution 960x600 --position 30,60
```
