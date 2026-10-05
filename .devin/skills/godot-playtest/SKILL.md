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

## 仓库约定

- 玩家控制器内置遥测：`[NAV] pos=(x,z) yaw pitch target` 每 15 帧一行；交互 `[INTERACT] node | message`。验证断言 grep `/tmp/escape.log`，别信截图。
- 键盘转向已内置（`player.gd` 的 `KB_LOOK`）：`key Left/Right/Up/Down` 给确定性的 ~3.4°/2.9° 步进，鼠标捕获下别用合成 mouse_move。
- 房间 ~10×10m，交互射线 3m。拾取台上的 Keycard 需要 `Down` 俯视角 ~0.5-0.7 rad 才能照到。
- Esc 会切鼠标模式（脚本处理 ui_cancel）；测试中释放了鼠标就让游戏内路径重新捕获。

## 验证清单（交互/场景改动后）

1. `--import` 无 `SCRIPT ERROR`。
2. 运行 10s+，`grep NAV /tmp/escape.log | tail` 有正常坐标流。
3. 按改动点做针对性断言（如 `grep INTERACT` 确认交互触发）。
4. 关键日志行摘进本次 exec log 的 verification 字段。
