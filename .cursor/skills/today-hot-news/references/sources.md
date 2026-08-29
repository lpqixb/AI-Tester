# 数据源清单

本 Skill 使用公开、无需认证的源。Agent 应优先运行 `scripts/fetch_hot_news.py`，再用 `WebFetch` 补充百度热搜。

## RSS 源（由脚本抓取）

| ID | 板块 | 名称 | URL | 解析说明 |
| --- | --- | --- | --- | --- |
| `google_cn` | domestic | Google 新闻（中文） | `https://news.google.com/rss?hl=zh-CN&gl=CN&ceid=CN:zh-Hans` | 解析 `<item>` 的 `title`、`link`、`pubDate`；媒体名可能在 title 末尾 `- 媒体` |
| `google_us` | international | Google 新闻（英文） | `https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en` | 同上 |
| `hn` | tech | Hacker News | `https://hnrss.org/frontpage` | `title` 为帖子标题；`link` 为原文或 HN 讨论 |
| `ithome` | tech | IT之家 | `https://www.ithome.com/rss/` | 国内科技资讯；feed 较大，脚本只取前 N 条 |

### RSS 解析字段

每个 `<item>` 提取：

- `title`：标题（去除 CDATA 包裹）
- `link`：原文或聚合链接
- `pubDate`：发布时间（RFC 822，可选）
- `source`：若 `<source>` 存在则用之；Google News 可尝试从 title 中 `- 媒体名` 分割

### 已知不可用源

| 源 | 原因 | 替代 |
| --- | --- | --- |
| BBC World RSS | 当前环境返回 HTTP 500 | Google 新闻英文 RSS |

## 网页源（由 Agent WebFetch）

| 板块 | 名称 | URL | 解析说明 |
| --- | --- | --- | --- |
| 国内热搜 | 百度热搜 | `https://top.baidu.com/board?tab=realtime` | WebFetch 转为 markdown 后，提取热搜标题行；忽略纯数字「热搜指数」行和「查看更多」 |

百度热搜页无稳定公开 JSON API，因此不由 Python 脚本解析，而由 Agent 在 WebFetch 结果中人工提取标题列表。

## 降级策略

按顺序尝试：

1. **单源失败**：跳过该源，在输出「数据来源」脚注中标注失败源名称。
2. **多源失败**（有效条目 < 3）：调用 `WebSearch`，查询 `"today top news"` 或 `"今日热点新闻 YYYY-MM-DD"`，补充 3–5 条并注明来自搜索。
3. **网络受限**（脚本全部 timeout / egress 拒绝）：告知用户当前环境网络策略，列出已成功源（若有），建议稍后重试。

## 输出语言

| 板块 | 语言 |
| --- | --- |
| 国内热搜、国内要闻、科技（IT之家） | 中文 |
| 国际要闻 | 英文标题保留原文；可在括号内附简短中文说明（若用户用中文提问） |
| Hacker News | 英文标题保留原文 |

## 请求参数建议

```bash
# 默认：每子源 10 条
python3 .cursor/skills/today-hot-news/scripts/fetch_hot_news.py --limit 10

# 只要国内 + 国际
python3 .cursor/skills/today-hot-news/scripts/fetch_hot_news.py --sections domestic,international

# 快速预览
python3 .cursor/skills/today-hot-news/scripts/fetch_hot_news.py --limit 5
```

脚本 stdout 为 JSON，结构：

```json
{
  "fetchedAt": "2026-08-29T13:00:00+08:00",
  "sections": {
    "domestic": { "items": [...], "source": "google_cn" },
    "international": { "items": [...], "source": "google_us" },
    "tech": { "items": [...], "sources": ["hn", "ithome"] }
  },
  "errors": []
}
```

每条 `item`：`{ "title", "link", "source", "pubDate" }`（字段可能为空字符串）。
