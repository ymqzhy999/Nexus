import 'package:flutter/material.dart';

import '../core/models.dart';

enum CatalogCategory { ai, code, business, product, science, chinese, world, community, search }

extension CatalogCategoryX on CatalogCategory {
  String get label => switch (this) {
        CatalogCategory.ai => 'AI 与科技',
        CatalogCategory.code => '编程开发',
        CatalogCategory.business => '商业财经',
        CatalogCategory.product => '产品设计',
        CatalogCategory.science => '科学学术',
        CatalogCategory.chinese => '中文资讯',
        CatalogCategory.world => '国际新闻',
        CatalogCategory.community => '社区',
        CatalogCategory.search => '关键词搜索',
      };

  IconData get icon => switch (this) {
        CatalogCategory.ai => Icons.memory,
        CatalogCategory.code => Icons.terminal,
        CatalogCategory.business => Icons.trending_up,
        CatalogCategory.product => Icons.auto_awesome_mosaic,
        CatalogCategory.science => Icons.science_outlined,
        CatalogCategory.chinese => Icons.translate,
        CatalogCategory.world => Icons.public,
        CatalogCategory.community => Icons.forum_outlined,
        CatalogCategory.search => Icons.manage_search,
      };

  Color get color => switch (this) {
        CatalogCategory.ai => const Color(0xFF22D3EE),
        CatalogCategory.code => const Color(0xFFA3E635),
        CatalogCategory.business => const Color(0xFFFBBF24),
        CatalogCategory.product => const Color(0xFFF472B6),
        CatalogCategory.science => const Color(0xFFA78BFA),
        CatalogCategory.chinese => const Color(0xFF60A5FA),
        CatalogCategory.world => const Color(0xFF34D399),
        CatalogCategory.community => const Color(0xFFFB923C),
        CatalogCategory.search => const Color(0xFFE879F9),
      };
}

class CatalogSource {
  final String id;
  final String name;
  final String url;
  final String description;
  final SourceKind kind;
  final CatalogCategory category;
  final String searchTemplate;
  final bool keywordOnly;
  final bool featured;

  const CatalogSource({
    required this.id,
    required this.name,
    required this.url,
    required this.description,
    required this.kind,
    required this.category,
    this.searchTemplate = '',
    this.keywordOnly = false,
    this.featured = false,
  });

  bool get keywordCapable => searchTemplate.isNotEmpty;

  String fetchUrl(String keyword) {
    if (searchTemplate.isEmpty) return url;
    if (keyword.trim().isEmpty) return url;
    return searchTemplate.replaceAll('{q}', Uri.encodeComponent(keyword.trim()));
  }
}

