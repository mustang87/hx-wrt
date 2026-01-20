'use strict';
'require baseclass';
'require rpc';

var callUciGet = rpc.declare({
	object: 'uci',
	method: 'get',
	params: [ 'config', 'section', 'option' ],
	expect: { value: '' }
});

function uciGet(option) {
	// 固定读取：/etc/config/hxwrt 里的 config brand 'main'
	return callUciGet('hxwrt', 'main', option).catch(function() { return ''; });
}

function s(v) {
	v = (v == null) ? '' : String(v);
	return v.trim();
}

function isHttpUrl(v) {
	return /^https?:\/\//i.test(v);
}

function toHttpsUrl(v) {
	v = s(v);
	if (!v) return '';
	if (isHttpUrl(v)) return v;
	return 'https://' + v.replace(/^\/+/, '');
}

function tgToUrl(v) {
	v = s(v);
	if (!v) return '';
	if (isHttpUrl(v)) return v;
	if (v.startsWith('@') && v.length > 1)
		return 'https://t.me/' + v.substring(1);
	return 'https://t.me/' + v.replace(/^\/+/, '');
}

function a(label, href) {
	href = s(href);
	if (!href) return E('span', {}, [ '-' ]);
	return E('a', {
		'href': href,
		'target': '_blank',
		'rel': 'noopener noreferrer'
	}, [ label ]);
}

function textNode(v) {
	v = s(v);
	return E('span', {}, [ v || '-' ]);
}

function row(k, vnode) {
	return E('div', { 'class': 'tr' }, [
		E('div', { 'class': 'td left' }, [ k ]),
		E('div', { 'class': 'td left' }, [ vnode ])
	]);
}

function button(label, href) {
	href = s(href);
	if (!href) {
		return E('span', {
			'class': 'cbi-button cbi-button-neutral',
			'style': 'opacity:.55; cursor:not-allowed;'
		}, [ label ]);
	}

	// 用 <a> 做按钮：LuCI 里最稳的可点击方式
	return E('a', {
		'class': 'cbi-button cbi-button-action',
		'href': href,
		'target': '_blank',
		'rel': 'noopener noreferrer'
	}, [ label ]);
}

return baseclass.extend({
	title: 'HX-WRT · 联系方式',

	load: function() {
		return Promise.all([
			uciGet('brand'),
			uciGet('channel'),
			uciGet('website'),
			uciGet('email'),
			uciGet('tg'),
			uciGet('qq'),
			uciGet('qqgroup'),
			uciGet('qqgroup_link'),
			uciGet('wechat')
		]);
	},

	render: function(data) {
		var CONTACT = {
			brand:        s(data[0]) || 'HX-WRT',
			channel:      s(data[1]) || 'stable',
			website:      s(data[2]),
			email:        s(data[3]),
			tg:           s(data[4]),
			qq:           s(data[5]),
			qqgroup:      s(data[6]),
			qqgroup_link: s(data[7]),
			wechat:       s(data[8])
		};

		// 跳转目标
		var websiteUrl = toHttpsUrl(CONTACT.website);
		var tgUrl = tgToUrl(CONTACT.tg);

		// 可点击节点
		var websiteNode = CONTACT.website ? a(CONTACT.website, websiteUrl) : textNode('');
		var emailNode   = CONTACT.email ? a(CONTACT.email, 'mailto:' + CONTACT.email) : textNode('');
		var tgNode      = CONTACT.tg ? a(CONTACT.tg, tgUrl) : textNode('');

		// QQ：展示为文本（兼容最稳）
		var qqNode = textNode(CONTACT.qq);

		// QQ群：优先用 qqgroup_link 做可点链接；否则只展示群号
		var qqGroupNode;
		if (CONTACT.qqgroup_link) {
			var qqlink = CONTACT.qqgroup_link;
			// 如果用户只填了域名/短路径，也补 https
			qqlink = isHttpUrl(qqlink) ? qqlink : toHttpsUrl(qqlink);
			// 展示文本优先用群号；没有群号就显示链接本身
			var label = CONTACT.qqgroup || qqlink;
			qqGroupNode = a(label, qqlink);
		} else {
			qqGroupNode = textNode(CONTACT.qqgroup);
		}

		// 按钮：加入 TG / 打开文档
		// var btnTG   = button('加入 TG', tgUrl);
		// var btnDocs = button('打开文档', websiteUrl);

		return E('div', { 'class': 'cbi-section-node' }, [
			E('div', { 'class': 'table' }, [
				row('品牌',     textNode(CONTACT.brand)),
				row('渠道',     textNode(CONTACT.channel)),
				row('官网',     websiteNode),
				row('邮箱',     emailNode),
				row('Telegram', tgNode),
				row('QQ',       qqNode),
				row('QQ群',     qqGroupNode),
				row('微信',     textNode(CONTACT.wechat))
			]),

			// E('div', { 'style': 'margin-top:10px;' }, [
			// 	btnTG,
			// 	E('span', { 'style': 'display:inline-block; width:8px;' }, [ ' ' ]),
			// 	btnDocs
			// ]),

			E('div', { 'class': 'cbi-value-description', 'style': 'margin-top:8px;' }, [
				'反馈问题建议附带：截图 + logread 关键日志 + 复现步骤（定位会快很多）。'
			])
		]);
	}
});
