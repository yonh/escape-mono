---
name: asset-pipeline
description: 本仓库资产生命周期——当任务涉及新增/替换/制作游戏资产、登记或推进 assets/manifest.json 条目、把资产导入 game/ 工程时使用。覆盖 needed→done 状态机、来源选择（灰盒/AI 生成/Blender/第三方）、license 登记与导入验证。
---

# Asset Pipeline

原则：**灰盒先行**。玩法先用 CSG/纯色占位跑通，实体资产随后按此管线替换。
台账 `assets/manifest.json` 是唯一事实来源——任何进 `game/` 的资源必须能在里面追到来历与 license。

## 步骤

1. **登记**：任务需要资产而 manifest 无条目 → 先加一条（`status: needed`，写清 `target` 与期望规格到 `notes`）。有条目 → 读它，确认本次推进到哪个状态。
2. **选来源**（写进 `source` 字段）：
   - `greybox` — 场景内 CSG/占位，无文件。玩法验证优先选它。
   - `dreamina` — 2D 图/贴图 → 调 `dreamina-canvas-cli` 技能生成。
   - `blender` — 3D 模型 → 调 `blender-mcp` 技能制作，导出 `.glb`（源 `.blend` 一并存 `assets/models/`）。
   - 第三方（polyhaven 等）→ 下载文件 + 记录原站 license 到 `license` 字段。
3. **落盘**：成品放 `assets/<type>/<id>.<ext>`，源文件（.blend、画布工程链接等）同目录或 `notes` 记位置。状态推进到 `in_progress`。
4. **入工程**：状态置 `integrated`，跑 `python3 tools/sync_assets.py` 拷到 `game/assets/<type>/`，再在场景里替换占位节点引用。
5. **验证**：`python3 tools/check_manifest.py` 干净；`godot --path game --import` 无 SCRIPT ERROR；涉及观感/交互的按 `godot-playtest` 技能跑真机确认。
6. **收尾**：exec log 记 manifest 条目变更；资产到位后 `status: done`。

## 注意

- AI 生成资产的 `license` 填 CC0-1.0（与本库一致）；第三方资产必须如实填原 license。
- 一次只推进必要条目——manifest 里 `needed`  backlog 是给后续会话的队列，不用清完。
- 别把二进制资产直接拖进 `game/` 绕开台账。
