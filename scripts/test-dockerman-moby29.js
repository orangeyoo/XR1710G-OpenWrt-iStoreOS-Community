'use strict';

const assert = require('assert').strict;
const fs = require('fs');

const overviewPath = process.argv[2];
const fixturePath = process.argv[3];

if (!overviewPath || !fixturePath)
	throw new Error(
		'usage: node test-dockerman-moby29.js <patched-overview.js> <moby29-info.json>'
	);

const overviewSource = fs.readFileSync(overviewPath, 'utf8');
const moby29Info = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));

assert.equal(moby29Info.ServerVersion.split('.')[0], '29',
	'the regression fixture must remain a Moby 29 /info response');
assert.equal(typeof moby29Info.Plugins, 'object',
	'the regression fixture must contain the nested Plugins object');
assert.equal(typeof moby29Info.RegistryConfig, 'object',
	'the regression fixture must contain the nested RegistryConfig object');
assert.equal(typeof moby29Info.Containerd, 'object',
	'the regression fixture must contain the nested Moby 29 Containerd object');

if (typeof String.prototype.format !== 'function') {
	Object.defineProperty(String.prototype, 'format', {
		configurable: true,
		value(...args) {
			if (String(this) === '%1024.2m')
				return `${(Number(args[0]) / (1024 * 1024)).toFixed(2)} MiB`;

			let index = 0;
			return String(this).replace(/%[sd]/g, () => String(args[index++]));
		}
	});
}

class TestNode {
	constructor(tag, attrs, children) {
		this.tag = tag;
		this.attrs = attrs || {};
		this.children = [];
		Object.assign(this, this.attrs);
		for (const child of normalizeChildren(children))
			this.appendChild(child);
	}

	appendChild(child) {
		this.children.push(child);
		return child;
	}

	get textContent() {
		return this.children.map(child => (
			child instanceof TestNode
				? child.textContent
				: String(child == null ? '' : child)
		)).join('');
	}
}

function normalizeChildren(children) {
	if (children === undefined || children === null)
		return [];
	if (!Array.isArray(children))
		return [children];

	return children.flatMap(child => Array.isArray(child)
		? normalizeChildren(child)
		: [child]);
}

function E(tag, attrs, children) {
	if (attrs === undefined || attrs === null)
		return new TestNode(tag, {}, []);

	if (typeof attrs !== 'object' || Array.isArray(attrs) || attrs instanceof TestNode)
		return new TestNode(tag, {}, attrs);

	return new TestNode(tag, attrs, children);
}

function walk(root) {
	const result = [];
	if (!(root instanceof TestNode))
		return result;

	result.push(root);
	for (const child of root.children)
		result.push(...walk(child));

	return result;
}

function nodes(root, tag) {
	return walk(root).filter(node => node.tag === tag);
}

function nodeByText(root, tag, text) {
	return nodes(root, tag).find(node => node.textContent.trim() === text);
}

const apiCalls = [];
const rcCalls = [];
const notifications = [];
const timers = [];
let daemonState = 'running';
let reloads = 0;

const dm2 = {
	dv: {
		extend(spec) {
			return spec;
		}
	},

	docker_info() {
		apiCalls.push('info');
		return Promise.resolve(daemonState === 'running'
			? { code: 200, body: JSON.parse(JSON.stringify(moby29Info)) }
			: { code: 503, body: { message: 'Cannot connect to Docker socket' } });
	},

	docker_version() {
		apiCalls.push('version');
		return Promise.resolve({
			code: 200,
			headers: {},
			body: {
				Version: '29.6.1',
				ApiVersion: '1.52',
				Components: [
					{ Name: 'Engine', Version: '29.6.1' }
				]
			}
		});
	},

	container_list() {
		apiCalls.push('containers');
		return Promise.resolve({
			body: [
				{
					ImageID: 'sha256:image-in-use',
					NetworkSettings: {
						Networks: {
							bridge: { NetworkID: 'network-in-use' }
						}
					},
					Mounts: [
						{ Type: 'volume', Name: 'volume-in-use' }
					]
				}
			]
		});
	},

	image_list() {
		apiCalls.push('images');
		return Promise.resolve({
			body: [
				{ Id: 'sha256:image-in-use' },
				{ Id: 'sha256:image-unused' }
			]
		});
	},

	network_list() {
		apiCalls.push('networks');
		return Promise.resolve({
			body: [
				{ Id: 'network-in-use' },
				{ Id: 'network-unused' }
			]
		});
	},

	volume_list() {
		apiCalls.push('volumes');
		return Promise.resolve({
			body: {
				Volumes: [
					{ Name: 'volume-in-use' },
					{ Name: 'volume-unused' }
				],
				Warnings: null
			}
		});
	},

	callMountPoints() {
		apiCalls.push('mounts');
		return Promise.resolve([
			{ mount: '/overlay/docker/', avail: 8 * 1024 * 1024 * 1024 }
		]);
	},

	callRcInit(name, action) {
		rcCalls.push(`${name}:${action}`);
		if (name === 'dockerd' && action === 'stop')
			daemonState = 'stopped';
		if (name === 'dockerd' && action === 'start')
			daemonState = 'running';
		return Promise.resolve(0);
	}
};

