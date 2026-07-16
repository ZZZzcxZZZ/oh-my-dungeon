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

# 首次启动：从 .env.example 创建 .env，并自动生成随机密钥/密码
if [ ! -f .env ]; then
  cp .env.example .env
  set_env_value JWT_SECRET "$(generate_secret)"
  set_env_value POSTGRES_PASSWORD "$(generate_secret)"
  host_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [ -n "$host_ip" ]; then
    set_env_value PUBLIC_BASE_URL "http://${host_ip}:3000"
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

docker compose up -d --build

attempt=1
while [ "$attempt" -le 30 ]; do
  if curl --fail --silent --show-error http://127.0.0.1:3000/health >/dev/null; then
    echo "D&D Table server is ready."
    grep '^PUBLIC_BASE_URL=' .env
    exit 0
  fi
  attempt=$((attempt + 1))
  sleep 2
done

echo "The server did not become healthy. Run: docker compose logs --tail=200 server" >&2
exit 1
