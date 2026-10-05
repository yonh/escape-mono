# 2026-10-05 factory-raid-port

- **session goal**: 按用户指定，在本仓库实现「类塔科夫 raid 玩法 + 工厂关卡」（目标级开发）；此前误投到 yonh/godot_escape（PR#35 已合并），按指示改为移植到 escape-mono。
- **did**: `game/` 整体移植玩法代码——game_state/inventory+inventory_ui/item_catalog/equipment/weapon_data+weapon_controller/health+health_ui/searchable+loot_crate+loot_table/raid_kit/interactable/prop_kit/factory_map + fps_controller；hideout（储物箱/装备台/单块工厂出发垫）↔ raid 双场景；raid_game 裁为工厂-only（去 raid_map/day_night/JEV）；删 M0 密室骨架（main.tscn/player.tscn/player.gd/interactable.gd）；main_scene→hideout.tscn；ADR-0004 + ROADMAP 重排 + manifest target 清理；移植 8 个 headless 测试；移植 docs/factory-map.md + docs/props-library.md；playtest 技能更新为移植后约定；世界 Label3D 统一 UIFONT 修 CJK 丢字。
- **verification**: `check_manifest.py` OK(4)；`--path game --import` 0 SCRIPT ERROR；8 测试全过（test_factory_map 0 failures 含吊顶覆盖/同帧 MIA 回归）；**真机 playtest 全链路通过**：`[INTERACT] depart_factory`→`[DEPART]`→`[SPAWN] map=factory (10,14.2)`，HUD 区名+倒计时正常，全封闭无天空、不穿墙、门洞全通，开箱拿 压缩饼干 入包（1.5kg），GATE-0 8s 读条→`[Raid] extracted: 5 moved, 0 dropped`→stash 合并可见；55-60fps。
- **decisions**: ADR-0004（玩法移植 + 仅保留工厂单图）。
- **friction**: 本机 `godot` 不在 PATH（用 ~/godot47 路径，已写入 playtest 技能）；Label3D 默认字体丢 CJK（已修，但全局技能 godot-gui-testing 未提 Label3D——下次 retro 可上浮）；escape-mono 无 blueprint（已建议，见会话）。
- **next**: PR 待审；M2 首件按 ROADMAP——敌对环境方案（游荡 AI 占位/伤害源）；manifest keycard/exit_door 重新登记或移除。
