# Nexus

**Local-first AI intelligence hub** — 采集、理解、沉淀，把公开信息流压缩成按价值密度排序的个人情报库。

Nexus 是 Flutter 移动端应用（Android 优先），本地优先：采集内容、原始正文、AI 结果全部保存在手机 SQLite 中，只有在你配置 DeepSeek API Key 后才会把正文发送给模型做结构化分析。

---

## 已实现（v0.3）

### 数据实验室（v0.3）

- **政府/权威数据**：世界银行 API（GDP/CPI/人口/失业/研发/债务等，按国家+年份）；国家统计局、财政部、海关总署、央行、人社部、教育部、科技部、IMF/OECD/Eurostat/FRED/UN Data/Data.gov 入口
- **省份统计年鉴**：31 个省级统计局 + 国家统计局/中国统计年鉴，内置浏览器可直接打开；点「抓表格」由 WebView 注入 JS 抓取页面表格
- **通用导入**：网页 HTML 表格、CSV、JSON、XLSX；自动识别表格、表头、列类型、年份列
- **分析**：描述统计（均值/中位数/方差/标准差/CV/分位/偏度/峰度）、趋势（累计变化/CAGR/同比/斜率/R²/倍增时间）、关系（Pearson/协方差/OLS/弹性）、数字经济理论（摩尔、梅特卡夫、数字经济占比、索洛 TFP、Cobb-Douglas、HHI、基尼）
- **公式本地化**：所有公式由 Dart 实现并单测；AI 只能从固定指标库里选指标、解释本地算出的数值，禁止生成公式或数字
- **导出**：Excel（.xlsx）、PDF（内置中文字体）、CSV，通过系统分享保存
- 数据集、指标结果、AI 解读保存在本地 SQLite，永久保留

### 精选来源库 + 关键词采集

- 内置 **60 个** 精选来源，覆盖 AI / 编程 / 商业 / 产品设计 / 科学 / 中文资讯 / 国际新闻 / 社区 / 关键词搜索
- 按分类筛选、搜索、图标展示、多选勾选；内置「AI 日报 / 开发者 / 中文科技 / 国际视野」快捷组合
- 关键词采集：
  - Google News（中/英）、HN Algolia、arXiv、Stack Overflow、GitHub 仓库、Reddit、DEV 标签
  - 普通 RSS / 网页也可填关键词，只保留标题或正文命中的内容
- 批量采集进度、逐站失败原因、来源配置（关键词 + 实际抓取 URL）持久化
- **数据永久保留，不自动删除**：信息流 / 知识库最多展示 500 条，全部原始记录与 AI 结果仍在本机

### 采集引擎（Dart，手机本地）

- 任意公开网页 URL（静态 HTML）
- RSS / Atom 订阅源
- 公开 JSON API（自动识别 `items / data / articles / posts / results` 等列表字段）
- Sitemap（含 sitemapindex，移动端默认最多抓 8 个页面）
- 自动识别来源类型，也可手动指定
- 统一 `CrawlEngine` 接口 + Connector 分层，后续可接云端 Python 引擎
- HTTP Fetcher：UA、超时、重试、按 host 限速、短时缓存、清晰失败原因
- URL 规范化、内容 hash 去重、原始内容与清洗内容分离
- WebView 原文阅读（处理需要 JS 渲染的页面展示）

### AI 处理（DeepSeek）

- 摘要 / 分类 / 标签 / 关键实体 / 关键要点 / 价值评分（0-100）
- 价值密度排序与“AI 情报简报”
- 知识库 AI 问答（本地 FTS5 检索 + 引用回答）
- 结构化 JSON 输出 + 校验 + 失败重试
- 长文截断、只分析新内容、内容 hash 未变不重复调用
- 记录模型、Prompt 版本、输入/输出 Token 用量

### 本地存储

Drift + SQLite + FTS5（trigram，中文可搜）：

`Sources / CrawlRuns / RawDocuments / Documents / AiAnalysis / Tags / DocumentTags / Collections / CollectionDocuments / Bookmarks / SearchHistory / SyncOutbox / SettingsEntries`

- 原始内容、清洗内容、AI 结果分开保存
- 索引、外键、级联删除、事务、数据库版本管理
- 全文搜索（FTS5 不可用时自动回退 LIKE）

