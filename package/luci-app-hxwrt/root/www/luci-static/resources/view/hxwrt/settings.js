'use strict';
'require view';
'require form';
'require uci';

return view.extend({
	render: function() {
		// 统一用 hxwrt；如果你系统里暂时没这个 config，也会在保存时创建
		var m = new form.Map('hxwrt', 'HX-WRT 设置', '这里只负责展示与配置（联系方式、开关），不改任何核心逻辑。');

		// ---------- 联系方式 ----------
		var s1 = m.section(form.NamedSection, 'main', 'brand', '品牌与联系方式');
		s1.anonymous = false;
		s1.addremove = false;

		var o;

		o = s1.option(form.Value, 'brand', '品牌名');
		o.placeholder = 'HX-WRT';

		o = s1.option(form.Value, 'channel', '渠道标识');
		o.placeholder = 'stable';

		o = s1.option(form.Value, 'website', '官网');
		o.placeholder = 'doc.myaccelerator.vip';

		o = s1.option(form.Value, 'email', '邮箱');
		o.datatype = 'string';

		o = s1.option(form.Value, 'qq', 'QQ');
		o.datatype = 'string';

		o = s1.option(form.Value, 'qqgroup', 'QQ群');
		o.datatype = 'string';

		o = s1.option(form.Value, 'tg', 'Telegram');
		o.datatype = 'string';
		o.placeholder = '@hxwrt_support';

		o = s1.option(form.Value, 'wechat', '微信');
		o.datatype = 'string';

		// ---------- 功能开关 ----------
		var s2 = m.section(form.NamedSection, 'ipv6_disable', 'feature', '功能开关');
		s2.anonymous = false;
		s2.addremove = false;

		o = s2.option(form.Flag, 'enabled', '默认关闭 IPv6');
		o.default = o.enabled;
		o.rmempty = false;
		o.description = '仅设置开关本身；真正执行逻辑由你的 uci-defaults / 脚本实现。';

		return m.render();
	}
});
