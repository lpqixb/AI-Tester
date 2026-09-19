---
name: short-drama
description: "Expand a brief plot idea into a continuous short drama with storyboard and dual video/image shot prompts. Use when the user asks to generate a short drama, 短剧, 分镜, 故事板, 视频提示词, storyboard, shot list, or invokes /short-drama."
---

# 短剧生成

用户只需给出简短剧情想法。本 Skill 负责发挥想象、丰富剧情、保证场次与分镜连续性，并输出 **故事板 + 静帧提示词 + 视频分镜提示词** 的 Markdown 文件。

模板与规范见：

- [references/storyboard-template.md](references/storyboard-template.md) — 输出文档结构
- [references/prompt-guide.md](references/prompt-guide.md) — 静帧 / 视频提示词写法
- [references/continuity-rules.md](references/continuity-rules.md) — 连续性与衔接规则
- [references/scale-guide.md](references/scale-guide.md) — 体量自动判断

## 何时使用

| 用户意图 | 动作 |
| --- | --- |
| 写短剧 / 生成分镜 / 故事板 / 视频提示词 | 执行完整流程 |
| 在已有短剧上续写、改某一镜 | 读取已有 Markdown，只改相关部分后另存新文件 |
| 仅改提示词风格（如更偏可灵 / Midjourney） | 按 [prompt-guide.md](references/prompt-guide.md) 调整后重存 |

## 执行流程

1. **读取用户一句话剧情**  
   提取：类型倾向、核心冲突、主角关系、时代/空间、情绪基调。信息不足时**不要反复追问**；按合理默认补全，并在文档「创作说明」中列出假设。

2. **自动判断体量**（见 [scale-guide.md](references/scale-guide.md)）  
   - 单场微短剧：约 8–12 镜  
   - 标准单集：约 12–18 镜  
   - 迷你剧：3–5 集，每集 6–10 镜  
   在文档开头写明判定结果与理由。

3. **丰富剧情（发挥想象）**  
   在不违背用户核心设定的前提下，补全：  
   - 标题与一句话卖点  
   - 人物小传（外貌锚点、性格、欲望、秘密）  
   - 完整故事梗概（起承转合）  
   - 若为迷你剧：分集大纲，每集有明确钩子与收束  

4. **编写故事板**  
   按场次 → 分镜展开。每一镜必须包含：镜号、时长建议、景别/运镜、画面描述、对白/旁白、情绪、**与上一镜的衔接说明**。  
   遵守 [continuity-rules.md](references/continuity-rules.md)。

5. **为每一镜生成双提示词**  
   - **静帧提示词**（中英各一段或中英混合一段，适合 Midjourney / Flux）  
   - **视频提示词**（适合 Kling / Runway / 可灵等，含动作、镜头运动、时长感）  
   同一角色跨镜使用稳定的视觉锚点（发型、服装色、标志物）。规范见 [prompt-guide.md](references/prompt-guide.md)。

6. **自检连续性**（写入前快速检查）  
   - 人物外观、道具、时间、天气是否前后一致  
   - 上一镜结尾动作/视线是否接到下一镜开头  
   - 情绪曲线是否有断裂硬切（除非刻意反转）  

7. **保存 Markdown**（必须执行）  

   ```bash
   # 将完整 Markdown 写入临时文件后保存为 short-drama/YYYYMMDDHHmmss.md
   python3 .cursor/skills/short-drama/scripts/save_drama_markdown.py \
     --input /tmp/short_drama.md \
     --output-dir short-drama
   ```

   也可直接把内容经 stdin 传入：

   ```bash
   python3 .cursor/skills/short-drama/scripts/save_drama_markdown.py \
     --output-dir short-drama < /tmp/short_drama.md
   ```

   脚本返回 `savedPath` 与 `filename`；**必须在回复中告知用户保存路径**。

8. **回复用户**  
   简要说明：标题、体量判定、核心卖点、分镜数量；附文件路径。不要在聊天里贴全文（文件已保存）。

## 输出文件命名

| 项 | 约定 |
| --- | --- |
| 目录 | 仓库根目录 `short-drama/` |
| 文件名 | `YYYYMMDDHHmmss.md`（Asia/Shanghai，无分隔符） |
| 内容结构 | 严格遵循 [storyboard-template.md](references/storyboard-template.md) |

## 边界

- 不生成违法、色情剥削、针对未成年人的内容。  
- 用户一句话优先；发挥想象不得推翻其明确设定（人名、结局、时代等）。  
- 每次执行必须保存一个新的 `{YYYYMMDDHHmmss}.md`；续写/大改也另存新文件，勿覆盖旧稿。  
- 提示词面向文生图/文生视频工具，不保证某一厂商 API 可直接调用。
