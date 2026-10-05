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

## 真机回归缺陷（测试代理 4 轮 raid 实测后修复）

- 出生秒杀（3 点全中招）：北走廊巡逻 x∈[-20,8] 穿过更衣室里 spawn、NE
  spawn 在走廊口被东走廊 scav 直视、装卸区 scav 东端 x=-4 距 spawn 14m 在
  视距内；calm 5s 又在场景加载期耗尽。修复：北巡逻收敛到走廊段
  (x∈[-10.5,8])、scav 出生位移出更衣室、东巡逻南端 z7.8→5.5、装卸区巡逻
  东端 -4→-6（视距外）、NE spawn 移进储藏间 (19.5,-13.5)、calm 提到 10s
  且期内仅认 <6m。
- 尸体箱摸不到：平躺碰撞板罩住箱顶，沿尸体长轴 F 射线全打在板上。修复：
  尸体不再留任何碰撞（纯视觉），箱放身体侧旁并偏向玩家一侧。
- 附加：曳光 0.07→0.12s（原寿命截图都抓不到）。

## friction（追加）

- 实机与 headless 的观感差：视距/巡逻几何在纸上「看着对」，真跑才暴露
  出生点 LOS——以后摆敌点必须过一遍「spawn 无 LOS」清单（已写入
  test_scav_ai 距离断言兜底）。

## 出生安全第三轮：改为「真出生保护」

门洞瞄准线打地鼠不可持续（每间出生房的门洞总会对准某条巡逻）。最终方案：
_grace_t 25s 出生保护——玩家未离开出生点 4m 且未开火时，scav 完全不可见
（与几何无关）；玩家开火 → raid_game 广播 end_grace 全体结束；离开 4m 或
计时到期后恢复常规视锥/LOS 索敌。巡逻几何修正保留（作为远离出生点的常识）。
测试代理终验要点：三 spawn 站桩 15s 无交战、尸体无碰撞可跨过、尸体箱正面
可搜、 corpse-in-doorway 不再堵路。
