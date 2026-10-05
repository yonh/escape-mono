---
name: godot-playtest
description: 真机运行/验证本仓库游戏——当需要启动 game/ 工程、验证场景或交互改动、截图或采集运行日志时使用。含本仓库特定的启动参数、NAV 遥测约定与本机合成输入的坑。
---

# Godot Playtest（本仓库）

本机合成输入与 Godot 鼠标捕获有坑，完整绕法先调全局 `godot-gui-testing` 技能——本文件只记仓库特定部分。

## 启动

```bash
godot --path game --import                                    # 新场景/资产后必先导入
godot --path game --resolution 960x600 --position 30,60 > /tmp/escape.log 2>&1 &
```

本机 `godot` 若不在 PATH：`~/godot47/Godot.app/Contents/MacOS/Godot`（Godot 4.7）。

## 游戏结构（ADR-0004 移植后）

- 主场景 `scenes/hideout.tscn`（生存屋）→ 出发垫进 `scenes/raid.tscn`（工厂）。
- 场景切换（change_scene_to_file + 地图建图）约 8-12s，验证时先 grep 日志再断言。
- 生存屋可交互物：储物箱 stash / 装备台 equip / 出发垫 depart_factory（F 键，射线 2.8m）。
- 工厂 raid：物资箱 loot（F 搜索→自动开格 UI，F/Esc/I 关闭）、撤离垫 extract
  （F 起 8s 读条，离开 4m 取消）；I 背包 / R 换弹 / 1-2 切枪 / H 自伤。

## 仓库约定

- 遥测：`[NAV] pos=(x,y,z) yaw pitch zone left fps target` 每 10 帧一行
  （hideout 与 raid_game 都打）；`[INTERACT] action | prompt` 在 F 触发时打印；
  `[SPAWN]`/`[DEPART]`/`[WPN]`/`[FIRE]` 关键事件行。验证断言 grep `/tmp/escape.log`，别信截图。
- 键盘转向已内置（fps_controller 的方向键分支）：`key Left/Right/Up/Down` 给确定性
  步进（约 3.4°/2.9°），鼠标捕获下别用合成 mouse_move。
- 低处目标（物资箱/出发垫）需要 `Down` 俯视角 ~0.5-0.7 rad 才能照到。
- Esc 会切鼠标模式；测试中释放了鼠标就让游戏内路径重新捕获（HUD 全部
  MOUSE_FILTER_IGNORE，LMB 点击可重新捕获）。

## 验证清单（交互/场景改动后）

1. `--import` 无 `SCRIPT ERROR`。
2. 运行 10s+，`grep NAV /tmp/escape.log | tail` 有正常坐标流。
3. 按改动点做针对性断言（如 `grep INTERACT` 确认交互触发、`grep SPAWN` 确认进图）。
4. 关键日志行摘进本次 exec log 的 verification 字段。
