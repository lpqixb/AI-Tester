# KofQMvp — Q 版小队格斗（Godot 4）

玩法对齐拳皇 2002 品类（3 人队、气槽、取消、超必杀），角色与美术为**原创 Q 版**。  
规划文档：[`docs/kof-q-mvp/`](../docs/kof-q-mvp/INDEX.md)

## 进度

| Phase | 状态 |
|-------|------|
| 0 工程骨架 | 完成 |
| 1 互殴闭环 | 完成 |
| 2 气槽/必杀/取消/回避 | 完成 |
| 3 小队 3v3 + 四角色 | 完成 |
| 4 Training / Arcade / AI | 完成 |
| 5 Q 版表现与验收 | 完成 |

## 本机运行（导入即玩）

1. 安装 **Godot 4.3+**（[下载](https://godotengine.org/download)）
2. Godot → **Import** → 选择本目录的 `project.godot`
3. 按 F5 运行（主场景 Boot → Title）

### 模式

- **Versus**：双方各选 3 人 → 本地 2P 对战
- **Training**：锁血锁气；`R` 复位；`B` 假人防；`F` 显示框
- **Arcade**：1P 选 3 人，打 4 关 CPU

### 键位

| 动作 | 1P | 2P |
|------|----|----|
| 走 / 跳 / 蹲 | WASD（A 后走，S 蹲） | 方向键 |
| 冲刺 / 后跳 | 连点 D / 连点 A | 连点 → / 连点 ← |
| 轻拳 / 轻脚 | J / K | Num0 / Num. |
| 中拳 / 中脚 | U / I | Num1 / Num2 |
| 跳攻 / 过身 | 跳起后 J / K / U；跳过对手可换边 | 跳起后 Num0 / Num. / Num1 |
| 投技 | 近身 J+K | 近身 Num0+Num. |
| 紧急回避 | 后方向 + I | 后方向 + Num2 |
| 暂停 | Esc | Esc |

**入门连招（赤焰）**：`J`(5A) → `↓↘→+J`(236A) → `↓↘→↓↘→+J`(236236A 超必杀，耗 1 格气)

## 自动化测试

```bash
# 需 Godot 4.3+ 在 PATH，或指定二进制：
godot --headless --path KofQMvp --script res://tests/run_combat_tests.gd
python3 KofQMvp/tests/test_aabb2.py
```

## 导出 Demo

编辑器：Project → Export → **Linux Demo**（见 `export_presets.cfg`），或：

```bash
godot --headless --path KofQMvp --export-release "Linux Demo" ../build/KofQMvp.x86_64
```

## 角色（原创）

| ID | 名 | 定位 |
|----|----|------|
| C01 | 赤焰 | 均衡扑手 |
| C02 | 青影 | 迅敏连段 |
| C03 | 岩岳 | 重装破防 |
| C04 | 铃风 | 诈术对空 |

## 版权

禁止使用 SNK / 拳皇商业素材与角色名。队伍气槽整队共享，换人不清零。
