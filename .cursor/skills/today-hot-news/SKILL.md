---
name: today-hot-news
description: "Fetch and summarize today's trending news from domestic and international sources (Baidu hot search, Google News, Hacker News, IT之家). Use when the user asks for today's hot news, headlines, trending topics, 热点新闻, 今日新闻, 热搜, or invokes /today-hot-news."
---

# 今日热点新闻

汇总今天国内热搜、国内要闻、国际要闻与科技热点。无需 API Key，使用公开 RSS 与网页源。

详细数据源与降级策略见 [references/sources.md](references/sources.md)。

## 何时使用

| 用户意图 | 动作 |
| --- | --- |
| 今天热点 / 今日新闻 / 热搜 / headlines | 执行本 Skill 完整流程 |
| 只看某一板块（如「国际新闻」） | 运行脚本时加 `--sections domestic,international,tech` 过滤 |
| 追问某条新闻详情 | 对原文链接使用 `WebFetch`，不编造内容 |

## 执行流程

1. **确定时间**：默认 `Asia/Shanghai` 时区，输出标题标注「截至 YYYY-MM-DD HH:mm」。
2. **抓取 RSS 数据**：运行脚本获取结构化 JSON。

   ```bash
   python3 .cursor/skills/today-hot-news/scripts/fetch_hot_news.py --limit 10
   ```

   可选参数：
   - `--limit N`：每个子源最多 N 条（默认 10）
   - `--sections domestic,international,tech`：只抓取指定板块

3. **补充国内热搜**：对百度热搜页调用 `WebFetch`：

   ```
   https://top.baidu.com/board?tab=realtime
   ```

   从返回的 markdown 文本中提取 Top 10 标题。跳过「热搜指数」「查看更多」等噪声行；标题通常出现在「热搜指数」数字块之间。

4. **合并与去重**：同一标题（忽略空格与标点）只保留一条，优先保留有 `pubDate` 的 RSS 条目。

5. **翻译英文标题**（必须执行）：以下板块的英文标题须翻译为中文，同时**保留英文原文与 `link` 链接**。

   | 板块 | 典型英文来源 | 说明 |
   | --- | --- | --- |
   | `international` | Google 新闻（英文 RSS） | 通常全部为英文 |
   | `tech` | Hacker News | 英文标题须翻译；IT之家等中文来源跳过 |

   - 判断：标题主体为英文（拉丁字母为主）时需翻译；已是中文则跳过。
   - 将翻译结果分别写入：
     - `/tmp/intl_translations.json`（国际要闻）
     - `/tmp/tech_translations.json`（科技热点中的 Hacker News 等英文条目）
   - JSON 格式任选其一：
     - 与对应板块 `items` **顺序一致**的数组（中文条目可填空字符串 `""` 跳过）
     - 或以英文原标题为键的对象：`{"English title": "中文标题", ...}`（**推荐**用于 `tech` 混合中英文）
   - 翻译要求：准确、简洁，符合新闻标题风格；不得编造或改动原文含义。
   - 回复用户时，已翻译条目须展示「中文标题 + 原文 + 链接」。

6. **保存 Markdown 文件**（必须执行）：将汇总结果写入 `hot-news/` 目录，文件名格式为 **`YYYYMMDDHHmmss.md`**（年月日时分秒，Asia/Shanghai 时区，无分隔符）。

   ```bash
   # 1) 抓取 RSS 并写入临时 JSON
   python3 .cursor/skills/today-hot-news/scripts/fetch_hot_news.py --limit 10 > /tmp/hot_news.json

   # 2) 将百度热搜标题写入 JSON 数组（示例）
   # echo '["标题1","标题2"]' > /tmp/baidu_titles.json

   # 3) 将英文标题中文翻译写入 JSON（示例）
   # echo '["中文标题1","中文标题2"]' > /tmp/intl_translations.json
   # echo '{"Hacker News title": "中文标题"}' > /tmp/tech_translations.json

   # 4) 渲染并保存为 hot-news/20260829135300.md
   python3 .cursor/skills/today-hot-news/scripts/save_markdown.py \
     --input /tmp/hot_news.json \
     --baidu /tmp/baidu_titles.json \
     --intl-translations /tmp/intl_translations.json \
     --tech-translations /tmp/tech_translations.json \
     --output-dir hot-news
   ```

   脚本 stdout 返回 `savedPath` 与 `filename`；**必须在回复中告知用户保存路径**。

   若无百度热搜数据，省略 `--baidu`；对应板块无英文标题时，省略相应 `--*-translations` 参数。

7. **回复用户**：简要展示各板块 Top 3。国际要闻与科技热点（Hacker News）的英文条目须展示中文标题，并附英文原文与来源链接；附完整文件的保存路径（如 `hot-news/20260829135300.md`）。

8. **降级**：若脚本 `errors` 非空或有效条目少于 3 条，使用 `WebSearch` 补充（例如 `"today top news"` 或 `"今日热点新闻"`），仍须保存 Markdown 并在文件末尾注明哪些源失败。补充的英文新闻同样须中英双语保留原文与链接。

## 板块与脚本映射

| 输出板块 | 脚本 section | 来源 |
| --- | --- | --- |
| 国内要闻 | `domestic` | Google 新闻（中文 RSS） |
| 国际要闻 | `international` | Google 新闻（英文 RSS） |
| 科技热点 | `tech` | Hacker News + IT之家 RSS |
| 国内热搜 | （WebFetch） | 百度热搜页 |

## 深入阅读

用户追问某条新闻时：

1. 优先使用 JSON 中该条的 `link` 字段。
2. 调用 `WebFetch` 抓取原文，提取 2–3 句摘要。
3. 若链接不可用，说明无法获取详情，不要臆测。

## 英文标题翻译

适用于 `international` 与 `tech`（Hacker News 等英文来源）板块。

| 字段 | 说明 |
| --- | --- |
| `title` | RSS 原标题（英文），保存为「原文」 |
| `titleZh` | 中文翻译（由 Agent 生成，经 `--intl-translations` / `--tech-translations` 注入） |
| `link` | 原文链接，必须保留 |

## Markdown 文件格式

保存内容与以下模板一致（由 `save_markdown.py` 自动生成）：

```markdown
# 今日热点新闻（YYYY-MM-DD）

> 抓取时间：YYYY-MM-DD HH:mm (Asia/Shanghai)

## 国内热搜（百度）
1. 标题

## 国内要闻
1. 标题 — [来源](链接)

## 国际要闻
1. 中文标题 — [来源](链接)
   > 原文：English title

## 科技热点
1. 中文标题 — [Hacker News](链接)
   > 原文：English title
2. 中文标题 — [IT之家](链接)

---
数据来源：... | 保存时间：...
以上内容来自公开信息汇总，仅供参考。
```

默认保存目录：`hot-news/`（仓库根目录下）。

## 边界

- 只汇总公开信息，不对新闻真实性做断言。
- 不写入或请求 API Key。
- 每次执行必须生成并保存一个 `{YYYYMMDDHHmmss}.md` 文件。
- 知乎/微博热榜不在默认源内（JS/反爬不稳定）；用户明确要求时可尝试 `WebSearch` 补充。
