'use strict';

const assert = require('assert').strict;
const fs = require('fs');

const zonesPath = process.argv[2];
const poPath = process.argv[3];

if (!zonesPath || !poPath)
	throw new Error('usage: node test-luci-firewall-fullcone.js <zones.js> <firewall.po>');

const zones = fs.readFileSync(zonesPath, 'utf8');
const translations = fs.readFileSync(poPath, 'utf8');
const compactZones = zones.replace(/\s+/g, '');

assert.ok(
	compactZones.includes(
		"if(fw4){s=m.section(form.TypedSection,'defaults',_('FullConeNAT')"
	),
	'the controls must use the global firewall defaults section and only appear with firewall4'
);

for (const family of [
	{ key: 'fullcone', label: 'Enable IPv4 Full Cone NAT' },
	{ key: 'fullcone6', label: 'Enable IPv6 Full Cone NAT' }
]) {
	const optionStart = compactZones.indexOf(
		`s.option(form.Flag,'${family.key}',_('${family.label.replace(/\s+/g, '')}')`
	);
	const nextOption = compactZones.indexOf('s.option(', optionStart + 1);
	const optionBlock = compactZones.slice(
		optionStart,
		nextOption >= 0 ? nextOption : compactZones.length
	);

	assert.ok(
		optionStart >= 0 && optionBlock.includes("o.default='0'"),
		`${family.key} must be an explicitly disabled global flag`
	);
	assert.ok(
		translations.includes(`msgid "${family.label}"`),
		`${family.key} is missing from the Simplified Chinese catalog`
	);
}

assert.ok(
	zones.includes('It cannot bypass CGNAT or double NAT.'),
	'the page must state the upstream-NAT limitation'
);
assert.ok(
	zones.includes('IPv6 NAT is usually unnecessary.'),
	'the IPv6 control must explain that IPv6 NAT is usually unnecessary'
);
assert.ok(
	translations.includes('msgstr "全锥形 NAT"'),
	'the Full Cone section title is not translated'
);
assert.ok(
	translations.includes('CGNAT 或双重 NAT'),
	'the translated safety warning is missing'
);
assert.doesNotMatch(
	compactZones,
	/s\.taboption\([^;]*'fullcone6?'/,
	'the global controls must not be presented as per-zone options'
);

console.log('LUCI FIREWALL FULL CONE TEST PASSED');
