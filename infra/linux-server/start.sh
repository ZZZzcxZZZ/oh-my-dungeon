#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Install Docker Engine and the Docker Compose plugin first." >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 is required." >&2
  exit 1
fi

set_env_value() {
  key=$1
  value=$2
  if grep -q "^${key}=" .env; then
    sed -i "s|^${key}=.*|${key}=${value}|" .env
  else
    printf '%s=%s\n' "$key" "$value" >> .env
  fi
}

generate_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    dd if=/dev/urandom bs=32 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n'
  fi
}

# 探测本机公网 IP；云服务器上 hostname -I 只返回内网地址，会导致
# /.well-known/dnd-tool-server 向客户端广播一个不可达的地址。
detect_public_ip() {
  for url in https://ifconfig.me https://api.ipify.org https://ip.sb; do
    ip=$(curl --fail --silent --max-time 4 "$url" 2>/dev/null || true)
    case "$ip" in
      [0-9]*.[0-9]*.[0-9]*.[0-9]*)
        printf '%s' "$ip"
        return 0
        ;;
    esac
  done
  return 1
}

# 从 .env 读取 PUBLIC_BASE_URL（去引号）
get_public_base_url() {
  grep '^PUBLIC_BASE_URL=' .env 2>/dev/null | head -n1 \
    | sed 's/^PUBLIC_BASE_URL=//; s/^"//; s/"$//'
}

# 每次启动检查 PUBLIC_BASE_URL 是否仍是 localhost / 空；若是则告警并给出候选地址。
# 不自动覆盖用户手动设置的值（可能是有意配置的域名或反代地址）。
warn_public_base_url() {
  current=$(get_public_base_url)
  case "$current" in
    ''|http://localhost*|http://127.0.0.1*|https://localhost*|https://127.0.0.1*)
      echo "------------------------------------------------------------" >&2
      echo "WARNING: PUBLIC_BASE_URL is '${current:-<empty>}'." >&2
      echo "Clients on other devices (phones, other machines) will be told" >&2
      echo "to use this address via /.well-known/dnd-tool-server and will" >&2
      echo "NOT be able to reach the API." >&2
      echo "Candidate addresses:" >&2
      pub=$(detect_public_ip || true)
      [ -n "$pub" ] && echo "  public IP : http://${pub}:3000" >&2
      lan=$(hostname -I 2>/dev/null | awk '{print $1}')
      [ -n "$lan" ] && echo "  LAN IP    : http://${lan}:3000" >&2
      echo "Edit .env, set PUBLIC_BASE_URL to the address clients will use," >&2
      echo "then re-run: ./start.sh" >&2
      echo "------------------------------------------------------------" >&2
      ;;
  esac
}

# 首次启动：从 .env.example 创建 .env，并自动生成随机密钥/密码
if [ ! -f .env ]; then
  cp .env.example .env
  set_env_value JWT_SECRET "$(generate_secret)"
  set_env_value POSTGRES_PASSWORD "$(generate_secret)"
  # 优先用公网 IP（云服务器场景）；取不到再退回内网 IP
  detected_ip=$(detect_public_ip || true)
  [ -z "$detected_ip" ] && detected_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [ -n "$detected_ip" ]; then
    set_env_value PUBLIC_BASE_URL "http://${detected_ip}:3000"
  fi
fi

# 兜底：如果旧 .env 里 POSTGRES_PASSWORD 还是占位值，替换为随机密码
if grep -q '^POSTGRES_PASSWORD="change-me"' .env 2>/dev/null \
  || grep -q '^POSTGRES_PASSWORD=change-me$' .env 2>/dev/null; then
  set_env_value POSTGRES_PASSWORD "$(generate_secret)"
fi

# 兜底：如果旧 .env 里 JWT_SECRET 还是占位值，替换为随机密钥
if grep -q '^JWT_SECRET="change-me"' .env 2>/dev/null \
  || grep -q '^JWT_SECRET=change-me$' .env 2>/dev/null; then
  set_env_value JWT_SECRET "$(generate_secret)"
fi

warn_public_base_url

if [ -f server-image.tar.gz ]; then
  if [ ! -f server-image.ref ]; then
    echo "server-image.ref is missing from the prebuilt package." >&2
    exit 1
  fi
  image_ref=$(tr -d '\r\n' < server-image.ref)
  case "$image_ref" in
    ''|*[!a-zA-Z0-9._:/-]*)
      echo "Invalid server image reference in server-image.ref." >&2
      exit 1
      ;;
  esac
  docker load -i server-image.tar.gz
  docker image inspect "$image_ref" >/dev/null
  set_env_value SERVER_IMAGE "$image_ref"
  docker compose up -d --no-build
else
  docker compose up -d --build
fi

attempt=1
while [ "$attempt" -le 30 ]; do
  if curl --fail --silent --show-error http://127.0.0.1:3000/health >/dev/null; then
    echo "OhMyDungeon server is ready."
    grep '^PUBLIC_BASE_URL=' .env
    exit 0
  fi
  attempt=$((attempt + 1))
  sleep 2
done

echo "The server did not become healthy. Run: docker compose logs --tail=200 server" >&2
exit 1
