'use strict';

const assert = require('assert').strict;
const fs = require('fs');

const sourcePath = process.argv[2];
const interfacesPath = process.argv[3];

if (!sourcePath || !interfacesPath)
	throw new Error('usage: node test-luci-lan-cidr.js <patched-static.js> <patched-interfaces.js>');

const source = fs.readFileSync(sourcePath, 'utf8');
const interfacesSource = fs.readFileSync(interfacesPath, 'utf8');
const compactSource = source.replace(/\s+/g, '');
const compactInterfacesSource = interfacesSource.replace(/\s+/g, '');

function extractFunction(text, name) {
	const start = text.indexOf(`function ${name}(`);

	if (start < 0)
		throw new Error(`${name}() is missing`);

	const bodyStart = text.indexOf('{', start);
	let depth = 0;

	for (let i = bodyStart; i < text.length; i++) {
		if (text[i] === '{')
			depth++;
		else if (text[i] === '}' && --depth === 0)
			return text.slice(start, i + 1);
	}

	throw new Error(`${name}() is malformed`);
}

const sanitizeSource = extractFunction(source, 'sanitizeLanIPv4');
const normalizeSource = extractFunction(source, 'normalizeLanIPv4')
	.replace(
		/'%s\/%d'\.format\(addr,\s*prefix\)/g,
		"String(addr) + '/' + String(prefix)"
	);
const broadcastSource = extractFunction(source, 'calculateBroadcast');
const isCIDRSource = extractFunction(source, 'isCIDR');
const netmaskSource = extractFunction(interfacesSource, 'get_netmask');

const network = {
	maskToPrefix(mask) {
		const prefixes = {
			'255.255.255.0': 24,
			'255.255.0.0': 16,
			'255.0.0.0': 8
		};

		return Object.prototype.hasOwnProperty.call(prefixes, mask)
			? prefixes[mask]
			: null;
	},

	prefixToMask(prefix) {
		const masks = {
			8: '255.0.0.0',
			16: '255.255.0.0',
			24: '255.255.255.0',
			32: '255.255.255.255'
		};

		return masks[prefix] || null;
	}
};

const validation = {
	parseIPv4(value) {
		if (typeof value !== 'string')
			return null;

		const octets = value.split('.');
		return octets.length === 4 &&
			octets.every(octet =>
				/^\d+$/.test(octet) &&
				Number(octet) >= 0 &&
				Number(octet) <= 255)
			? octets.map(Number)
			: null;
	}
};

const L = {
	toArray(value) {
		if (value == null)
			return [];
		return Array.isArray(value) ? value : [ value ];
	}
};

const helpers = new Function(
	'L',
	'network',
	'validation',
	`${sanitizeSource}\n${normalizeSource}\n${isCIDRSource}\n${broadcastSource}
	return { sanitizeLanIPv4, normalizeLanIPv4, calculateBroadcast };`
)(L, network, validation);

const getNetmask = new Function(
	'L',
	'network',
	`${netmaskSource}\nreturn get_netmask;`
)(L, network);

assert.deepEqual(
	helpers.sanitizeLanIPv4('lan', [ undefined, null, '', '192.168.50.1/24' ]),
	[ '192.168.50.1/24' ],
	'the LAN render path must remove sparse values before DynamicList sees them'
);

const untouchedGuest = [ undefined, '10.0.0.1' ];
assert.equal(
	helpers.sanitizeLanIPv4('guest', untouchedGuest),
	untouchedGuest,
	'non-LAN interfaces must retain their exact upstream value'
);

assert.deepEqual(
	helpers.normalizeLanIPv4('lan', [ '192.168.50.1/24' ], undefined),
	[ '192.168.50.1/24' ],
	'an existing LAN CIDR must remain unchanged'
);
assert.deepEqual(
	helpers.normalizeLanIPv4('lan', '192.168.40.1', undefined),
	[ '192.168.40.1/24' ],
	'a bare LAN scalar must be saved as /24'
);
assert.deepEqual(
	helpers.normalizeLanIPv4('lan', [ '192.168.40.1' ], '255.255.0.0'),
	[ '192.168.40.1/16' ],
	'a valid legacy LAN netmask must be preserved as a prefix'
);
assert.deepEqual(
	helpers.normalizeLanIPv4('lan', [ undefined, '', '192.168.40.1', '192.168.41.1/24' ], undefined),
	[ '192.168.40.1/24', '192.168.41.1/24' ],
	'a sparse mixed LAN list must be filtered and normalize only its bare address'
);
assert.deepEqual(
	helpers.normalizeLanIPv4('lan', [ undefined, null, '', 'not-an-ip' ], undefined),
	[ 'not-an-ip' ],
	'the save hook must not dereference sparse values or rewrite invalid text'
);

