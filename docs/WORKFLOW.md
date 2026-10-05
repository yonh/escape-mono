# WORKFLOW — Agent 开发循环

本文件由 `workflow-retro` 技能定期修订；改动会在 `docs/exec-logs/` 留 retro 记录。
当前版本：v1（初版，未经 retro）。

## 会话循环

1. **定位**：跑 `python3 tools/retro_due.py` —— `RETRO_DUE` 时先执行 `workflow-retro` 技能再继续 → 读 `docs/ROADMAP.md` 当前里程碑 → 读最新一条 `docs/exec-logs/`（上次进展、遗留 friction）→ `git status`。
2. **选任务**：取里程碑内最靠前的未完成项；不确定时在日志里记 `blocked:` 并向用户确认。
3. **干活**：
   - 玩法/场景/脚本 → `game/`。
   - 任何资产需求 → 先登记 `assets/manifest.json`（status: needed），再按 `asset-pipeline` 技能推进。灰盒先行：先用 CSG/纯色占位让玩法跑通，资产随后替换。
   - 设计抉择（玩法机制、目录约定、工具取舍）→ 追加一条 ADR 到 `docs/DECISIONS.md`。
4. **验证**（收尾三件套，AGENTS.md 有命令）：
   - `python3 tools/check_manifest.py` 干净。
   - `godot --path game --import` 无 `SCRIPT ERROR`。
   - 涉及交互/场景的改动 → 按 `godot-playtest` 技能跑一遍真机验证，日志断言优先于肉眼截图。
5. **写 exec log**：复制 `docs/exec-logs/TEMPLATE.md` 为 `YYYY-MM-DD-<slug>.md` 填实。friction 字段必填（没有就写 "none"）——它是 retro 的输入。
6. **提交**：一次会话一个或多个聚焦 commit；message 说 why。不 push，除非用户要求。

## 约定

- 场景占位统一用 CSGBox3D；可交互物挂 `scripts/interactable.gd`（class_name Interactable）。
- 遥测用带前缀的 print（`[NAV]`、`[INTERACT]`），验证时 grep 日志，别信截图。
- `assets/manifest.json` 状态机：needed → placeholder → in_progress → integrated → done。
- exec log 文件名即时间序；retro 日志命名 `YYYY-MM-DD-retro.md`。

## 节奏

- 触发是确定性的：会话开头跑 `tools/retro_due.py`（≥5 条未复盘日志 → `RETRO_DUE`），不靠记性。
- 用户喊「复盘/retro」随时可直接触发 `workflow-retro`。
- retro 只改「下一次会更顺」的东西：文档、技能、脚本、约定。不为改而改。
