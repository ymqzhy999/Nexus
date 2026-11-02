class WbIndicator {
  final String code;
  final String name;
  final String unit;

  const WbIndicator(this.code, this.name, this.unit);
}

const List<WbIndicator> wbIndicators = [
  WbIndicator('NY.GDP.MKTP.CD', 'GDP（现价美元）', '美元'),
  WbIndicator('NY.GDP.MKTP.KD.ZG', 'GDP 增长率', '%'),
  WbIndicator('NY.GDP.PCAP.CD', '人均 GDP（现价美元）', '美元'),
  WbIndicator('NY.GDP.PCAP.KD.ZG', '人均 GDP 增长率', '%'),
  WbIndicator('FP.CPI.TOTL', 'CPI（2010=100）', '指数'),
  WbIndicator('FP.CPI.TOTL.ZG', '通货膨胀率（CPI）', '%'),
  WbIndicator('SP.POP.TOTL', '总人口', '人'),
  WbIndicator('SL.UEM.TOTL.ZS', '失业率（ILO 模型）', '%'),
  WbIndicator('GC.DOD.TOTL.GD.ZS', '政府债务 / GDP', '%'),
  WbIndicator('GB.XPD.RSDV.GD.ZS', '研发支出 / GDP', '%'),
  WbIndicator('IT.NET.USER.ZS', '互联网使用率', '%'),
  WbIndicator('IT.CEL.SETS.P2', '每百人移动电话', '每百人'),
  WbIndicator('TX.VAL.TECH.MF.ZS', '高技术产品出口占比', '%'),
  WbIndicator('NE.EXP.GNFS.ZS', '出口 / GDP', '%'),
  WbIndicator('NE.IMP.GNFS.ZS', '进口 / GDP', '%'),
  WbIndicator('NV.IND.TOTL.ZS', '工业增加值 / GDP', '%'),
  WbIndicator('NV.SRV.TOTL.ZS', '服务业增加值 / GDP', '%'),
  WbIndicator('SE.TER.ENRR', '高等教育毛入学率', '%'),
];

class WbCountry {
  final String code;
  final String name;

  const WbCountry(this.code, this.name);
}

const List<WbCountry> wbCountries = [
  WbCountry('CN', '中国'),
  WbCountry('US', '美国'),
  WbCountry('WLD', '世界'),
  WbCountry('JP', '日本'),
  WbCountry('DE', '德国'),
  WbCountry('GB', '英国'),
  WbCountry('IN', '印度'),
  WbCountry('KR', '韩国'),
  WbCountry('FR', '法国'),
  WbCountry('SG', '新加坡'),
];

class ProvinceSource {
  final String name;
  final String url;
  final bool yearbook;

  const ProvinceSource(this.name, this.url, {this.yearbook = false});
}

const List<ProvinceSource> provinceSources = [
  ProvinceSource('国家统计局', 'https://data.stats.gov.cn/', yearbook: true),
  ProvinceSource('中国统计年鉴', 'https://www.stats.gov.cn/sj/ndsj/', yearbook: true),
  ProvinceSource('北京', 'https://tjj.beijing.gov.cn/'),
  ProvinceSource('天津', 'https://stats.tj.gov.cn/tjsj_52032/tjnj/', yearbook: true),
  ProvinceSource('河北', 'https://tjj.hebei.gov.cn/'),
  ProvinceSource('山西', 'https://tjj.shanxi.gov.cn/tjsj/tjnj/', yearbook: true),
  ProvinceSource('内蒙古', 'https://tj.nmg.gov.cn/tjyw/tjnj/', yearbook: true),
  ProvinceSource('辽宁', 'https://tjj.ln.gov.cn/tjsj/tjnj/', yearbook: true),
  ProvinceSource('吉林', 'https://tjj.jl.gov.cn/tjsj/tjnj/', yearbook: true),
  ProvinceSource('黑龙江', 'https://tjj.hlj.gov.cn/'),
  ProvinceSource('上海', 'https://tjj.sh.gov.cn/tjnj/', yearbook: true),
  ProvinceSource('江苏', 'https://tj.jiangsu.gov.cn/'),
  ProvinceSource('浙江', 'https://tjj.zj.gov.cn/col/col1525563/index.html', yearbook: true),
  ProvinceSource('安徽', 'https://tjj.ah.gov.cn/ssah/qwfbjd/tjnj/index.html', yearbook: true),
  ProvinceSource('福建', 'https://tjj.fujian.gov.cn/'),
  ProvinceSource('江西', 'https://tjj.jiangxi.gov.cn/col/col38595/index.html', yearbook: true),
  ProvinceSource('山东', 'https://tjj.shandong.gov.cn/'),
  ProvinceSource('河南', 'https://tjj.henan.gov.cn/tjfw/tjcbw/tjnj/', yearbook: true),
  ProvinceSource('湖北', 'https://tjj.hubei.gov.cn/'),
  ProvinceSource('湖南', 'https://tjj.hunan.gov.cn/hntj/tjsj/tjnj/', yearbook: true),
  ProvinceSource('广东', 'https://stats.gd.gov.cn/gdtjnj/', yearbook: true),
  ProvinceSource('广西', 'http://tjj.gxzf.gov.cn/tjsj/tjnj/', yearbook: true),
  ProvinceSource('海南', 'https://stats.hainan.gov.cn/tjj/tjsj/tjnj/', yearbook: true),
  ProvinceSource('重庆', 'https://tjj.cq.gov.cn/zwgk_233/tjnj/', yearbook: true),
  ProvinceSource('四川', 'https://tjj.sc.gov.cn/'),
  ProvinceSource('贵州', 'https://stjj.guizhou.gov.cn/'),
  ProvinceSource('云南', 'https://stats.yn.gov.cn/'),
  ProvinceSource('西藏', 'http://tjj.xizang.gov.cn/'),
  ProvinceSource('陕西', 'https://tjj.shaanxi.gov.cn/'),
  ProvinceSource('甘肃', 'https://tjj.gansu.gov.cn/'),
  ProvinceSource('青海', 'https://tjj.qinghai.gov.cn/'),
  ProvinceSource('宁夏', 'https://tj.nx.gov.cn/'),
  ProvinceSource('新疆', 'https://tjj.xinjiang.gov.cn/'),
];

