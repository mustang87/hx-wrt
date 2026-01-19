'use strict';
'require baseclass';
'require fs';
'require rpc';

var callUciGet = rpc.declare({
	object: 'uci',
	method: 'get',
	params: [ 'config', 'section', 'option' ],
	expect: { value: '' }
});

function getUci(config, section, option) {
	return callUciGet(config, section, option).catch(function() { return ''; });
}

function parseBrandConf(text) {
	// 兼容：package/hx-brand/files/etc/hx-wrt/brand.conf 可能是 k=v
	// 例如：
	// BRAND=HX-WRT
	// QQ=123...
	// TG=@...
	var out = {};
	(text || '').split(/\r?\n/).forEach(function(line) {
		line = line.trim();
		if (!line || line.startsWith('#')) return;
		var m = line.match(/^([A-Za-z0-9_]+)\s*=\s*(.*)$/);
		if (!m) return;
		var k = m[1].toLowerCase();
		var v = (m[2] || '').replace(/^['"]|['"]$/g, '').trim();
		out[k] = v;
	});
	return out;
}

return baseclass.extend({
	title: 'HX-WRT · 联系方式',

	load: function() {
		// 优先：新配置 hxwrt
		// 兼容：旧配置 hx-wrt
		// 兼容：/etc/hx-wrt/brand.conf
		return Promise.all([
			getUci('hxwrt', 'main', 'brand'),
			getUci('hxwrt', 'main', 'channel'),
			getUci('hxwrt', 'main', 'website'),
			getUci('hxwrt', 'main', 'email'),
			getUci('hxwrt', 'main', 'qq'),
			getUci('hxwrt', 'main', 'qqgroup'),
			getUci('hxwrt', 'main', 'tg'),
			getUci('hxwrt', 'main', 'wechat'),

			// 旧配置名兼容（你现在已有 overlay/etc/config/hx-wrt）
			getUci('hx-wrt', 'main', 'brand'),
			getUci('hx-wrt', 'main', 'channel'),
			getUci('hx-wrt', 'main', 'website'),
			getUci('hx-wrt', 'main', 'email'),
			getUci('hx-wrt', 'main', 'qq'),
			getUci('hx-wrt', 'main', 'qqgroup'),
			getUci('hx-wrt', 'main', 'tg'),
			getUci('hx-wrt', 'main', 'wechat'),

			fs.read('/etc/hx-wrt/brand.conf').catch(function() { return ''; })
		]);
	},

	render: function(data) {
		// data[0..7]  = hxwrt.main.*
		// data[8..15] = hx-wrt.main.* (兼容)
		// data[16]    = brand.conf
		var hxwrt = {
			brand:   (data[0]  || '').trim(),
			channel: (data[1]  || '').trim(),
			website: (data[2]  || '').trim(),
			email:   (data[3]  || '').trim(),
			qq:      (data[4]  || '').trim(),
			qqgroup: (data[5]  || '').trim(),
			tg:      (data[6]  || '').trim(),
			wechat:  (data[7]  || '').trim()
		};

		var old = {
			brand:   (data[8]  || '').trim(),
			channel: (data[9]  || '').trim(),
			website: (data[10] || '').trim(),
			email:   (data[11] || '').trim(),
			qq:      (data[12] || '').trim(),
			qqgroup: (data[13] || '').trim(),
			tg:      (data[14] || '').trim(),
			wechat:  (data[15] || '').trim()
		};

		var conf = parseBrandConf(data[16] || '');

		// 最终默认值（固件级兜底）
		var CONTACT = {
			brand:   hxwrt.brand   || old.brand   || conf.brand   || 'HX-WRT',
			channel: hxwrt.channel || old.channel || conf.channel || 'stable',
			website: hxwrt.website || old.website || conf.website || 'doc.myaccelerator.vip',
			email:   hxwrt.email   || old.email   || conf.email   || '',
			qq:      hxwrt.qq      || old.qq      || conf.qq      || '',
			qqgroup: hxwrt.qqgroup || old.qqgroup || conf.qqgroup || '',
			tg:      hxwrt.tg      || old.tg      || conf.tg      || '',
			wechat:  hxwrt.wechat  || old.wechat  || conf.wechat  || ''
		};

		function row(k, v) {
			return E('div', { 'class': 'tr' }, [
				E('div', { 'class': 'td left' }, k),
				E('div', { 'class': 'td left' }, (v && String(v).trim()) ? v : '-')
			]);
		}

		return E('div', { 'class': 'cbi-section-node' }, [
			E('div', { 'class': 'table' }, [
				row('品牌',    CONTACT.brand),
				row('渠道',    CONTACT.channel),
				row('官网',    CONTACT.website),
				row('邮箱',    CONTACT.email),
				row('QQ',      CONTACT.qq),
				row('QQ群',    CONTACT.qqgroup),
				row('Telegram',CONTACT.tg),
				row('微信',    CONTACT.wechat)
			]),
			E('div', { 'class': 'cbi-value-description' }, [
				'反馈问题请带：截图 + 系统日志（logread）+ 复现步骤，定位会快很多。'
			])
		]);
	}
});
