// Offline LuCI module tests; no DOM/network/router or flashing is invoked.
const assert = require('assert').strict;
const fsNode = require('fs');
const source = fsNode.readFileSync(process.argv[2], 'utf8');
let tick, modal, reconnects, calls, failures, state, notifications;
const E = (tag, attrs, children) => ({tag, attrs, children, textContent:''});
const ui = {
 showModal: (title, body) => { modal = {title, body}; },
 hideModal: () => {},
 addNotification: (...v) => notifications.push(v),
 awaitReconnect: (...v) => reconnects.push(v)
};
const api = new Function('baseclass', 'fs', 'ui', 'L', 'E', 'window', source)(
 {extend:x=>x}, {
  exec: async (path, args) => {
   calls.push(args);
   if (failures) throw Error('simulated network loss');
   return {code:0,stdout:JSON.stringify(state)};
  }, read: async () => 'simulated backup failure'
 }, ui, {env:{lang:'zh-cn'}}, E,
 {setInterval:f=>{tick=f;return 1;},clearInterval:()=>{tick=null;},setTimeout:f=>f(),location:{host:'192.0.2.1'}}
);
const flush = () => new Promise(r=>setImmediate(r));
const reset = () => {calls=[];reconnects=[];notifications=[];failures=false;state={id:'test-id',state:'running',keep:1};};
(async () => {
 reset();
 await api.start(['--force','-u','-k'],true);
 assert.deepEqual(calls[0],['start','--force','-u','-k']);
 assert.equal(reconnects.length,0,'must not reconnect while backing up');
 state={id:'test-id',state:'failed',code:42,keep:1};
 tick(); await flush(); await flush();
 assert.equal(modal.title,'升级失败');
 assert.ok(JSON.stringify(modal).includes('42'));
 assert.equal(calls.filter(a=>a[0]==='start').length,1);
 assert.equal(reconnects.length,0);
 reset(); await api.start(['-n'],false);
 state={id:'test-id',state:'handoff',keep:0};
 tick(); await flush();
 // Initial keep is authoritative. Test normal no-config job separately.
 reset(); state.keep=0; await api.start(['-n'],false);
 state.state='handoff'; tick(); await flush();
 assert.ok(reconnects[0].includes('192.168.50.1'));
 assert.ok(!reconnects[0].includes('192.168.1.1'));
 reset(); await api.start([],true); failures=true;
 tick(); await flush(); tick(); await flush();
 assert.equal(calls.filter(a=>a[0]==='start').length,1,'network loss must not resubmit');
 assert.equal(reconnects.length,1);
 reset();
 await assert.rejects(api.guard());
 assert.equal(calls.filter(a=>a[0]==='start').length,0);
 reset(); state={state:'idle'}; await api.guard();
 console.log('PASS: argument forwarding, preparation wait, explicit failure, no retry, correct reset address, network loss, busy upload guard');
})().catch(e=>{console.error(e);process.exitCode=1;});
