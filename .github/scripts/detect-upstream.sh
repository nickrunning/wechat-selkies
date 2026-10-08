#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="${STATE_FILE:-versions/upstream.env}"
TMP_DIR="$(mktemp -d)"
CHANGE_DETECTED="false"
DOWNLOADED_URL=""
ENV_WECHAT_AMD64_URL="${WECHAT_AMD64_URL-__UNSET__}"
ENV_WECHAT_ARM64_URL="${WECHAT_ARM64_URL-__UNSET__}"
ENV_QQ_AMD64_URL="${QQ_AMD64_URL-__UNSET__}"
ENV_QQ_ARM64_URL="${QQ_ARM64_URL-__UNSET__}"

DEFAULT_WECHAT_AMD64_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb"
DEFAULT_WECHAT_ARM64_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.deb"
DEFAULT_QQ_AMD64_URL="https://qqdl.gtimg.cn/qqfile/QQNT/9.9.33/release/c97651b2/QQ_3.2.32_260730_amd64_01.deb"
DEFAULT_QQ_ARM64_URL="https://qqdl.gtimg.cn/qqfile/QQNT/9.9.33/release/c97651b2/QQ_3.2.32_260730_arm64_01.deb"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

if [[ -f "$STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

# Keep the tracked URLs before overrides and discovery replace them.
PREVIOUS_WECHAT_AMD64_URL="${WECHAT_AMD64_URL:-}"
PREVIOUS_WECHAT_ARM64_URL="${WECHAT_ARM64_URL:-}"
PREVIOUS_QQ_AMD64_URL="${QQ_AMD64_URL:-}"
PREVIOUS_QQ_ARM64_URL="${QQ_ARM64_URL:-}"

if [[ "$ENV_WECHAT_AMD64_URL" != "__UNSET__" ]]; then
  WECHAT_AMD64_URL="$ENV_WECHAT_AMD64_URL"
fi

if [[ "$ENV_WECHAT_ARM64_URL" != "__UNSET__" ]]; then
  WECHAT_ARM64_URL="$ENV_WECHAT_ARM64_URL"
fi

if [[ "$ENV_QQ_AMD64_URL" != "__UNSET__" ]]; then
  QQ_AMD64_URL="$ENV_QQ_AMD64_URL"
fi

if [[ "$ENV_QQ_ARM64_URL" != "__UNSET__" ]]; then
  QQ_ARM64_URL="$ENV_QQ_ARM64_URL"
fi

# Dynamically fetch latest QQ URLs from official CDN config if unset
fetch_qq_urls() {
  if [[ "$ENV_QQ_AMD64_URL" != "__UNSET__" && "$ENV_QQ_ARM64_URL" != "__UNSET__" ]]; then
    return
  fi

  local qq_config
  if ! qq_config="$(curl -fsSL --connect-timeout 10 --max-time 30 --retry 2 --retry-delay 3 https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/linuxConfig.js)"; then
    echo "::warning::Failed to fetch the official QQ configuration; using tracked package URLs." >&2
    return
  fi
  if [[ -n "$qq_config" ]]; then
    local fetched_amd64 fetched_arm64
    fetched_amd64="$(echo "$qq_config" | grep -oE 'https://[^"]+amd64[^"]+\.deb' | head -n 1 || true)"
    fetched_arm64="$(echo "$qq_config" | grep -oE 'https://[^"]+arm64[^"]+\.deb' | head -n 1 || true)"
    if [[ -n "$fetched_amd64" && "$ENV_QQ_AMD64_URL" == "__UNSET__" ]]; then
      QQ_AMD64_URL="$fetched_amd64"
    fi
    if [[ -n "$fetched_arm64" && "$ENV_QQ_ARM64_URL" == "__UNSET__" ]]; then
      QQ_ARM64_URL="$fetched_arm64"
    fi
  fi
}

fetch_qq_urls

WECHAT_AMD64_URL="${WECHAT_AMD64_URL:-$DEFAULT_WECHAT_AMD64_URL}"
WECHAT_ARM64_URL="${WECHAT_ARM64_URL:-$DEFAULT_WECHAT_ARM64_URL}"
QQ_AMD64_URL="${QQ_AMD64_URL:-$DEFAULT_QQ_AMD64_URL}"
QQ_ARM64_URL="${QQ_ARM64_URL:-$DEFAULT_QQ_ARM64_URL}"

download_package() {
  local source_path="$1"
  local destination="$2"
  shift 2
  local candidate attempted_url already_attempted
  local -a attempted_urls=()

  for candidate in "$source_path" "$@"; do
    [[ -n "$candidate" ]] || continue
    already_attempted="false"
    for attempted_url in "${attempted_urls[@]}"; do
      if [[ "$candidate" == "$attempted_url" ]]; then
        already_attempted="true"
        break
      fi
    done
    [[ "$already_attempted" == "false" ]] || continue
    attempted_urls+=("$candidate")

    case "$candidate" in
      http://*|https://*)
        # Retry transient failures, but move on immediately for HTTP 403/404.
        if ! curl --fail --silent --show-error --location \
          --connect-timeout 30 --max-time 600 \
          --retry 3 --retry-delay 5 --retry-connrefused \
          -o "$destination" "$candidate"; then
          echo "::warning::Failed to download ${candidate}; trying the next package URL." >&2
          continue
        fi
        ;;
      *)
        if ! cp "$candidate" "$destination"; then
          echo "::warning::Failed to copy ${candidate}; trying the next package URL." >&2
          continue
        fi
        ;;
    esac

    if ! dpkg-deb --info "$destination" >/dev/null 2>&1; then
      echo "::warning::Invalid Debian package from ${candidate}; trying the next package URL." >&2
      continue
    fi

    DOWNLOADED_URL="$candidate"
    if [[ "$candidate" != "$source_path" ]]; then
      echo "::warning::Using fallback package from ${candidate} instead of ${source_path}." >&2
    fi
    return 0
  done

  echo "::error::Failed to download a valid package from all configured URLs for ${source_path}." >&2
  return 1
}

read_metadata() {
  local package_name="$1"
  local arch="$2"
  local source_path="$3"
  shift 3
  local package_path="$TMP_DIR/${package_name}-${arch}.deb"
  local version_var="${package_name}_${arch}_VERSION"
  local sha_var="${package_name}_${arch}_SHA256"
  local url_var="${package_name}_${arch}_URL"
  local current_version="${!version_var:-}"
  local current_sha="${!sha_var:-}"
  local previous_url_var="PREVIOUS_${url_var}"
  local current_url="${!previous_url_var:-}"
  local detected_version
  local detected_sha

  echo "Checking ${package_name} ${arch} from ${source_path}"
  download_package "$source_path" "$package_path" "$@"

  detected_version="$(dpkg-deb -f "$package_path" Version)"
  detected_sha="$(sha256sum "$package_path" | awk '{print $1}')"

  printf -v "$version_var" '%s' "$detected_version"
  printf -v "$sha_var" '%s' "$detected_sha"
  printf -v "$url_var" '%s' "$DOWNLOADED_URL"

  if [[ "$current_version" != "$detected_version" || "$current_sha" != "$detected_sha" || "$current_url" != "$DOWNLOADED_URL" ]]; then
    CHANGE_DETECTED="true"
  fi
}

read_metadata "WECHAT" "AMD64" "$WECHAT_AMD64_URL" "$PREVIOUS_WECHAT_AMD64_URL" "$DEFAULT_WECHAT_AMD64_URL"
read_metadata "WECHAT" "ARM64" "$WECHAT_ARM64_URL" "$PREVIOUS_WECHAT_ARM64_URL" "$DEFAULT_WECHAT_ARM64_URL"
read_metadata "QQ" "AMD64" "$QQ_AMD64_URL" "$PREVIOUS_QQ_AMD64_URL" "$DEFAULT_QQ_AMD64_URL"
read_metadata "QQ" "ARM64" "$QQ_ARM64_URL" "$PREVIOUS_QQ_ARM64_URL" "$DEFAULT_QQ_ARM64_URL"

CHECKED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
if [[ "$CHANGE_DETECTED" == "true" || ! -f "$STATE_FILE" ]]; then
  WECHAT_LAST_CHECKED_AT="$CHECKED_AT"
  QQ_LAST_CHECKED_AT="$CHECKED_AT"
fi

NEW_STATE_FILE="$TMP_DIR/upstream.env"
cat > "$NEW_STATE_FILE" <<EOF
# Upstream package state tracked by automation.

WECHAT_AMD64_URL="$WECHAT_AMD64_URL"
WECHAT_ARM64_URL="$WECHAT_ARM64_URL"

WECHAT_AMD64_VERSION="${WECHAT_AMD64_VERSION:-}"
WECHAT_ARM64_VERSION="${WECHAT_ARM64_VERSION:-}"

WECHAT_AMD64_SHA256="${WECHAT_AMD64_SHA256:-}"
WECHAT_ARM64_SHA256="${WECHAT_ARM64_SHA256:-}"

WECHAT_LAST_CHECKED_AT="${WECHAT_LAST_CHECKED_AT:-}"

QQ_AMD64_URL="$QQ_AMD64_URL"
QQ_ARM64_URL="$QQ_ARM64_URL"

QQ_AMD64_VERSION="${QQ_AMD64_VERSION:-}"
QQ_ARM64_VERSION="${QQ_ARM64_VERSION:-}"

QQ_AMD64_SHA256="${QQ_AMD64_SHA256:-}"
QQ_ARM64_SHA256="${QQ_ARM64_SHA256:-}"

QQ_LAST_CHECKED_AT="${QQ_LAST_CHECKED_AT:-}"
EOF

mkdir -p "$(dirname "$STATE_FILE")"
if [[ ! -f "$STATE_FILE" ]] || ! cmp -s "$NEW_STATE_FILE" "$STATE_FILE"; then
  cp "$NEW_STATE_FILE" "$STATE_FILE"
fi

echo "Change detected: $CHANGE_DETECTED"
echo "WECHAT_AMD64_VERSION=${WECHAT_AMD64_VERSION:-}"
echo "WECHAT_ARM64_VERSION=${WECHAT_ARM64_VERSION:-}"
echo "QQ_AMD64_VERSION=${QQ_AMD64_VERSION:-}"
echo "QQ_ARM64_VERSION=${QQ_ARM64_VERSION:-}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "changed=$CHANGE_DETECTED"
    echo "wechat_amd64_version=${WECHAT_AMD64_VERSION:-}"
    echo "wechat_arm64_version=${WECHAT_ARM64_VERSION:-}"
    echo "qq_amd64_version=${QQ_AMD64_VERSION:-}"
    echo "qq_arm64_version=${QQ_ARM64_VERSION:-}"
    echo "state_file=$STATE_FILE"
  } >> "$GITHUB_OUTPUT"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Upstream Detection"
    echo ""
    echo "- Changed: \`$CHANGE_DETECTED\`"
    echo "- WeChat amd64: \`${WECHAT_AMD64_VERSION:-}\`"
    echo "- WeChat arm64: \`${WECHAT_ARM64_VERSION:-}\`"
    echo "- QQ amd64: \`${QQ_AMD64_VERSION:-}\`"
    echo "- QQ arm64: \`${QQ_ARM64_VERSION:-}\`"
    echo "- State file: \`$STATE_FILE\`"
  } >> "$GITHUB_STEP_SUMMARY"
fi