### 界面

深色未来感 UI：网格背景、霓虹光晕、玻璃卡片、价值环、按价值密度排序的信息流、AI 简报、知识分布、来源实验室、系统设置。

---

## 快速开始

### 1. 配置 DeepSeek

设置 → DeepSeek → 填入 API Key → 保存。Key 存在系统安全存储（EncryptedSharedPreferences），不会写进代码或上传。

默认模型 `deepseek-chat`，可切换 `deepseek-reasoner`。DeepSeek 官方 API 在中国大陆可直连。

### 2. 添加来源

发现 → 粘贴 URL → 选择类型（或保持“自动识别”）→ 开始采集。

推荐起点：

- Hacker News：`https://hnrss.org/frontpage`
- 阮一峰周刊：`https://www.ruanyifeng.com/blog/atom.xml`
- 少数派：`https://sspai.com/feed`
- V2EX：`https://www.v2ex.com/index.xml`

### 3. 阅读与检索

信息流按价值密度排序，点卡片查看 AI 结构化字段与原文；知识库支持全文搜索和基于本地语料的 AI 问答。

---

## 构建 APK

仓库使用 GitHub Actions 云端构建（手机端无需 JDK/Android SDK）：

1. push 到 `main` 触发 `.github/workflows/build.yml`
2. 构建 `flutter build apk --release`
3. 自动发布到 Release：`Nexus.apk`（tag `v0.3.1`）

本地构建：

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release
```

Android 工程由 CI 用 `flutter create --platforms=android .` 生成，再由 `tool/patch_android.py` 注入网络权限、应用名与 minSdk 23。

---

## 关于 RSS / Sitemap / 外网

- **RSS / Atom**：网站提供的标准订阅格式（XML），一次拿到最新文章列表与正文，最稳定，优先用。
- **Sitemap**：网站给爬虫的网址清单（`sitemap.xml`），只有 URL 不含正文，需要逐页再抓；适合中小站点，移动端较慢，默认限制 8 页。
- **外网**：Android 应用走系统网络。手机开梯子（VPN）后，App 会自动走 VPN，不需要额外开关。设置里的 HTTP 代理仅用于“按应用分流”或局域网代理场景。
- 遇到 Cloudflare / 登录墙 / 403，手机端不会强行绕过，会显示具体失败原因。这是移动端采集的边界，云端 Playwright 引擎才会处理复杂动态站点。

---

## 目录结构

```
lib/
  ai/            DeepSeek 客户端、分析编排
  catalog/       60 个精选来源 + 政府数据源 + 31 省年鉴
  analysis/      统计/计量指标库（固定公式）
  export/        Excel / PDF / CSV 导出
  core/          主题、组件、模型、设置、工具
  crawl/         HTTP、提取器、统一引擎
  data/          Drift 数据库、Repository、表格解析、世界银行
  features/      feed / discover / catalog / data lab / library / settings / document / reader
  state/         Riverpod providers 与控制器
```

设计原则：UI 不直接访问 HTTP / 数据库；AI 只输出结构化结果，写入由 Repository 完成；采集引擎与数据契约保持可替换。

---

## 边界与路线图

- 手机端不承诺抓取所有网站：动态渲染、登录、强风控站点会失败并给出原因。
- 定时后台刷新 v0.2 再上：Workmanager 0.9 系列插件在 Flutter 3.35 下互相不兼容（已在本机 CI 复现），v0.1 先移除；信息流下拉刷新、来源「刷新全部」可用。
- 云端 Python 引擎（Scrapy / Playwright / Trafilatura / FastAPI）为下一阶段，共用同一份数据契约。
- 计划：多设备同步（SyncOutbox 已预留）、集合/标签管理、更多插件、i18n。

## 签名与升级

v0.3.1 起使用仓库内的固定签名（`tool/nexus-release.p12`，个人 sideload 用途），后续版本可直接覆盖升级并保留本地数据。
v0.1/v0.2 使用临时调试签名，无法覆盖安装；首次装 v0.3.1 需要卸载旧版（旧数据会清空）。

## 隐私

无账号、无自建服务器、无埋点。数据默认只在本机。AI 请求仅发送当前文章的标题与正文到 DeepSeek API。

## License

MIT
