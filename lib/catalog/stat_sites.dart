class StatSite {
  final String id;
  final String name;
  final String url;
  final String category;
  final String description;
  final List<String> tags;

  const StatSite({
    required this.id,
    required this.name,
    required this.url,
    required this.category,
    required this.description,
    this.tags = const [],
  });
}

const List<StatSite> statSites = [
  // 国家统计
  StatSite(id: 'nbs_data', name: '国家数据', url: 'https://data.stats.gov.cn/', category: '国家统计', description: '国家统计局年度/月度/分省数据查询', tags: ['全国', 'gdp', 'cpi', '人口', '统计']),
  StatSite(id: 'nbs_yearbook', name: '中国统计年鉴', url: 'https://www.stats.gov.cn/sj/ndsj/', category: '国家统计', description: '中国统计年鉴历年入口', tags: ['全国', '年鉴', '统计']),
  StatSite(id: 'nbs', name: '国家统计局', url: 'https://www.stats.gov.cn/', category: '国家统计', description: '统计公报、年鉴、数据发布', tags: ['全国', '统计', '公报']),
  StatSite(id: 'mof', name: '财政部', url: 'https://www.mof.gov.cn/gkml/caizhengshuju/', category: '部委数据', description: '财政收支、债务与转移支付', tags: ['财政', '税收', '债务']),
  StatSite(id: 'customs', name: '海关总署', url: 'http://www.customs.gov.cn/', category: '部委数据', description: '进出口、贸易与关税统计', tags: ['进出口', '贸易', '海关']),
  StatSite(id: 'pbc', name: '中国人民银行', url: 'http://www.pbc.gov.cn/diaochatongjisi/116219/index.html', category: '部委数据', description: '金融、信贷、社融与利率', tags: ['金融', '货币', '信贷']),
  StatSite(id: 'mohrss', name: '人社部', url: 'https://www.mohrss.gov.cn/SYrlzyhshbzb/zwgk/szrs/', category: '部委数据', description: '就业、工资、社保统计', tags: ['就业', '工资', '社保']),
  StatSite(id: 'moe', name: '教育部', url: 'http://www.moe.gov.cn/jyb_sjzl/', category: '部委数据', description: '教育统计与经费', tags: ['教育', '高校', '经费']),
  StatSite(id: 'most', name: '科技部', url: 'https://www.most.gov.cn/kjbgz/', category: '部委数据', description: '科技统计与研发投入', tags: ['科技', '研发', '专利']),

  // 省份年鉴直达（已验证可访问的年鉴栏目）
  StatSite(id: 'tianjin_yb', name: '天津统计年鉴', url: 'https://stats.tj.gov.cn/tjsj_52032/tjnj/', category: '省级年鉴', description: '天津统计年鉴', tags: ['天津']),
  StatSite(id: 'shanxi_yb', name: '山西统计年鉴', url: 'https://tjj.shanxi.gov.cn/tjsj/tjnj/', category: '省级年鉴', description: '山西统计年鉴', tags: ['山西']),
  StatSite(id: 'neimeng_yb', name: '内蒙古统计年鉴', url: 'https://tj.nmg.gov.cn/tjyw/tjnj/', category: '省级年鉴', description: '内蒙古统计年鉴', tags: ['内蒙古']),
  StatSite(id: 'liaoning_yb', name: '辽宁统计年鉴', url: 'https://tjj.ln.gov.cn/tjsj/tjnj/', category: '省级年鉴', description: '辽宁统计年鉴', tags: ['辽宁']),
  StatSite(id: 'jilin_yb', name: '吉林统计年鉴', url: 'https://tjj.jl.gov.cn/tjsj/tjnj/', category: '省级年鉴', description: '吉林统计年鉴', tags: ['吉林']),
  StatSite(id: 'shanghai_yb', name: '上海统计年鉴', url: 'https://tjj.sh.gov.cn/tjnj/', category: '省级年鉴', description: '上海统计年鉴', tags: ['上海']),
  StatSite(id: 'zhejiang_yb', name: '浙江统计年鉴', url: 'https://tjj.zj.gov.cn/col/col1525563/index.html', category: '省级年鉴', description: '浙江统计年鉴', tags: ['浙江']),
  StatSite(id: 'anhui_yb', name: '安徽统计年鉴', url: 'https://tjj.ah.gov.cn/ssah/qwfbjd/tjnj/index.html', category: '省级年鉴', description: '安徽统计年鉴', tags: ['安徽']),
  StatSite(id: 'jiangxi_yb', name: '江西统计年鉴', url: 'https://tjj.jiangxi.gov.cn/col/col38595/index.html', category: '省级年鉴', description: '江西统计年鉴', tags: ['江西']),
  StatSite(id: 'henan_yb', name: '河南统计年鉴', url: 'https://tjj.henan.gov.cn/tjfw/tjcbw/tjnj/', category: '省级年鉴', description: '河南统计年鉴', tags: ['河南']),
  StatSite(id: 'hunan_yb', name: '湖南统计年鉴', url: 'https://tjj.hunan.gov.cn/hntj/tjsj/tjnj/', category: '省级年鉴', description: '湖南统计年鉴', tags: ['湖南']),
  StatSite(id: 'guangdong_yb', name: '广东统计年鉴', url: 'https://stats.gd.gov.cn/gdtjnj/', category: '省级年鉴', description: '广东统计年鉴', tags: ['广东']),
  StatSite(id: 'guangxi_yb', name: '广西统计年鉴', url: 'http://tjj.gxzf.gov.cn/tjsj/tjnj/', category: '省级年鉴', description: '广西统计年鉴', tags: ['广西']),
  StatSite(id: 'hainan_yb', name: '海南统计年鉴', url: 'https://stats.hainan.gov.cn/tjj/tjsj/tjnj/', category: '省级年鉴', description: '海南统计年鉴', tags: ['海南']),
  StatSite(id: 'chongqing_yb', name: '重庆统计年鉴', url: 'https://tjj.cq.gov.cn/zwgk_233/tjnj/', category: '省级年鉴', description: '重庆统计年鉴', tags: ['重庆']),

  // 省份统计局首页（年鉴入口）
  StatSite(id: 'beijing', name: '北京统计局', url: 'https://tjj.beijing.gov.cn/', category: '省级统计', description: '北京统计年鉴入口', tags: ['北京']),
  StatSite(id: 'hebei', name: '河北统计局', url: 'https://tjj.hebei.gov.cn/', category: '省级统计', description: '河北统计年鉴入口', tags: ['河北']),
  StatSite(id: 'heilongjiang', name: '黑龙江统计局', url: 'https://tjj.hlj.gov.cn/', category: '省级统计', description: '黑龙江统计年鉴入口', tags: ['黑龙江']),
  StatSite(id: 'jiangsu', name: '江苏统计局', url: 'https://tj.jiangsu.gov.cn/', category: '省级统计', description: '江苏统计年鉴入口', tags: ['江苏']),
  StatSite(id: 'fujian', name: '福建统计局', url: 'https://tjj.fujian.gov.cn/', category: '省级统计', description: '福建统计年鉴入口', tags: ['福建']),
  StatSite(id: 'shandong', name: '山东统计局', url: 'https://tjj.shandong.gov.cn/', category: '省级统计', description: '山东统计年鉴入口', tags: ['山东']),
  StatSite(id: 'hubei', name: '湖北统计局', url: 'https://tjj.hubei.gov.cn/', category: '省级统计', description: '湖北统计年鉴入口', tags: ['湖北']),
  StatSite(id: 'sichuan', name: '四川统计局', url: 'https://tjj.sc.gov.cn/', category: '省级统计', description: '四川统计年鉴入口', tags: ['四川']),
  StatSite(id: 'guizhou', name: '贵州统计局', url: 'https://stjj.guizhou.gov.cn/', category: '省级统计', description: '贵州统计年鉴入口', tags: ['贵州']),
  StatSite(id: 'yunnan', name: '云南统计局', url: 'https://stats.yn.gov.cn/', category: '省级统计', description: '云南统计年鉴入口', tags: ['云南']),
  StatSite(id: 'xizang', name: '西藏统计局', url: 'http://tjj.xizang.gov.cn/', category: '省级统计', description: '西藏统计年鉴入口', tags: ['西藏']),
  StatSite(id: 'shaanxi', name: '陕西统计局', url: 'https://tjj.shaanxi.gov.cn/', category: '省级统计', description: '陕西统计年鉴入口', tags: ['陕西']),
  StatSite(id: 'gansu', name: '甘肃统计局', url: 'https://tjj.gansu.gov.cn/', category: '省级统计', description: '甘肃统计年鉴入口', tags: ['甘肃']),
  StatSite(id: 'qinghai', name: '青海统计局', url: 'https://tjj.qinghai.gov.cn/', category: '省级统计', description: '青海统计年鉴入口', tags: ['青海']),
  StatSite(id: 'ningxia', name: '宁夏统计局', url: 'https://tj.nx.gov.cn/', category: '省级统计', description: '宁夏统计年鉴入口', tags: ['宁夏']),
  StatSite(id: 'xinjiang', name: '新疆统计局', url: 'https://tjj.xinjiang.gov.cn/', category: '省级统计', description: '新疆统计年鉴入口', tags: ['新疆']),

  // 数据开放平台
  StatSite(id: 'dc_national', name: '国家数据', url: 'https://data.stats.gov.cn/', category: '数据开放', description: '国家统计局数据平台', tags: ['全国', '开放数据']),
  StatSite(id: 'dc_beijing', name: '北京公共数据', url: 'https://data.beijing.gov.cn/', category: '数据开放', description: '北京市公共数据开放平台', tags: ['北京', '开放数据']),
  StatSite(id: 'dc_shanghai', name: '上海公共数据', url: 'https://data.sh.gov.cn/', category: '数据开放', description: '上海市公共数据开放平台', tags: ['上海', '开放数据']),
  StatSite(id: 'dc_zhejiang', name: '浙江公共数据', url: 'https://data.zj.gov.cn/', category: '数据开放', description: '浙江省公共数据开放平台', tags: ['浙江', '开放数据']),
  StatSite(id: 'dc_guangdong', name: '广东公共数据', url: 'https://gddata.gd.gov.cn/', category: '数据开放', description: '广东省公共数据开放平台', tags: ['广东', '开放数据']),
  StatSite(id: 'dc_shandong', name: '山东公共数据', url: 'http://data.sd.gov.cn/', category: '数据开放', description: '山东省公共数据开放网', tags: ['山东', '开放数据']),
  StatSite(id: 'dc_fujian', name: '福建公共数据', url: 'https://data.fujian.gov.cn/', category: '数据开放', description: '福建省公共数据开放平台', tags: ['福建', '开放数据']),
  StatSite(id: 'dc_guizhou', name: '贵州公共数据', url: 'https://data.guizhou.gov.cn/', category: '数据开放', description: '贵州省数据开放平台', tags: ['贵州', '开放数据']),
  StatSite(id: 'dc_shenzhen', name: '深圳开放数据', url: 'https://opendata.sz.gov.cn/', category: '数据开放', description: '深圳市政府数据开放平台', tags: ['深圳', '广东', '开放数据']),
];

