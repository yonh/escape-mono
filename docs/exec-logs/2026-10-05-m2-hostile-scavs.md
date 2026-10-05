# exec log 2026-10-05 — M2 敌对环境（scav AI + 锁区 + 尸体掉装）

## 干了什么

- 新 `scav_ai.gd`：CharacterBody3D 白盒游荡者（胶囊身体+头+胸挂），
  状态机 patrol→chase→attack→search→(dead)；索敌 = 视距15m + ±60°视锥 +
  LOS 射线；命中判定 hit_chance 概率 hitscan（曳光 0.07s）；中弹即警觉；
  阵亡倒地 + 原地掉「尸体箱」（loot_crate，新 scav 战利品表，4×3 格）。
- `factory_map.gd`：`ENEMIES` 7 个出生位+巡逻路点（主车间 2 空巷 + 北/东/西
  走廊 + 装卸区西 + 车间）；`LOCKED_DOORS` 危险品库门洞挂红卡门；危险品库内
  新增 valuable 高价值箱（13→14 箱位）。
- 新 `locked_door.gd`：门扇 interactable（action=`locked_door`），背包含
  keycard_red 才开门（卡不消耗），开门滑入门楣 + 关碰撞；无卡提示所需钥匙。
- `raid_game.gd`：`_hook_enemies` 给每只 scav `set_target(player)` + 接 died
  → 尸体箱挂进 LootCrates 复用自动开箱钩子；HUD 新增「敌人 N」计数（左上角
  血量下方）；[NAV] 增加 foes= 字段；F 分发新增 `locked_door`。
- `loot_table.gd`：新增 scav 表（随身弹药/医疗/食物，pm 偶见，keycard_red 5%）。
- 测试：新 `tools/test_scav_ai.gd`（巡逻推进/冷静期/视锥+LOS 索敌/开火掉血/
  中弹警觉/阵亡掉箱+尸体搜索/锁门拒开与持卡开/巡逻点不出界）；
  test_loot_search 表数断言改 id 集合；test_factory_map 全程零失败。

## 决定

- 敌人用 loot_crate 当尸体（不写第二套尸检系统）：searched→pending→开箱
  全链免费继承；尸体就是「会掉东西的箱」，语义吻合。
- 钥匙卡不消耗：类塔科夫钥匙语义——进过门即解锁，锁区是高价值房间的风险
  回报；钥匙卡来源 = scav 掉落 5% / valuable 藏匿点 4%。
- 冷静期 5s + >5m 不锁：出生点旁（装卸区、北走廊东端）敌人不秒锁，但贴脸
  仍可见——保留塔科夫「出图即对峙」的张力。
- 锁区选危险品库（自带 tank/barrel 氛围）而非新房间：零布局改动。

## friction

- `get_tree().current_scene` 在 `-s` SceneTree 测试脚本里为 null —— 曳光
  首次 add_child 到 null 静默失败，后续 look_at 报错。教训：节点归属一律
  挂自身或父级，别碰 current_scene（playtest 技能可补这条坑）。
- factory_map 测试「Props 数 = LAYOUT.size()」的口径要求非 LAYOUT 对象（门）
  放独立 node——合理但易踩；已在代码注释里体现。

## 验证

- `test_scav_ai` 等 9 个 headless 脚本全 PASS；`check_manifest.py` OK；
  `--import` 无 SCRIPT ERROR。
- 真机 playtest：待测试代理跑（战斗/掉装/锁门/撤离）。
