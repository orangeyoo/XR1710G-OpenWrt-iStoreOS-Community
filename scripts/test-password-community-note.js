'use strict';
// Execute the real LuCI render path with lightweight view/form fixtures.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const source = fs.readFileSync(process.argv[2], 'utf8');
for (const chinese of [false, true]) for (const hasHttpd of [false, true]) {
  let description;
  const option = { value: () => {}, depends: () => {} };
  const form = {
    JSONMap: function(data, title, desc) {
      description = desc;
      this.section = () => ({ option: () => ({ ...option }) });
      this.render = () => Promise.resolve({ description: desc });
    },
    Value: function() {}, NamedSection: {}, Flag: {}
  };
  const page = vm.runInNewContext('String.prototype.format = function(v) {return String(this).replace("%s", v);};\n(function(){' + source + '\n})()', {
    view: { extend: x => x },
    rpc: { declare: () => () => {} },
    form,
    L: { hasViewPermission: () => true },
    _: text => chinese && text === 'Firmware community QQ group: 1061612207'
      ? '本固件交流群 1061612207' : text,
    uci: { sections: (pkg, type, cb) => cb({ username: 'root' }) }, dom: {}, ui: {}, fs: {}, pwtool: {}
  });
  page.render([hasHttpd, ['root:x:0:0:root:/root:/bin/ash']]);
  assert(description.includes(chinese ? '本固件交流群 1061612207' : 'Firmware community QQ group: 1061612207'));
  assert(!description.includes('cbi-value-description'), 'Do not hijack the password strength element');
  assert(!description.includes('<input'), 'Community note must not be an account form field');
}
console.log('PASSWORD COMMUNITY NOTE RENDER TEST PASSED (zh/en)');