class Table {
	constructor(headers, attrs) {
		this.headers = headers;
		this.attrs = attrs;
		this.rows = [];
	}

	update(rows) {
		this.rows = rows;
	}

	render() {
		return E('table', this.attrs, [
			E('thead', {}, [
				E('tr', {}, this.headers.map(header => E('th', {}, [header])))
			]),
			E('tbody', {}, this.rows.map(row => E('tr', {}, row.map(
				value => E('td', {}, [value])
			))))
		]);
	}
}

const L = {
	url(path) {
		return `/${path}`;
	},
	resource(path) {
		return `/luci-static/resources/${path}`;
	},
	ui: {
		Table,
		addTimeLimitedNotification(...args) {
			notifications.push(args);
		}
	}
};

const uci = {
	get(config, section, option) {
		assert.deepEqual([config, section, option], ['dockerd', 'globals', 'hosts']);
		return [];
	}
};

const window = {
	location: {
		reload() {
			reloads++;
		}
	},
	setTimeout(callback, delay) {
		timers.push({ callback, delay });
		return timers.length;
	}
};

function translate(value) {
	return value;
}

/*
 * The XR build appliance still carries Node 12 while current LuCI sources use
 * optional chaining. Replace only the exact expressions present in this view
 * so the final installed file can be exercised by both the old local verifier
 * and modern CI Node versions. Any new optional-chain expression makes the
 * test fail instead of silently weakening coverage.
 */
function node12CompatibleSource(source) {
	const replacements = [
		[/mounts\.find\(m\s*=>\s*m\?\.mount\s*===\s*info\?\.DockerRootDir\)\?\.avail/g, '(mounts.find(m => (m == null ? undefined : m.mount) === (info == null ? undefined : info.DockerRootDir)) || {}).avail'],
		['info_response?.body?.message', '(info_response == null || info_response.body == null ? undefined : info_response.body.message)'],
		['c.NetworkSettings?.Networks', '(c.NetworkSettings == null ? undefined : c.NetworkSettings.Networks)'],
		['info_response?.code', '(info_response == null ? undefined : info_response.code)'],
		['version_response?.body', '(version_response == null ? undefined : version_response.body)'],
		['info_response?.body', '(info_response == null ? undefined : info_response.body)'],
		['ev?.currentTarget', '(ev == null ? undefined : ev.currentTarget)'],
		['info?.ContainersRunning', '(info == null ? undefined : info.ContainersRunning)'],
		['info?.Containers', '(info == null ? undefined : info.Containers)'],
		['info?.DockerRootDir', '(info == null ? undefined : info.DockerRootDir)'],
		['info?.code', '(info == null ? undefined : info.code)'],
		['getImagesInUseByContainers(container_list)?.size', '(getImagesInUseByContainers(container_list) || {}).size'],
		['getNetworksInUseByContainers(container_list)?.size', '(getNetworksInUseByContainers(container_list) || {}).size'],
		['getVolumesInUseByContainers(container_list)?.size', '(getVolumesInUseByContainers(container_list) || {}).size'],
		['volume_list?.Volumes', '(volume_list == null ? undefined : volume_list.Volumes)'],
		['m?.mount', '(m == null ? undefined : m.mount)']
	];

	let compatible = source;
	for (const [needle, replacement] of replacements) {
		compatible = typeof needle === 'string'
			? compatible.split(needle).join(replacement)
			: compatible.replace(needle, replacement);
	}

	if (compatible.includes('?.'))
		throw new Error('unhandled optional chaining in final Dockerman overview');

	return compatible;
}

const loadOverview = new Function(
	'dm2',
	'uci',
	'L',
	'_',
	'E',
	'window',
	`return (function() {\n${node12CompatibleSource(overviewSource)}\n})();`
);

const view = loadOverview(dm2, uci, L, translate, E, window);

async function renderCurrentState() {
	apiCalls.length = 0;
	const loaded = await view.load();
	const rendered = await view.render(loaded);
	return { loaded, rendered, calls: [...apiCalls] };
}

