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

5. **格式化输出**（使用中文，固定模板）：

   ```markdown
   # 今日热点新闻（YYYY-MM-DD）

   ## 国内热搜（百度）
   1. 标题

   ## 国内要闻
   1. 标题 — [来源](链接)

   ## 国际要闻
   1. Title — [Source](link)

   ## 科技热点
   1. 标题 — [来源](链接)

   ---
   数据来源：百度热搜、Google 新闻、Hacker News、IT之家 | 抓取时间：YYYY-MM-DD HH:mm (Asia/Shanghai)
   以上内容来自公开信息汇总，仅供参考。
   ```

6. **降级**：若脚本 `errors` 非空或有效条目少于 3 条，使用 `WebSearch` 补充（例如 `"today top news"` 或 `"今日热点新闻"`），并在输出末尾注明哪些源失败。

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

## 边界

- 只汇总公开信息，不对新闻真实性做断言。
- 不写入或请求 API Key。
- 知乎/微博热榜不在默认源内（JS/反爬不稳定）；用户明确要求时可尝试 `WebSearch` 补充。
