# 2026-10-06 workflow-hardening

- **session goal**: 补上「持续改进」的确定性机制 + Git LFS。
- **did**: `.gitattributes`（二进制资产全走 LFS）；`tools/retro_due.py`（数上次 retro 后的日志，≥5 输出 RETRO_DUE）；AGENTS.md/WORKFLOW.md 会话入口改为先跑 retro_due；workflow-retro 技能加「上次处方回访(recurring 标记)」「经验上浮到全局技能」两步并定义 retro 日志格式（covered/patterns/prescriptions/promotable/revisit/deferred）；skill description 接 RETRO_DUE 关键词。
- **verification**: `retro_due.py` → `OK: 1/5 logs since last retro`；`git check-attr filter` 确认现有文本文件不命中 LFS；两次 push 成功（aaf016c 起）。
- **decisions**: none（本次属工作流自身迭代，非玩法/资产决策）。
- **friction**: project-manager 技能文档列了 `report` 子命令但本机脚本不支持——首次 retro 时可考虑记入（属全局技能问题，不堵本仓库）。
- **next**: M1 任务 1 —— Keycard 拾取进入玩家状态，门交互时判定。