const List<CatalogSource> catalogSources = [
  // ── AI 与科技 ─────────────────────────────────────────────
  CatalogSource(id: 'hn', name: 'Hacker News', url: 'https://hnrss.org/frontpage', description: '全球开发者与技术创业者的每日头条', kind: SourceKind.rss, category: CatalogCategory.ai, featured: true),
  CatalogSource(id: 'tc', name: 'TechCrunch', url: 'https://techcrunch.com/feed/', description: '科技创业、融资与硅谷动态', kind: SourceKind.rss, category: CatalogCategory.ai, featured: true),
  CatalogSource(id: 'verge', name: 'The Verge', url: 'https://www.theverge.com/rss/index.xml', description: '消费科技、产品与数字文化', kind: SourceKind.rss, category: CatalogCategory.ai),
  CatalogSource(id: 'ars', name: 'Ars Technica', url: 'https://feeds.arstechnica.com/arstechnica/index', description: '深度科技新闻与技术分析', kind: SourceKind.rss, category: CatalogCategory.ai),
  CatalogSource(id: 'wired', name: 'WIRED', url: 'https://www.wired.com/feed/rss', description: '科技如何改变商业与生活', kind: SourceKind.rss, category: CatalogCategory.ai),
  CatalogSource(id: 'vb', name: 'VentureBeat', url: 'https://venturebeat.com/feed/', description: '企业级 AI 与科技产业新闻', kind: SourceKind.rss, category: CatalogCategory.ai),
  CatalogSource(id: 'huggingface', name: 'Hugging Face Blog', url: 'https://huggingface.co/blog/feed.xml', description: '开源模型、数据集与 AI 工程实践', kind: SourceKind.rss, category: CatalogCategory.ai, featured: true),
  CatalogSource(id: 'googleai', name: 'Google AI Blog', url: 'https://blog.google/technology/ai/rss/', description: 'Google 官方 AI 研究与产品', kind: SourceKind.rss, category: CatalogCategory.ai),
  CatalogSource(id: 'qbitai', name: '量子位', url: 'https://www.qbitai.com/feed', description: '中文 AI 前沿与产品动态', kind: SourceKind.rss, category: CatalogCategory.ai),

  // ── 编程开发 ─────────────────────────────────────────────
  CatalogSource(id: 'githubblog', name: 'GitHub Blog', url: 'https://github.blog/feed/', description: 'GitHub 官方产品与开源生态', kind: SourceKind.rss, category: CatalogCategory.code, featured: true),
  CatalogSource(id: 'soblog', name: 'Stack Overflow Blog', url: 'https://stackoverflow.blog/feed/', description: '开发者调查、工程文化与技术趋势', kind: SourceKind.rss, category: CatalogCategory.code),
  CatalogSource(id: 'devto', name: 'DEV Community', url: 'https://dev.to/feed', description: '开发者社区的高频实战文章', kind: SourceKind.rss, category: CatalogCategory.code),
  CatalogSource(id: 'lobsters', name: 'Lobsters', url: 'https://lobste.rs/rss', description: '硬核技术社区，质量高于噪音', kind: SourceKind.rss, category: CatalogCategory.code, featured: true),
  CatalogSource(id: 'simon', name: 'Simon Willison', url: 'https://simonwillison.net/atom/everything/', description: 'LLM 工具与工程实践的独立观察', kind: SourceKind.atom, category: CatalogCategory.code, featured: true),
  CatalogSource(id: 'jvns', name: 'Julia Evans', url: 'https://jvns.ca/atom.xml', description: '系统、调试与工程师成长', kind: SourceKind.atom, category: CatalogCategory.code),
  CatalogSource(id: 'css', name: 'CSS-Tricks', url: 'https://css-tricks.com/feed/', description: '前端与 CSS 实战技巧', kind: SourceKind.rss, category: CatalogCategory.code),
  CatalogSource(id: 'ruanyf', name: '阮一峰的网络日志', url: 'https://www.ruanyifeng.com/blog/atom.xml', description: '中文技术圈长期主义博客', kind: SourceKind.atom, category: CatalogCategory.code, featured: true),
  CatalogSource(id: 'v2ex', name: 'V2EX', url: 'https://www.v2ex.com/index.xml', description: '中文开发者社区最新主题', kind: SourceKind.rss, category: CatalogCategory.code),
  CatalogSource(id: 'juejin', name: '掘金', url: 'https://juejin.cn/rss', description: '中文前端、后端与移动开发', kind: SourceKind.rss, category: CatalogCategory.code),
  CatalogSource(id: 'flutter', name: 'Flutter Blog', url: 'https://medium.com/feed/flutter', description: 'Flutter 官方与社区更新', kind: SourceKind.rss, category: CatalogCategory.code),
  CatalogSource(id: 'android', name: 'Android Developers', url: 'https://android-developers.googleblog.com/feeds/posts/default', description: 'Android 平台与工具更新', kind: SourceKind.atom, category: CatalogCategory.code),
  CatalogSource(id: 'rust', name: 'Rust Blog', url: 'https://blog.rust-lang.org/feed.xml', description: 'Rust 语言与生态官方动态', kind: SourceKind.rss, category: CatalogCategory.code),
  CatalogSource(id: 'goblog', name: 'Go Blog', url: 'https://go.dev/blog/feed.atom', description: 'Go 语言官方工程文章', kind: SourceKind.atom, category: CatalogCategory.code),
  CatalogSource(id: 'gh_trending', name: 'GitHub Trending', url: 'https://github.com/trending', description: '当日最热开源项目（网页抓取）', kind: SourceKind.html, category: CatalogCategory.code),

  // ── 商业财经 / 中文 ──────────────────────────────────────
  CatalogSource(id: 'sspai', name: '少数派', url: 'https://sspai.com/feed', description: '数字生活、效率工具与产品', kind: SourceKind.rss, category: CatalogCategory.business, featured: true),
  CatalogSource(id: 'ifanr', name: '爱范儿', url: 'https://www.ifanr.com/feed', description: '消费科技与产品体验', kind: SourceKind.rss, category: CatalogCategory.business),
  CatalogSource(id: 'tmtpost', name: '钛媒体', url: 'https://www.tmtpost.com/rss', description: '科技商业与产业趋势', kind: SourceKind.rss, category: CatalogCategory.business),

  // ── 产品设计 ─────────────────────────────────────────────
  CatalogSource(id: 'nng', name: 'Nielsen Norman Group', url: 'https://www.nngroup.com/feed/rss/', description: 'UX 研究与可用性权威', kind: SourceKind.rss, category: CatalogCategory.product, featured: true),
  CatalogSource(id: 'uxcollective', name: 'UX Collective', url: 'https://uxdesign.cc/feed', description: '产品设计与 UX 实践社区', kind: SourceKind.rss, category: CatalogCategory.product),
  CatalogSource(id: 'producthunt', name: 'Product Hunt', url: 'https://www.producthunt.com/feed', description: '每日新产品与独立开发者', kind: SourceKind.rss, category: CatalogCategory.product),

  // ── 科学学术 ─────────────────────────────────────────────
  CatalogSource(id: 'nature', name: 'Nature', url: 'https://www.nature.com/nature.rss', description: '自然科学顶级期刊最新内容', kind: SourceKind.rss, category: CatalogCategory.science, featured: true),
  CatalogSource(id: 'quanta', name: 'Quanta Magazine', url: 'https://www.quantamagazine.org/feed/', description: '数学、物理与生命科学的深度叙事', kind: SourceKind.rss, category: CatalogCategory.science, featured: true),
  CatalogSource(id: 'mitnews', name: 'MIT News', url: 'https://news.mit.edu/rss/feed', description: 'MIT 科研与创新新闻', kind: SourceKind.rss, category: CatalogCategory.science),
  CatalogSource(id: 'arxiv', name: 'arXiv cs.AI', url: 'https://rss.arxiv.org/rss/cs.AI', description: 'AI 领域最新预印本', kind: SourceKind.rss, category: CatalogCategory.science, featured: true),

  // ── 国际新闻 ─────────────────────────────────────────────
  CatalogSource(id: 'bbc', name: 'BBC World', url: 'https://feeds.bbci.co.uk/news/world/rss.xml', description: '全球新闻与地缘动态', kind: SourceKind.rss, category: CatalogCategory.world, featured: true),
  CatalogSource(id: 'guardian', name: 'The Guardian', url: 'https://www.theguardian.com/world/rss', description: '国际新闻与长篇调查', kind: SourceKind.rss, category: CatalogCategory.world),
  CatalogSource(id: 'npr', name: 'NPR', url: 'https://feeds.npr.org/1001/rss.xml', description: '美国公共广播新闻', kind: SourceKind.rss, category: CatalogCategory.world),
  CatalogSource(id: 'aljazeera', name: 'Al Jazeera', url: 'https://www.aljazeera.com/xml/rss/all.xml', description: '中东与全球新闻视角', kind: SourceKind.rss, category: CatalogCategory.world),
  CatalogSource(id: 'nyt', name: 'NYT World', url: 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml', description: '纽约时报国际新闻', kind: SourceKind.rss, category: CatalogCategory.world),

  // ── 社区 ─────────────────────────────────────────────────
  CatalogSource(id: 'reddit_tech', name: 'r/technology', url: 'https://www.reddit.com/r/technology/.rss', description: 'Reddit 科技版块热帖', kind: SourceKind.rss, category: CatalogCategory.community),
  CatalogSource(id: 'reddit_ml', name: 'r/MachineLearning', url: 'https://www.reddit.com/r/MachineLearning/.rss', description: '机器学习研究与工程讨论', kind: SourceKind.rss, category: CatalogCategory.community, featured: true),
  CatalogSource(id: 'reddit_prog', name: 'r/programming', url: 'https://www.reddit.com/r/programming/.rss', description: '编程社区高赞讨论', kind: SourceKind.rss, category: CatalogCategory.community),
  CatalogSource(id: 'hnask', name: 'Hacker News Ask', url: 'https://hnrss.org/ask', description: 'HN 上的提问与经验讨论', kind: SourceKind.rss, category: CatalogCategory.community),

  // ── 关键词搜索（需要关键词） ─────────────────────────────
  CatalogSource(id: 'gnews_cn', name: 'Google 新闻（中文）', url: 'https://news.google.com/rss', description: '按关键词搜索中文新闻聚合', kind: SourceKind.rss, category: CatalogCategory.search, keywordOnly: true, searchTemplate: 'https://news.google.com/rss/search?q={q}&hl=zh-CN&gl=CN&ceid=CN:zh-Hans', featured: true),
  CatalogSource(id: 'gnews_en', name: 'Google News（英文）', url: 'https://news.google.com/rss', description: '按关键词搜索全球英文新闻', kind: SourceKind.rss, category: CatalogCategory.search, keywordOnly: true, searchTemplate: 'https://news.google.com/rss/search?q={q}&hl=en-US&gl=US&ceid=US:en'),
  CatalogSource(id: 'hnalgolia', name: 'HN Algolia 搜索', url: 'https://hn.algolia.com/api/v1/search', description: '搜索 Hacker News 全站讨论', kind: SourceKind.jsonApi, category: CatalogCategory.search, keywordOnly: true, searchTemplate: 'https://hn.algolia.com/api/v1/search?query={q}&tags=story&hitsPerPage=25', featured: true),
  CatalogSource(id: 'arxiv_search', name: 'arXiv 论文搜索', url: 'https://export.arxiv.org/api/query', description: '按关键词检索 arXiv 预印本', kind: SourceKind.atom, category: CatalogCategory.search, keywordOnly: true, searchTemplate: 'https://export.arxiv.org/api/query?search_query=all:{q}&max_results=20&sortBy=submittedDate&sortOrder=descending', featured: true),
  CatalogSource(id: 'stackexchange', name: 'Stack Overflow 搜索', url: 'https://api.stackexchange.com/2.3/search/advanced', description: '搜索技术问答与解决方案', kind: SourceKind.jsonApi, category: CatalogCategory.search, keywordOnly: true, searchTemplate: 'https://api.stackexchange.com/2.3/search/advanced?order=desc&sort=relevance&q={q}&site=stackoverflow&pagesize=20&filter=withbody'),
  CatalogSource(id: 'github_search', name: 'GitHub 仓库搜索', url: 'https://api.github.com/search/repositories', description: '按关键词发现开源项目', kind: SourceKind.jsonApi, category: CatalogCategory.search, keywordOnly: true, searchTemplate: 'https://api.github.com/search/repositories?q={q}&sort=stars&order=desc&per_page=20'),
  CatalogSource(id: 'reddit_search', name: 'Reddit 搜索', url: 'https://www.reddit.com/search.json', description: '搜索 Reddit 全站讨论', kind: SourceKind.jsonApi, category: CatalogCategory.search, keywordOnly: true, searchTemplate: 'https://www.reddit.com/search.json?q={q}&sort=new&limit=25'),
  CatalogSource(id: 'devtag', name: 'DEV 标签', url: 'https://dev.to/api/articles', description: '按技术标签发现 DEV 文章', kind: SourceKind.jsonApi, category: CatalogCategory.search, keywordOnly: true, searchTemplate: 'https://dev.to/api/articles?per_page=20&tag={q}'),
  CatalogSource(id: 'hnnew', name: 'Hacker News Newest', url: 'https://hnrss.org/newest', description: 'HN 最新提交，信息更早一步', kind: SourceKind.rss, category: CatalogCategory.ai),
  CatalogSource(id: 'hnshow', name: 'Hacker News Show', url: 'https://hnrss.org/show', description: 'Show HN：独立开发者新作品', kind: SourceKind.rss, category: CatalogCategory.ai),
  CatalogSource(id: 'register', name: 'The Register', url: 'https://www.theregister.com/headlines.atom', description: '带刺的英国科技新闻与评论', kind: SourceKind.atom, category: CatalogCategory.ai),
  CatalogSource(id: 'engadget', name: 'Engadget', url: 'https://www.engadget.com/rss.xml', description: '消费电子与科技产品新闻', kind: SourceKind.rss, category: CatalogCategory.ai),
  CatalogSource(id: 'cnet', name: 'CNET', url: 'https://www.cnet.com/rss/news/', description: '科技产品评测与购买指南', kind: SourceKind.atom, category: CatalogCategory.ai),
  CatalogSource(id: 'decoder', name: 'The Decoder', url: 'https://the-decoder.com/feed/', description: 'AI 产业与模型进展的独立报道', kind: SourceKind.rss, category: CatalogCategory.ai'),
  CatalogSource(id: 'daringfireball', name: 'Daring Fireball', url: 'https://daringfireball.net/feeds/main', description: 'John Gruber 的苹果与产品观察', kind: SourceKind.rss, category: CatalogCategory.ai),
  CatalogSource(id: 'cloudflare', name: 'Cloudflare Blog', url: 'https://blog.cloudflare.com/rss/', description: '网络、安全与边缘计算工程', kind: SourceKind.rss, category: CatalogCategory.code),
  CatalogSource(id: 'aws', name: 'AWS Blog', url: 'https://aws.amazon.com/blogs/aws/feed/', description: 'AWS 新产品与架构实践', kind: SourceKind.rss, category: CatalogCategory.code),
];