class DataCenter {
  final String name;
  final String url;

  const DataCenter(this.name, this.url);
}

const List<DataCenter> dataCenters = [
  DataCenter('国家数据', 'https://data.stats.gov.cn/'),
  DataCenter('中国统计年鉴', 'https://www.stats.gov.cn/sj/ndsj/'),
  DataCenter('北京公共数据', 'https://data.beijing.gov.cn/'),
  DataCenter('上海公共数据', 'https://data.sh.gov.cn/'),
  DataCenter('浙江公共数据', 'https://data.zj.gov.cn/'),
  DataCenter('广东公共数据', 'https://gddata.gd.gov.cn/'),
  DataCenter('山东公共数据', 'http://data.sd.gov.cn/'),
  DataCenter('福建公共数据', 'https://data.fujian.gov.cn/'),
  DataCenter('贵州公共数据', 'https://data.guizhou.gov.cn/'),
  DataCenter('深圳开放数据', 'https://opendata.sz.gov.cn/'),
];

class GovPortal {
  final String name;
  final String url;
  final String category;
  final String description;

  const GovPortal(this.name, this.url, this.category, this.description);
}

const List<GovPortal> govPortals = [
  GovPortal('国家统计局', 'https://www.stats.gov.cn/', '中国官方', '统计公报、年鉴、月度/年度数据'),
  GovPortal('国家数据', 'https://data.stats.gov.cn/', '中国官方', '分省年度/月度数据查询'),
  GovPortal('财政部', 'https://www.mof.gov.cn/gkml/caizhengshuju/', '中国官方', '财政收支与债务数据'),
  GovPortal('海关总署', 'http://www.customs.gov.cn/', '中国官方', '进出口与贸易统计'),
  GovPortal('中国人民银行', 'http://www.pbc.gov.cn/diaochatongjisi/116219/index.html', '中国官方', '金融、信贷与社会融资'),
  GovPortal('人社部', 'https://www.mohrss.gov.cn/SYrlzyhshbzb/zwgk/szrs/', '中国官方', '就业、工资与社会保障'),
  GovPortal('教育部', 'http://www.moe.gov.cn/jyb_sjzl/', '中国官方', '教育统计与经费'),
  GovPortal('科技部', 'https://www.most.gov.cn/kjbgz/', '中国官方', '科技统计与研发投入'),
  GovPortal('世界银行', 'https://data.worldbank.org/', '国际组织', '跨国年度经济与社会指标'),
  GovPortal('IMF', 'https://data.imf.org/', '国际组织', '国际金融与宏观经济'),
  GovPortal('OECD', 'https://data.oecd.org/', '国际组织', '发达国家比较数据'),
  GovPortal('Eurostat', 'https://ec.europa.eu/eurostat/data/database', '国际组织', '欧盟统计数据库'),
  GovPortal('FRED', 'https://fred.stlouisfed.org/', '国际组织', '美国与全球宏观时间序列'),
  GovPortal('UN Data', 'https://data.un.org/', '国际组织', '联合国统计数据库'),
  GovPortal('Data.gov', 'https://catalog.data.gov/dataset', '美国政府', '美国联邦开放数据目录'),
  GovPortal('Our World in Data', 'https://ourworldindata.org/', '研究机构', '长期全球发展数据与图表'),
];
