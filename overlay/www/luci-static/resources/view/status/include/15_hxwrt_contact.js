render: function(data) {
	// —— 以下 CONTACT 构建逻辑与你现有的一致，这里假设已得到 CONTACT ——
	var CONTACT = this._contact || data; // 说明性占位，你实际用你现有 CONTACT

	function text(v) {
		return (v && String(v).trim()) ? v : '-';
	}

	function link(label, href) {
		if (!href) return '-';
		return E('a', {
			'href': href,
			'target': '_blank',
			'rel': 'noopener noreferrer'
		}, label);
	}

	function row(k, v) {
		return E('div', { 'class': 'tr' }, [
			E('div', { 'class': 'td left' }, k),
			E('div', { 'class': 'td left' }, v)
		]);
	}

	/* ===== 构建可点击内容 ===== */

	var websiteNode = CONTACT.website
		? link(CONTACT.website.startsWith('http')
			? CONTACT.website
			: 'https://' + CONTACT.website,
			CONTACT.website)
		: '-';

	var emailNode = CONTACT.email
		? link(CONTACT.email, 'mailto:' + CONTACT.email)
		: '-';

	var tgNode = CONTACT.tg
		? link(CONTACT.tg, CONTACT.tg.startsWith('@')
			? 'https://t.me/' + CONTACT.tg.substring(1)
			: CONTACT.tg)
		: '-';

	// QQ：尝试 tencent://，失败也不影响页面
	var qqNode = CONTACT.qq
		? link(CONTACT.qq, 'tencent://message/?uin=' + CONTACT.qq)
		: '-';

	// QQ 群：如果你以后换成 qm.qq.com 链接，这里自动支持
	var qqGroupNode = CONTACT.qqgroup
		? (CONTACT.qqgroup.startsWith('http')
			? link(CONTACT.qqgroup, CONTACT.qqgroup)
			: text(CONTACT.qqgroup))
		: '-';

	return E('div', { 'class': 'cbi-section-node' }, [
		E('div', { 'class': 'table' }, [
			row('品牌', CONTACT.brand || 'HX-WRT'),
			row('渠道', CONTACT.channel || 'stable'),
			row('官网', websiteNode),
			row('邮箱', emailNode),
			row('Telegram', tgNode),
			row('QQ', qqNode),
			row('QQ群', qqGroupNode),
			row('微信', text(CONTACT.wechat))
		]),
		E('div', { 'class': 'cbi-value-description' }, [
			'建议反馈问题时附带：截图 + 系统日志（logread），便于快速定位。'
		])
	]);
}
