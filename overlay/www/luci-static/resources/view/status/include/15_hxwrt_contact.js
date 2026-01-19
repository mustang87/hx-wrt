'use strict';
'require baseclass';

return baseclass.extend({
	title: _('HX-WRT · Contact'),

	render: function() {
		// ====== 你只需要改这里 ======
		var CONTACT = {
			brand:  'HX-WRT',
			qq:     '799717180',
			qqgroup:'620409641',
			tg:     '@LeoLei',        // TG 用户名 或 频道/群入口描述
			email:  'support@myaccelerator.vip',
			website:'doc.myaccelerator.vip', // 这里只显示文本，不强制写 URL
			wechat: '-'                      // 可选：没有就 '-'
		};
		// ============================

		function row(k, v) {
			return E('div', { 'class': 'tr' }, [
				E('div', { 'class': 'td left' }, k),
				E('div', { 'class': 'td left' }, v || '-')
			]);
		}

		return E('div', { 'class': 'cbi-section-node' }, [
			E('div', { 'class': 'table' }, [
				row(_('Brand'),   CONTACT.brand),
				row(_('QQ'),      CONTACT.qq),
				row(_('QQ Group'),CONTACT.qqgroup),
				row(_('Telegram'),CONTACT.tg),
				row(_('Email'),   CONTACT.email),
				row(_('Website'), CONTACT.website),
				row(_('WeChat'),  CONTACT.wechat)
			]),
			E('div', { 'class': 'cbi-value-description' }, [
				_('If you encounter issues, please include screenshots + system log to speed up troubleshooting.')
			])
		]);
	}
});
