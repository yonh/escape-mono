# DECISIONS (ADR)

格式：每条一个 ADR，倒序追加。`Status: accepted | superseded by ADR-xxxx`。

## ADR-0003 资产走 manifest 台账，文件与工程分离

- Status: accepted
- Context: 资产来源杂（灰盒、AI 生成、Blender、第三方），license 不一；game/ 里裸放文件会丢来历。
- Decision: `assets/` 持有源文件与成品，`manifest.json` 是唯一台账（id/type/status/source/license/file/target）；`tools/sync_assets.py` 把已登记的成品同步进 `game/assets/` 供 Godot 导入。
- Consequence: 多一步登记，换可追溯性；校验脚本兜底。

## ADR-0002 双许可：代码 MIT + 资产 CC0

- Status: accepted
- Context: 开源发布；AI 生成资产不宜附带强署名义务。
- Decision: 根 `LICENSE` MIT 管代码；`assets/LICENSE` CC0 管本库资产；第三方资产以 manifest 的 license 字段为准。

## ADR-0001 3D 第一人称 + 灰盒先行

- Status: accepted
- Context: 密室逃脱需要空间探索感；资产产能是瓶颈，不能让玩法等美术。
- Decision: Godot 4.7 第一人称；一律 CSG/纯色占位起步，玩法验证后资产按 manifest 状态机替换。