const guest = [ '10.0.0.1' ];
assert.equal(
	helpers.normalizeLanIPv4('guest', guest, undefined),
	guest,
	'non-LAN interfaces must retain the exact upstream value'
);

function makeBroadcastSection(addresses, netmask) {
	const values = {
		ipaddr: addresses,
		netmask
	};

	return {
		section: 'lan',
		children: [ 'ipaddr', 'netmask' ].map(option => ({
			option,
			cfgvalue() {
				return values[option];
			},
			formvalue() {
				return values[option];
			}
		}))
	};
}

assert.equal(
	helpers.calculateBroadcast(
		makeBroadcastSection([ undefined, '', '192.168.50.1/24' ], null),
		true
	),
	'192.168.50.255',
	'broadcast calculation must skip sparse addresses without throwing'
);
assert.equal(
	helpers.calculateBroadcast(makeBroadcastSection([ undefined, '' ], null), true),
	null,
	'broadcast calculation must tolerate an entirely empty sparse list'
);

function makeNetmaskSection(addresses, netmask) {
	return {
		section: 'lan',
		cfgvalue(section, option) {
			return option === 'ipaddr' ? addresses : netmask;
		},
		formvalue(section, option) {
			return option === 'ipaddr' ? addresses : netmask;
		}
	};
}

assert.equal(
	getNetmask(makeNetmaskSection([ undefined, '', '192.168.50.1/24' ], null), true),
	'255.255.255.0',
	'the interfaces view must derive a netmask from the first valid CIDR'
);
assert.equal(
	getNetmask(makeNetmaskSection([ undefined, '192.168.40.1' ], '255.255.0.0'), true),
	'255.255.0.0',
	'the interfaces view must pair a legacy mask with the first valid address'
);
assert.equal(
	getNetmask(makeNetmaskSection([ undefined, '' ], null), true),
	null,
	'the interfaces view must tolerate an empty sparse list'
);

const sanitizeAt = compactSource.indexOf('cfgvalue=sanitizeLanIPv4(section_id,cfgvalue)');
const widgetAt = compactSource.indexOf('constwidget=isCIDR(cfgvalue)', sanitizeAt);
assert.ok(
	sanitizeAt >= 0 && widgetAt > sanitizeAt,
	'the render path must sanitize the LAN value before choosing DynamicList'
);
assert.ok(
	compactSource.includes("if(section_id!='lan')returnthis.super('write',[section_id,value])"),
	'the save hook must leave non-LAN interfaces on the upstream path'
);
assert.ok(
	compactSource.includes('constnormalized=normalizeLanIPv4(section_id,value,netmask)'),
	'the LAN save hook must pass the legacy netmask to normalization'
);
assert.ok(
	compactSource.includes("this.map.data.unset('network',section_id,'netmask')"),
	'the modern CIDR list must become authoritative after a LAN save'
);
assert.ok(
	compactSource.includes(
		"L.toArray(addropt[readfn](s.section)).filter(addr=>typeofaddr=='string'&&addr!='')"
	),
	'broadcast rendering must discard sparse values before dereferencing them'
);
assert.ok(
	compactSource.includes("if(typeofa!='string'||a=='')continue;"),
	'gateway validation must not split sparse IPv4 entries'
);
assert.ok(
	compactSource.includes('or(cidr4,ipmask4,ip4addr("nomask"))'),
	'the LAN DynamicList must accept a bare address before save-time normalization'
);
assert.ok(
	compactSource.includes('o.forcewrite=true'),
	'an unchanged legacy LAN value must still be repaired on save'
);
assert.ok(
	compactInterfacesSource.includes(
		"addrs.find(function(a){returntypeofa=='string'&&a.indexOf('/')>0})"
	),
	'the interfaces netmask helper must filter sparse values before indexOf()'
);

console.log('LUCI LAN CIDR TEST PASSED');
