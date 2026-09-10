'use strict';
'require baseclass';
'require fs';
'require ui';

// This job survives the browser/RPC connection. Never silently retry start.
const helper = '/usr/libexec/xr1710g-upgrade';
const log = '/tmp/xr1710g-upgrade/output.log';
const text = (zh, en) => String(L.env.lang || '').startsWith('zh') ? zh : en;

function call(args) {
	return fs.exec(helper, args).then(res => {
		if (res.code !== 0)
			throw new Error(res.stderr || 'Upgrade control failed');
		return JSON.parse(res.stdout);
	});
}

function watch(initial, keep) {
	keep = initial.keep == null ? keep : !!initial.keep;
	let failures = 0;
	let pending = false;
	const message = E('p', { 'role': 'status', 'aria-live': 'polite' },
		text('正在校验、备份或刷写。请勿断电或重复提交；关闭网页不会取消升级。',
		'Validating, backing up or flashing. Do not power off or resubmit. Closing this page does not cancel the upgrade.'));
	ui.showModal(text('升级任务已提交', 'Upgrade task submitted'), [ message ]);
	const timer = window.setInterval(() => {
		if (pending) return;
		pending = true;
		call(['status']).then(job => {
			failures = 0;
			if (job.id !== initial.id) {
				window.clearInterval(timer);
				message.textContent = text('任务已改变或设备已重启。请重新登录检查固件版本。',
					'The job changed or the device rebooted. Log in again and check the firmware version.');
				return;
			}
			if (job.state === 'failed') {
				window.clearInterval(timer);
				message.textContent = text('升级准备失败，退出码：', 'Upgrade preparation failed, exit code: ') + job.code;
				fs.read(log).catch(() => '').then(details => {
					ui.showModal(text('升级失败', 'Upgrade failed'), [message,
						E('pre', { 'style': 'white-space:pre-wrap;overflow-wrap:anywhere;max-height:40vh;overflow:auto' }, details.slice(-8192)),
						E('p', {}, text('请先处理上述错误。不会自动重试或重启。', 'Resolve the error first. No automatic retry or reboot will occur.')),
						E('button', { 'class': 'btn', 'click': () => {
							call(['clear', job.id]).then(() => ui.hideModal()).catch(e => ui.addNotification(null, E('p', {}, e.message)));
						}}, text('确认并关闭', 'Acknowledge and close'))]);
				});
			}
			else if (job.state === 'unknown') {
				message.textContent = text('升级任务状态不明。请勿断电或重复刷写，先检查设备及升级日志。',
					'Upgrade state is unknown. Do not power off or resubmit; inspect the device and upgrade log first.');
			}
			else if (job.state === 'handoff') {
				window.clearInterval(timer);
				// A successful command return is a handoff, not proof of a new image.
				window.setTimeout(() => keep ? ui.awaitReconnect(window.location.host) :
					ui.awaitReconnect(window.location.host, '192.168.50.1', 'openwrt.lan'), 15000);
			}
		}).catch(() => {
			// A failed status RPC can mean shutdown, lost connectivity or an expired
			// login. It is not proof that preparation failed or flashing succeeded.
			if (++failures >= 2) {
				message.textContent = text('设备暂时无法响应，可能正在重启。请勿断电或再次刷写；待设备恢复后重新登录核对版本。',
					'The device is not responding and may be rebooting. Do not power off or flash again; log in and verify the version after it recovers.');
				window.clearInterval(timer);
				keep ? ui.awaitReconnect(window.location.host) :
					ui.awaitReconnect(window.location.host, '192.168.50.1', 'openwrt.lan');
			}
		}).finally(() => { pending = false; });
	}, 3000);
}

return baseclass.extend({
	guard() {
		return call(['status']).then(job => {
			if (job.state !== 'idle') {
				watch(job, true);
				throw new Error(text('已有升级任务，请先检查其状态。', 'An upgrade job already exists. Check its status first.'));
			}
		});
	},
	start(args, keep) {
		return call(['start', ...args]).then(job => watch(job, keep)).catch(e => {
			// Even a lost launch response does not authorize another launch.
			return call(['status']).then(job => {
				if (job.id) return watch(job, keep);
				throw e;
			}).catch(error => ui.showModal(text('升级尚未确认', 'Upgrade not confirmed'), [
				E('p', {}, text('未能确认升级任务状态。不要重复提交，请检查设备和日志。',
					'Unable to confirm the upgrade job. Do not resubmit; check the device and logs.')),
				E('pre', {}, error.message),
				E('button', { 'class': 'btn', 'click': ui.hideModal }, text('关闭', 'Close'))
			]));
		});
	}
});
