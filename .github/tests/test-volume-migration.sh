#!/bin/bash
# Run against a locally built image: bash .github/tests/test-volume-migration.sh IMAGE
set -euo pipefail
image=${1:?Pass the local image tag}

# The main WeChat window can open even when its search renderer cannot load.
renderer_deps=$(docker run --rm --network none --user 1000:100 --env LC_ALL=C \
    --entrypoint ldd "$image" /opt/wechat/RadiumWMPF/runtime/WeChatAppEx.bin)
if grep -F 'not found' <<< "$renderer_deps" >&2; then
    exit 1
fi

work=$(mktemp -d)
volume=$(docker volume create)
container=
cleanup() {
    if [[ -n $container ]]; then docker rm -f "$container" >/dev/null; fi
    docker volume rm "$volume" >/dev/null
    rm -r "$work"
}
trap cleanup EXIT
cat > "$work/check" <<'CHECK'
#!/bin/bash
set -eu
[[ $(id -u):$(id -g) == "$EXPECT_IDS" ]]
[[ $SELKIES_BASIC_AUTH_PASSWORD == "$(< /run/test-password)" && $SELKIES_ENABLE_BASIC_AUTH == true ]]
[[ $SELKIES_PORT == 7310 && $SELKIES_HTTPS_PORT == 7311 ]]
[[ $(cat /config/.config/private-marker) == old-profile ]]
touch /config/.config/write-marker
CHECK
chmod 755 "$work/check"
python3 -c 'import secrets; print(secrets.token_hex(16))' > "$work/password"
chmod 444 "$work/password"

admin() {
    docker run --rm --network none --entrypoint /bin/bash -v "$volume:/config" "$image" -ec "$1"
}
migrate() {
    docker run --rm --network none --group-add 100 -v "$volume:/config" \
        -v "$work/check:/etc/container-entrypoint.sh:ro" -v "$work/password:/run/test-password:ro" \
        -e FILE__PASSWORD=/run/test-password -e CUSTOM_PORT=7310 -e CUSTOM_HTTPS_PORT=7311 \
        -e SELKIES_ENABLE_BASIC_AUTH=false -e EXPECT_IDS=911:911 "$@" "$image"
}

# With no IDs configured, docker run uses 911:911 even when xwechat_files
# belongs to 1000 and the session accesses it through a shared group.
# The unrelated file belongs to the image's original UID: usermod must not
# reassign it when remapping the session from 1000 to 911.
admin 'mkdir -p /config/.config /config/xwechat_files; echo old-profile > /config/.config/private-marker
       chown 1000:100 /config/xwechat_files; chmod 2770 /config/xwechat_files
       chown -R 911:911 /config/.config; chmod 700 /config/.config; chmod 600 /config/.config/private-marker
       touch /config/unrelated; chown 1000:100 /config/unrelated; chmod 640 /config/unrelated
       chown 0:0 /config'
migrate
migrate -e PGID=2345 -e EXPECT_IDS=911:2345
# A custom maximize-all rule alone is intentional. Only the old project's
# combination of that wildcard and its later WeChat exception needs reordering.
rc=/config/.config/openbox/rc.xml
admin "printf '%s\n' '<openbox_config><applications>' '<application class=\"*\"><maximized>yes</maximized></application>' '</applications></openbox_config>' > $rc
       chown 911:911 $rc"
custom_before=$(admin "sha256sum $rc")
migrate -e PUID=911 -e PGID=911
[[ $(admin "sha256sum $rc") == "$custom_before" ]]
admin "sed -i '/<\/applications>/i\  <application class=\"wechat\"><maximized>no</maximized></application>' $rc
       chown 911:911 $rc"
if migrate -e PUID=1000 -e PGID=1000 >"$work/error" 2>&1; then
    echo 'Inaccessible old profile accepted' >&2; exit 1
fi
grep -q 'cannot use /config/.config' "$work/error"
admin 'test "$(stat -c %u:%g /config)" = 911:911
       test "$(stat -c %u:%g:%a /config/xwechat_files)" = 1000:100:2770
       test "$(stat -c %u:%g:%a /config/.config/private-marker)" = 911:911:600
       test "$(stat -c %u:%g:%a /config/unrelated)" = 1000:100:640'

# All paths here belong to the disposable test volume.
admin 'chown -R 1234:2345 /config/.config; chown 1234:2345 /config'
migrate -e EXPECT_IDS=1234:911 -e PUID=1234
admin 'chown 0:3456 /config; chmod 2750 /config'
migrate -e EXPECT_IDS=1234:2345 -e PUID=1234 -e PGID=2345
admin "test \"\$(grep -c 'Pelorus fixed-size windows' $rc)\" = 1"
admin 'test "$(stat -c %u:%g:%a /config)" = 1234:3456:2750'

# An old Compose deployment may keep a read-only archive next to its active account.
admin 'mkdir -p /config/xwechat_files/{current,archive}
       chown -R 1000:100 /config/.config /config/xwechat_files
       chmod 700 /config/xwechat_files/current; chmod 500 /config/xwechat_files/archive'
archive_before=$(admin 'stat -c %u:%g:%a /config/xwechat_files/archive')
migrate -e EXPECT_IDS=1000:100 -e PUID=1000 -e PGID=100

# Start the real desktop with the old Compose identity and the same private volume.
# Keep default Docker security settings to catch renderer sandbox regressions.
container=$(docker run -d --network none --shm-size 1g -v "$volume:/config" \
    -v "$work/password:/run/test-password:ro" -e SELKIES_BASIC_AUTH_PASSWORD_FILE=/run/test-password -e PASSWORD= \
    -e PUID=1000 -e PGID=100 -e CUSTOM_USER=migration -e ENABLE_WECHAT_AUTO_LOGIN=false \
    -e SELKIES_ENABLE_DUAL_MODE=false "$image")
api=(docker exec "$container" curl -ks --max-time 2)
desktop=https://localhost:3001/api/pelorus/desktop
for ((attempt=0; attempt<60; attempt++)); do
    if response=$("${api[@]}" -f -u "migration:$(< "$work/password")" "$desktop") &&
        python3 -c 'import json, sys
windows = json.load(sys.stdin)["windows"]
sys.exit(not any(w["app_id"].lower() == "wechat" and w["mapped"] for w in windows))' <<< "$response" &&
        docker exec "$container" pgrep -f \
            '^/opt/wechat/RadiumWMPF/runtime/WeChatAppEx[.]bin .*--utility-sub-type=network[.]mojom[.]NetworkService ' >/dev/null; then
        break
    fi
    sleep 1
done
if (( attempt == 60 )); then
    echo 'WeChat desktop or embedded browser did not start' >&2
    exit 1
fi
[[ $("${api[@]}" -o /dev/null -w '%{http_code}' "$desktop") == 401 ]]
admin 'test "$(stat -c %u:%g:%a /config/.config/private-marker)" = 1000:100:600
       test "$(cat /config/.config/private-marker)" = old-profile'
[[ $(admin 'stat -c %u:%g:%a /config/xwechat_files/archive') == "$archive_before" ]]
echo 'Volume migration checks passed'