(async () => {
	const firstRun = await renderCurrentState();
	assert.deepEqual(firstRun.calls,
		['info', 'version', 'containers', 'images', 'networks', 'volumes', 'mounts'],
		'a running daemon must load every overview resource after one /info probe');
	assert.ok(firstRun.rendered instanceof TestNode,
		'the running state must render a DOM node');
	assert.equal(nodeByText(firstRun.rendered, 'h3', 'Docker is not running'), undefined,
		'the running state must not show the stopped-daemon warning');

	const summaryTable = nodes(firstRun.rendered, 'table').find(
		table => table.attrs.id === 'containers-table'
	);
	assert.ok(summaryTable, 'the running state must render the core summary table');
	assert.match(summaryTable.textContent, /29\.6\.1/);
	assert.match(summaryTable.textContent, /xr1710g-fixture/);
	assert.doesNotMatch(summaryTable.textContent, /Plugins|RegistryConfig|Containerd/);
	assert.doesNotMatch(summaryTable.textContent, /\{"Volume"|\[\["Backing Filesystem"/);

	const advanced = nodes(firstRun.rendered, 'details').find(
		detail => String(detail.attrs.class || '').includes('dockerman-advanced-info')
	);
	assert.ok(advanced, 'nested Moby 29 values must be available in a details block');
	assert.equal(Object.prototype.hasOwnProperty.call(advanced.attrs, 'open'), false,
		'the advanced Moby 29 block must be collapsed by default');

	const advancedEntries = nodes(advanced, 'details').filter(
		detail => String(detail.attrs.class || '').includes('dockerman-advanced-entry')
	);
	const advancedKeys = advancedEntries.map(detail => {
		const summaries = nodes(detail, 'summary');
		return summaries.length > 0 ? summaries[0].textContent : undefined;
	});
	for (const key of ['Containerd', 'DriverStatus', 'Plugins', 'RegistryConfig', 'Warnings'])
		assert.ok(advancedKeys.includes(key), `${key} must be represented as collapsed data`);

	const preformatted = nodes(advanced, 'pre');
	assert.ok(preformatted.length >= 5,
		'nested Docker values must be formatted in pre elements');
	assert.ok(preformatted.every(pre => (
		pre.attrs.style.includes('white-space: pre-wrap') &&
		pre.attrs.style.includes('overflow-wrap: anywhere') &&
		pre.attrs.style.includes('max-width: 100%')
	)), 'every nested value must wrap instead of widening the page');
	assert.ok(preformatted.some(pre => /\n  "Volume":/.test(pre.textContent)),
		'nested objects must use readable multi-line JSON');

	const stopButton = nodeByText(firstRun.rendered, 'button', 'Stop');
	assert.ok(stopButton && typeof stopButton.attrs.click === 'function',
		'the running state must expose the Docker stop action');
	await stopButton.attrs.click({ currentTarget: stopButton });
	assert.deepEqual(rcCalls.slice(-1), ['dockerd:stop']);

	const stopped = await renderCurrentState();
	assert.deepEqual(stopped.calls, ['info'],
		'a stopped daemon must not fan out failing Docker API requests');
	assert.ok(nodeByText(stopped.rendered, 'h3', 'Docker is not running'),
		'the stopped state must render a clear owner-facing heading');
	assert.match(stopped.rendered.textContent, /disabled by default/);
	assert.doesNotMatch(stopped.rendered.textContent, /Cannot connect to Docker socket/);

	const startButton = nodeByText(stopped.rendered, 'button', 'Enable and start Docker');
	assert.ok(startButton && typeof startButton.attrs.click === 'function',
		'the stopped state must expose its enable-and-start action');
	await startButton.attrs.click({ currentTarget: startButton });
	assert.deepEqual(rcCalls.slice(-2), ['dockerd:enable', 'dockerd:start']);
	assert.equal(startButton.disabled, true,
		'the enable-and-start button must remain disabled while reload is pending');
	assert.ok(notifications.length > 0,
		'a successful start must produce an owner-facing notification');
	const finalTimer = timers[timers.length - 1];
	assert.equal(finalTimer && finalTimer.delay, 3000,
		'a successful start must schedule the documented automatic refresh');
	finalTimer.callback();
	assert.equal(reloads, 1, 'the start refresh timer must reload the page');

	const restarted = await renderCurrentState();
	assert.deepEqual(restarted.calls,
		['info', 'version', 'containers', 'images', 'networks', 'volumes', 'mounts'],
		'a restarted daemon must return to the complete overview flow');
	assert.equal(nodeByText(restarted.rendered, 'h3', 'Docker is not running'), undefined);
	assert.ok(nodes(restarted.rendered, 'table').some(
		table => table.attrs.id === 'containers-table'
	), 'the running summary must return after a stop/start cycle');

	console.log('DOCKERMAN MOBY 29 DOM TEST PASSED');
})().catch(error => {
	console.error(error);
	process.exit(1);
});
