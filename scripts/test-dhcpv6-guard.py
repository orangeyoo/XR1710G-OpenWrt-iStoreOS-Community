#!/usr/bin/env python3
"""Offline regressions: no sockets, ubus calls, DHCP clients or UCI writes."""
import pathlib
import shlex
import subprocess
import sys

src = pathlib.Path(sys.argv[1]).resolve()
top = pathlib.Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else None
helper_path = src / 'files/lib/netifd/xr1710g-dhcpv6-guard.sh'
helper = helper_path.read_text().replace('. /lib/functions.sh', ': # fixture library')
count = 0

def shell(code, expected=0):
    global count
    p = subprocess.run(['sh', '-c', code], text=True, capture_output=True, timeout=5)
    assert p.returncode == expected, (count, p.returncode, p.stdout, p.stderr)
    count += 1
    return p.stdout

def config_fixture(rows):
    values = ''.join(f'{shlex.quote(k)}) value={shlex.quote(v)};;\n'
                     for k, v in rows.items())
    sections = sorted({k.split('.')[0] for k in rows})
    return '''
config_load() { return 0; }
config_get() {
 local value
 case "$2.$3" in
''' + values + '''*) value="${4-}";; esac
 export "$1=$value"
}
config_get_bool() { config_get "$@"; }
config_foreach() {
 local section
 for section in ''' + ' '.join(map(shlex.quote, sections)) + '''; do "$1" "$section" || :; done
}
'''

cases = [
    ({}, 1),
    ({'wan6.proto': 'dhcpv6', 'wan6.device': '@wan'}, 0),
    ({'custom.proto': 'dhcpv6', 'custom.ifname': 'pppoe-wan'}, 0),
    ({'custom.proto': 'dhcpv6', 'custom.device': '@alias', 'alias.device': '@wan'}, 0),
    ({'custom.proto': 'dhcpv6', 'custom.device': '@loop', 'loop.device': '@custom'}, 1),
    ({'other.proto': 'dhcpv6', 'other.device': '@wan2'}, 1),
    ({'wan6.proto': 'static', 'wan6.device': '@wan'}, 1),
    ({'wan6.proto': 'dhcpv6', 'wan6.device': '@wan', 'wan6.auto': '0'}, 1),
    ({'wan6.proto': 'dhcpv6', 'wan6.device': '@wan', 'wan6.disabled': '1'}, 1),
    ({'wan6.proto': 'dhcpv6', 'wan6.device': '@wan', 'wan6.disabled': '0'}, 0),
    ({'bad.proto': 'dhcpv6', 'bad.device': '@other',
      'good.proto': 'dhcpv6', 'good.device': '@wan'}, 0),
]
for rows, result in cases:
    shell(helper + config_fixture(rows) + '\nxr_dhcpv6_has_explicit wan pppoe-wan', result)
shell(helper + config_fixture(cases[1][0]) + '''
CONFIG_SECTIONS=unchanged
xr_dhcpv6_has_explicit wan pppoe-wan || exit 1
[ "$CONFIG_SECTIONS" = unchanged ]
''')

for device, owner, result in [('pppoe-wan', 'wan6', 0), ('pppoe-wan', 'wan_6', 1),
                              ('pppoe-other', 'wan6', 1), ('pppoe-wan', '', 1), ('', 'wan6', 1)]:
    shell(helper + f'''
xr_dhcpv6_pids() {{ echo 123; }}
xr_dhcpv6_device() {{ echo {shlex.quote(device)}; }}
xr_dhcpv6_owner() {{ echo {shlex.quote(owner)}; }}
xr_dhcpv6_conflict wan_6 pppoe-wan
''', result)
shell(helper + '\nxr_dhcpv6_pids() { :; }; xr_dhcpv6_conflict wan_6 pppoe-wan', 1)

if top:
    # Execute the real patched hook with only its external interfaces stubbed.
    ppp = (top / 'package/network/services/ppp/files/lib/netifd/ppp6-up').read_text()
    ppp = ppp.replace('. /lib/netifd/netifd-proto.sh', ':')
    ppp = ppp.replace('[ -d /etc/ppp/ip-up.d ]', 'false')
    ppp = ppp.replace('[ -r /lib/netifd/xr1710g-dhcpv6-guard.sh ]', 'true')
    ppp = ppp.replace('. /lib/netifd/xr1710g-dhcpv6-guard.sh', ':')
    stubs = '\n'.join(f'{f}() {{ :; }}' for f in (
        'proto_init_update', 'proto_set_keep', 'proto_add_ipv6_address', 'proto_send_update',
        'json_init', 'json_add_string', 'json_add_boolean', 'json_close_object', 'fw3'))
    for rows, skip in cases:
        output = shell(helper + config_fixture(rows) + stubs + '''
ubus() { echo CREATE_AUTO; }
json_dump() { echo '{}'; }
set -- one two three four five wan
IFNAME=pppoe-wan
AUTOIPV6=1
''' + ppp + '\nexit 0\n')
        assert ('CREATE_AUTO' in output) == bool(skip), rows
    # Actual DHCPv6 setup must stop ONLY the duplicate interface before export
    # or proto_run_command, and signal netifd to block the respawn loop.
    dhcp = (top / 'package/network/ipv6/odhcp6c/files/dhcpv6.sh').read_text()
    dhcp = '\n'.join(':' if line.startswith(('. ', 'init_proto ', 'add_protocol ')) else line
                     for line in dhcp.splitlines())
    dhcp = dhcp.replace('[ -r /lib/netifd/xr1710g-dhcpv6-guard.sh ]', 'true')
    dhcp = dhcp.replace('. /lib/netifd/xr1710g-dhcpv6-guard.sh', ':')
    output = shell(dhcp + '''
xr_dhcpv6_conflict() { return 0; }
logger() { :; }
proto_notify_error() { echo "ERROR:$*"; }
proto_block_restart() { echo "BLOCK:$*"; }
proto_run_command() { echo UNEXPECTED_START; }
proto_dhcpv6_setup wan_6 pppoe-wan
''', 1)
    assert output.splitlines() == ['ERROR:wan_6 DHCPV6_DUPLICATE_CLIENT', 'BLOCK:wan_6'], output

print(f'DHCPv6 guard: {count} offline cases PASS')
