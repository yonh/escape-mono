# 白盒素材库（prop_kit）

白盒摆位约定：地图布局全部用 `prop_kit.spawn(kind, params)` 生成的
程序化占位物件，命名统一为 `prop_<kind>`（重名自动 `prop_<kind>2`、3…），
节点带 `prop_kind` 元数据。之后拿到真资产时按 kind 逐个替换即可，
布局数据（`factory_map.gd` 的 `LAYOUT`）不用动。

## 使用方式

```gdscript
const PROP_KIT := preload("res://scripts/gameplay/prop_kit.gd")

# 摆一个物件
var p := PROP_KIT.spawn(&"house", {"w": 9.0, "d": 7.0, "yaw": 90.0})
p.position = Vector3(x, 0, z)
root.add_child(p)

# 或在 raid_map.gd 的 LAYOUT 里加一行（推荐，数据驱动）：
{"zone": "village", "kind": "house", "pos": Vector3(4, 0, 8),
 "params": {"w": 9.0, "d": 7.0, "yaw": 90.0}},
```

`params.yaw` 单位是度。所有 prop 以 `position` 为底面中心（y=0 贴地）。

## 结构件（structure）

| kind | 说明 | params（默认值） |
|---|---|---|
| `house` | 单层小屋，南墙留门洞 | `w=8, d=6, h=3, door_w=1.6, door_h=2.1, yaw` |
| `warehouse` | 高大仓库棚，南侧 6m 门洞 | `w=14, d=20, h=6, yaw` |
| `wall` | 独立墙体 | `w=6, h=2.6, t=0.25, yaw` |
| `concrete_wall` | 边界混凝土围墙 | `len=10, h=3, yaw`（沿 x 方向延伸） |
| `fence` | 木栅栏段 | `len=6, h=1.2, yaw` |
| `ruins_wall` | 残破墙体（高低错落） | `len=8, h=2.2, yaw` |
| `barrier` | 道路隔离墩 | `yaw` |
| `sandbags` | 沙袋掩体 | `w=2.4, yaw` |
| `watchtower` | 瞭望塔（四柱+顶台） | `h=6, yaw` |
| `stairs` | 台阶 | `w=2, steps=6, yaw` |
| `plaza` | 地面铺装块 | `w=8, d=8` |
| `guard_booth` | 岗亭（小屋留门洞） | `yaw` |
| `concrete_block` | 混凝土块障碍 | `scale=1, yaw` |
| `tank_trap` | 反坦克拒马（钢架交叉） | `yaw` |

## 容器/家具（container）

| kind | 说明 | params |
|---|---|---|
| `crate_stack` | 木箱堆 | `n=3, yaw` |
| `barrel` | 油桶 | `n=2` |
| `shelf` | 货架 | `w=3, h=2.4, yaw` |
| `container` | 集装箱 | `yaw` |
| `table` | 桌子 | `yaw` |

## 场景件（scene）

| kind | 说明 | params |
|---|---|---|
| `vehicle` | 废弃车辆（车身+车厢+轮） | `yaw` |
| `tent` | 军用帐篷 | `w=4, d=5, yaw` |
| `pipe` | 大型管道 | `len=8, yaw` |
| `sign` | 标牌（杆+板） | `yaw` |
| `road` | 沥青路段（含分道虚线） | `len=12, w=8, yaw` |
| `power_pole` | 电线杆（杆+横担） | `yaw` |
| `well` | 水井（石圈+顶棚） | `yaw` |
| `hay_bale` | 干草卷（圆柱横躺） | `yaw` |
| `rubble` | 瓦砾堆（不规则块状） | `scale=1, yaw` |
| `scrap_pile` | 金属废料堆 | `yaw` |

## 植被/地貌（nature）

| kind | 说明 | params |
|---|---|---|
| `tree` | 阔叶树（干+冠） | `h=5` |
| `bush` | 灌木 | `r=0.8` |
| `rock` | 岩石 | `r=1.2` |
| `log` | 倒木（横躺树干障碍） | `len=4, yaw` |

## 工厂/室内件（factory wing，feat/factory-map 新增）

| kind | 说明 | params |
|---|---|---|
| `pillar` | 承重柱（柱身+柱础/柱头环带） | `w=0.7, h=6, yaw` |
| `wall_door` | 带门洞的隔墙段（两侧墙段+门楣，碰撞齐全） | `w=6, h=4, t=0.25, door_w=1.4, door_h=2.2, door_x=0, yaw` |
| `ceiling` | 吊顶板（房间/走廊顶） | `w=10, d=10, y=6, t=0.3, yaw` |
| `machine` | 机床（底座+机头+立柱+面板，各自碰撞） | `w=2.2, d=1.4, h=2.2, yaw` |
| `tank` | 立式储罐（圆柱+罐顶检修口） | `r=1.3, h=3.4, yaw` |
| `catwalk` | 二层钢平台（板+4腿+可选护栏 "both"/"near"/"far"/"none"） | `len=8, w=1.6, elev=2.7, rails="both", yaw` |
| `ramp` | 斜坡上桥（旋转板碰撞，朝向 -Z 升高） | `len=5, rise=2.7, w=1.5, yaw` |
| `railing` | 独立护栏段（立柱+横杆） | `len=4, yaw` |
| `locker` | 一排金属储物柜（门缝/把手贴片） | `n=4, yaw` |
| `duct` | 矩形通风管（管身+肋环） | `len=10, y=4.8, yaw` |
| `beam` | 吊车工字梁 | `len=10, y=5.4, yaw` |
| `lamp` | 吊挂工矿灯（杆+灯罩+发光灯泡；碰撞在灯罩高度） | `y=5.2, glow=暖黄` |
| `rollup_door` | 卷帘大门（门板+凸棱+卷筒+导轨，关闭态） | `w=5, h=4, yaw` |
| `forklift` | 叉车（车身+棚架+门架+货叉+轮） | `yaw, color` |
| `floor_mark` | 地面标线（"lane"通道线/"hazard"黄黑警示带，无碰撞） | `len=10, w=0.3, style="lane", yaw` |

## 色板 `PAL`

统一 StandardMaterial3D（无贴图白盒）：
`structure` 灰白墙体 · `wood` 木件 · `metal` 金属/集装箱 · `vegetation` 植被 ·
`asphalt` 路面 · `marking` 标线/标牌 · `hazard` 黄色警示 · `canvas` 帐篷布 ·
`rock` 岩石 · `vehicle` 车体 · `ground_cover` 地面。

换真资产时无需碰色板；prop 本身就是白盒占位，替换时保留节点名和
`prop_kind` 元数据即可被工具/测试识别。

## 地图数据 `raid_map.gd`

- `ZONES`：区域矩形 + 中文标签（村庄/工厂区/军营/林地/废墟/野地兜底），
  `zone_label_at(pos)` 供 HUD 显示当前区域。
- `LAYOUT`：`{zone, kind, pos, params}` 条目表，全部摆位都在这里改。
- `CRATES`：`{table, pos, color}` 战利品箱（table 对应 `loot_table.TABLES`）。
- `EXTRACTS` / `SPAWN` / `SPAWN_YAW`：撤离点与出生点。
- `MAP_MIN/MAX`：可活动范围（Vector2 x/z），边界围墙已按此围合。
- `build(root)`：搭出 `Props` / `LootCrates` / `Extracts` 三个组 +
  地面 + 撤离点发光台，返回 `{spawn, spawn_yaw, crates, extracts}`。
