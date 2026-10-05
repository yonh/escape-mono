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

## ADR-0004 玩法移植：raid 循环 + 工厂关卡（来源 yonh/godot_escape）

- Status: accepted
- Context: 用户指定在本仓库做「类塔科夫 raid 玩法 + 工厂关卡」的目标级开发；骨架灰盒密室仅作 M0 起步，不承载该玩法。godot_escape 已有完整可玩的 raid 循环（生存屋→出发→搜刮/开箱→撤离/阵亡/超时→回生存屋合并仓库）与工厂室内 CQB 关卡。
- Decision: 将玩法代码整体移植进 `game/`（prop_kit 白盒道具 + factory_map 布局 + hideout/raid 双场景 + 库存/装备/武器/血量/搜索全链），删掉 skeleton 密室场景与占位脚本；本次只保留工厂单图，野外大图/JEV 规划/昼夜系统不随迁（属 godot_escape 室外栈，与本里程碑无关）。`game_state.raid_map_id` 保留分发入口，后续新图走同一机制。
- Consequence: 仓库定位从「密室逃脱」转为「类塔科夫逃离 raid」；ROADMAP M1 起按新玩法重排，原密室解谜里程碑暂停；全程序化白盒无外部资产，manifest 登记项不变。

## ADR-0005 M2 敌对环境：白盒 scav AI + 尸体即 loot_crate + 钥匙不消耗

- Status: accepted
- Context: M2 要求敌对环境、谜题式锁区、更多物资箱表、难度变化。此前无任何敌方实体；loot_crate 已具备「搜索→pending→开格」全链。
- Decision: `scav_ai.gd` 单类承载敌人（CharacterBody3D 白盒人形）：巡逻路点 → 视距/±60°视锥/LOS 射线索敌 → 追击 → 近距 hitscan 概率命中（曳光可视）→ 脱战搜索回巡逻；中弹立即警觉。阵亡倒地并原地生成 loot_crate（`scav` 战利品表）当尸体——不造第二套尸检/尸体系统。锁区用 `locked_door.gd`：背包持 keycard_red 按 F 开门，钥匙不消耗；危险品库为首个锁区。难度靠出生冷静期（5s 内 >5m 不锁）+ 巡逻分区避让出生点/撤离垫调参，不改撤离规则。
- Consequence: 敌人与开箱共用一条 loot 链（维护面小）；钥匙卡有持久价值（不消耗）；敌方数值集中在 scav_ai 顶部便于 tier 扩展；寻路仍是路点直线（厂房开阔，无 A* 需求）。
