'use strict';
'require rpc';
'require ui';
'require view';

var callStatus = rpc.declare({ object: 'luci.xr1710g_recovery', method: 'getStatus' });
var callUboot = rpc.declare({ object: 'luci.xr1710g_recovery', method: 'rebootToUboot' });
var callReset = rpc.declare({ object: 'luci.xr1710g_recovery', method: 'factoryReset' });

function actionButton(label, className, handler, disabled) {
	return E('button', {
		'class': 'cbi-button ' + className,
		'disabled': disabled ? 'disabled' : null,
		'click': handler
	}, label);
}

return view.extend({
	load: function() {
		return callStatus();
	},

	render: function(status) {
		var self = this;
		var oneShot = !!status.uboot_one_shot_supported;
		var sections = [ E('h2', {}, _('Recovery and Reset')) ];
		if (oneShot) {
			sections.push(E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Reboot to U-Boot Recovery')),
				E('p', {}, _('Sets a one-time recovery trigger and reboots. User configuration is not erased.')),
				actionButton(_('Reboot to U-Boot Recovery'), 'cbi-button-action', function() {
					return self.confirmUboot();
				}, false)
			]));
		}
		sections.push(E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('iStoreOS Factory Reset')),
				E('p', {}, _('Erases installed packages and all user configuration, then returns to the firmware defaults at 192.168.50.1. U-Boot, Factory, EEPROM and wireless calibration data are not changed.')),
				actionButton(_('Erase configuration and reboot'), 'cbi-button-negative', function() {
					return self.confirmReset();
				}, !status.factory_reset_supported)
			]));
		return E('div', { 'class': 'cbi-map' }, sections);
	},

	confirmUboot: function() {
		return ui.showModal(_('Reboot to U-Boot Recovery'), [
			E('p', {}, _('The router will become unavailable and should open its recovery service at 192.168.255.1. Continue?')),
			E('div', { 'class': 'right' }, [
				actionButton(_('Continue'), 'cbi-button-action', function() {
					ui.hideModal();
					return callUboot().then(function(res) {
						if (!res || !res.success)
							throw new Error(_('The installed U-Boot does not support the safe one-time trigger.'));
						ui.showModal(_('Rebooting…'), [ E('p', { 'class': 'spinning' }, _('Waiting for device…')) ]);
					});
				}), ' ', actionButton(_('Cancel'), 'cbi-button-neutral', ui.hideModal)
			])
		]);
	},

	confirmReset: function() {
		var self = this;
		return ui.showModal(_('Confirm factory reset'), [
			E('p', { 'class': 'alert-message warning' }, _('This permanently erases all user configuration and installed packages. Back up anything needed before continuing.')),
			E('label', {}, [
				E('input', { 'type': 'checkbox', 'id': 'xr-reset-confirm' }),
				' ', _('I understand that all configuration will be erased')
			]),
			E('div', { 'class': 'right' }, [
				actionButton(_('Erase and reboot'), 'cbi-button-negative', function() {
					var checkbox = document.getElementById('xr-reset-confirm');
					if (!checkbox || !checkbox.checked) {
						ui.addNotification(null, E('p', {}, _('Confirm the data-loss warning first.')));
						return;
					}
					ui.hideModal();
					return callReset().then(function(res) {
						if (!res || !res.success)
							throw new Error(_('Factory reset could not be started.'));
						ui.showModal(_('Resetting…'), [ E('p', { 'class': 'spinning' }, _('The router will restart at 192.168.50.1.')) ]);
					});
				}), ' ', actionButton(_('Cancel'), 'cbi-button-neutral', ui.hideModal)
			])
		]);
	}
});
