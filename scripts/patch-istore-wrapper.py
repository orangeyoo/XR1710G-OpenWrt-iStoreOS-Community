#!/usr/bin/env python3
"""Apply the XR1710G package-safety policy to iStore's APK wrapper."""

from pathlib import Path
import sys


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one upstream anchor, found {count}")
    return text.replace(old, new, 1)


if len(sys.argv) != 2:
    raise SystemExit(f"usage: {sys.argv[0]} PATH-TO-is-opkg")

path = Path(sys.argv[1])
text = path.read_text()

# iStore contains meta and LuCI packages, while architecture dependencies come
# from this image's reviewed OpenWrt distfeeds. Never enable arbitrary feeds.
old_wrappers = (
    '    APK_CONFIG=${APK_CONF} apk "$@"',
    '    APK_CONFIG=${APK_CONF} apk --repositories-file /dev/null "$@"',
)
new_wrapper = (
    '    APK_CONFIG=${APK_CONF} apk '
    '--repositories-file ${SYSTEM_REPOSITORIES} "$@"'
)
if new_wrapper not in text:
    matches = [line for line in old_wrappers if line in text]
    if len(matches) != 1:
        raise SystemExit(
            f"APK wrapper: expected one reviewed upstream form, found {len(matches)}"
        )
    text = replace_once(text, matches[0], new_wrapper, "APK wrapper")

system_repo = '    SYSTEM_REPOSITORIES=/etc/apk/repositories.d/distfeeds.list\n'
if system_repo not in text:
    text = replace_once(
        text,
        '    APK_CONF=${IS_ROOT}/etc/apk.conf\n',
        '    APK_CONF=${IS_ROOT}/etc/apk.conf\n' + system_repo,
        "APK system repository declaration",
    )

preflight_marker = "Preflight dependency resolution failed; no packages were changed."
if preflight_marker not in text:
    text = replace_once(
        text,
        '''        apk_wrap "$action" "$@"
    else
        opkg_wrap "$action" "$@"
''',
        '''        case "$action" in
            add|upgrade)
                echo "Preflight dependency resolution"
                if ! apk_wrap "$action" --simulate "$@"; then
                    echo "Preflight dependency resolution failed; no packages were changed." >&2
                    return 1
                fi
            ;;
        esac
        apk_wrap "$action" "$@"
    else
        opkg_wrap "$action" "$@"
''',
        "direct APK transaction preflight",
    )
    text = replace_once(
        text,
        '''do_install_in_mirrors() {
    if $USE_APK; then
        apk_wrap_mirrors add "$@"
''',
        '''do_install_in_mirrors() {
    if $USE_APK; then
        echo "Preflight dependency resolution"
        if ! apk_wrap add --simulate "$@"; then
            echo "Preflight dependency resolution failed; no packages were changed." >&2
            return 1
        fi
        apk_wrap_mirrors add "$@"
''',
        "mirrored APK install preflight",
    )
    text = replace_once(
        text,
        '''do_upgrade_in_mirrors() {
    if $USE_APK; then
        apk_wrap_mirrors upgrade "$@"
''',
        '''do_upgrade_in_mirrors() {
    if $USE_APK; then
        echo "Preflight dependency resolution"
        if ! apk_wrap upgrade --simulate "$@"; then
            echo "Preflight dependency resolution failed; no packages were changed." >&2
            return 1
        fi
        apk_wrap_mirrors upgrade "$@"
''',
        "mirrored APK upgrade preflight",
    )

required = (
    new_wrapper,
    system_repo.rstrip(),
    'apk_wrap "$action" --simulate "$@"',
    'apk_wrap add --simulate "$@"',
    'apk_wrap upgrade --simulate "$@"',
    preflight_marker,
)
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit("iStore wrapper hardening incomplete: " + ", ".join(missing))

# Keep shell files LF-only even when this verifier is run from Windows.
with path.open("w", newline="\n") as stream:
    stream.write(text)