const List<String> _provinces = [
  '北京', '天津', '河北', '山西', '内蒙古', '辽宁', '吉林', '黑龙江', '上海', '江苏', '浙江', '安徽',
  '福建', '江西', '山东', '河南', '湖北', '湖南', '广东', '广西', '海南', '重庆', '四川', '贵州',
  '云南', '西藏', '陕西', '甘肃', '青海', '宁夏', '新疆',
];

List<StatSite> suggestStatSites(String keyword, {int limit = 8}) {
  final k = keyword.toLowerCase().trim();
  final out = <StatSite>[];
  void add(StatSite s) {
    if (!out.any((e) => e.id == s.id)) out.add(s);
  }

  for (final p in _provinces) {
    if (k.contains(p)) {
      for (final s in statSites) {
        if (s.tags.contains(p)) add(s);
      }
      break;
    }
  }
  if (k.contains('财政') || k.contains('税收') || k.contains('债务')) {
    add(statSites.firstWhere((s) => s.id == 'mof'));
  }
  if (k.contains('进出口') || k.contains('贸易') || k.contains('海关')) {
    add(statSites.firstWhere((s) => s.id == 'customs'));
  }
  if (k.contains('金融') || k.contains('货币') || k.contains('信贷')) {
    add(statSites.firstWhere((s) => s.id == 'pbc'));
  }
  if (k.contains('就业') || k.contains('工资')) {
    add(statSites.firstWhere((s) => s.id == 'mohrss'));
  }
  if (k.contains('教育') || k.contains('高校')) {
    add(statSites.firstWhere((s) => s.id == 'moe'));
  }
  if (k.contains('科技') || k.contains('研发') || k.contains('专利')) {
    add(statSites.firstWhere((s) => s.id == 'most'));
  }

  // Always include national sources for macro keywords.
  for (final id in ['nbs_data', 'nbs_yearbook', 'nbs']) {
    add(statSites.firstWhere((s) => s.id == id));
  }
  // Add open data platforms when no province matched.
  if (!_provinces.any((p) => k.contains(p))) {
    for (final id in ['dc_beijing', 'dc_shanghai', 'dc_zhejiang', 'dc_guangdong']) {
      add(statSites.firstWhere((s) => s.id == id));
    }
  }
  return out.take(limit).toList();
}
