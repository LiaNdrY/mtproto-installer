#!/usr/bin/env bash
# MTProto Proxy (Fake TLS) + Traefik — установка одной командой
# Все файлы загружаются с https://github.com/LiaNdrY/mtproto-installer
# Запуск на сервере: curl -sSL https://raw.githubusercontent.com/LiaNdrY/mtproto-installer/main/install.sh | bash

set -e

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/LiaNdrY/mtproto-installer/main}"
INSTALL_DIR="${INSTALL_DIR:-$(pwd)/mtproxy-data}"
FAKE_DOMAIN="${FAKE_DOMAIN:-1c.ru}"
TELEMT_INTERNAL_PORT="${TELEMT_INTERNAL_PORT:-1234}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR]${NC} $*"; exit 1; }

# --- Загрузка файла с GitHub
fetch() {
	local url="$1"
	local dest="$2"

	if ! curl -fsSL "$url" -o "$dest"; then
		err "Не удалось загрузить: $url"
	fi
}

# --- Проверка Docker
check_docker() {

	if command -v docker &>/dev/null; then
		if docker info &>/dev/null 2>&1; then
			info "Docker доступен."
		else
			warn "Docker установлен, но текущий пользователь не в группе docker."
			err "Запустите: sudo usermod -aG docker \$USER && newgrp docker"
		fi
	else
		info "Установка Docker..."
		curl -fsSL https://get.docker.com | sh
	fi

	if ! docker info &>/dev/null 2>&1; then
		err "Docker установлен, но недоступен. Выполните: sudo usermod -aG docker \$USER && newgrp docker"
	fi
}

# --- Определение Docker Compose
detect_compose() {

	if docker compose version >/dev/null 2>&1; then
		COMPOSE_CMD="docker compose"
	elif command -v docker-compose >/dev/null 2>&1; then
		COMPOSE_CMD="docker-compose"
	else
		err "Docker Compose не найден. Установите docker-compose-plugin или docker-compose."
	fi

	info "Используется: ${COMPOSE_CMD}"
}

# --- Запрос домена маскировки
prompt_fake_domain() {

	if [[ -n "${FAKE_DOMAIN_FROM_ENV}" ]]; then
		FAKE_DOMAIN="${FAKE_DOMAIN_FROM_ENV}"
		return
	fi

	if [[ -t 0 ]]; then
		echo -n "Домен для маскировки Fake TLS [${FAKE_DOMAIN}]: "
		read -r input
		[[ -n "$input" ]] && FAKE_DOMAIN="$input"
	fi
}

# --- Генерация секрета Telemt (32 hex = 16 bytes)
generate_secret() {
	openssl rand -hex 16
}

# --- Скачать конфиги и подставить параметры
download_and_configure() {

	info "Загрузка файлов из ${REPO_RAW} ..."

	mkdir -p "${INSTALL_DIR}/traefik/dynamic"
	mkdir -p "${INSTALL_DIR}/traefik/static"

	fetch "${REPO_RAW}/docker-compose.yml" "${INSTALL_DIR}/docker-compose.yml"
	fetch "${REPO_RAW}/traefik/dynamic/tcp.yml" "${INSTALL_DIR}/traefik/dynamic/tcp.yml"
	fetch "${REPO_RAW}/telemt.toml.example" "${INSTALL_DIR}/telemt.toml.example"

	SECRET=$(generate_secret)

	# telemt.toml
	sed -e "s/ПОДСТАВЬТЕ_32_СИМВОЛА_HEX/${SECRET}/g" \
	    -e "s/tls_domain = \"1c.ru\"/tls_domain = \"${FAKE_DOMAIN}\"/g" \
	    "${INSTALL_DIR}/telemt.toml.example" > "${INSTALL_DIR}/telemt.toml"

	rm -f "${INSTALL_DIR}/telemt.toml.example"

	info "Создан ${INSTALL_DIR}/telemt.toml (домен маскировки: ${FAKE_DOMAIN})"

	# Traefik TCP router
	local tcp_yml="${INSTALL_DIR}/traefik/dynamic/tcp.yml"

	sed -e "s/1c\.ru/${FAKE_DOMAIN}/g" \
	    -e "s/telemt:1234/telemt:${TELEMT_INTERNAL_PORT}/g" \
	    "$tcp_yml" > "${tcp_yml}.tmp"

	mv "${tcp_yml}.tmp" "$tcp_yml"

	info "Настроен Traefik: SNI ${FAKE_DOMAIN} -> telemt:${TELEMT_INTERNAL_PORT} (TLS passthrough)"

	echo "$SECRET" > "${INSTALL_DIR}/.secret"
}

# --- Запуск контейнеров
run_compose() {

	cd "${INSTALL_DIR}"

	${COMPOSE_CMD} pull -q 2>/dev/null || true
	${COMPOSE_CMD} up -d

	info "Контейнеры запущены."
}

# --- Вывод ссылки
print_link() {

	local SECRET
	SECRET=$(cat "${INSTALL_DIR}/.secret" 2>/dev/null || true)

	[[ -z "$SECRET" ]] && err "Секрет не найден"

	SERVER_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

	LINK="tg://proxy?server=${SERVER_IP}&port=8443&secret=${SECRET}"

	echo ""
	echo -e "${GREEN}--- Ссылка для Telegram ---${NC}"
	echo "${LINK}"
	echo ""
	echo "Сохраните ссылку и не публикуйте её публично."
	echo ""
	echo "Данные установки: ${INSTALL_DIR}"
	echo "Логи: cd ${INSTALL_DIR} && ${COMPOSE_CMD} logs -f"
	echo "Остановка: cd ${INSTALL_DIR} && ${COMPOSE_CMD} down"
}

# --- Main
main() {

	[[ "${INSTALL_DIR}" != /* ]] && INSTALL_DIR="$(pwd)/${INSTALL_DIR}"

	check_docker
	detect_compose
	prompt_fake_domain
	download_and_configure
	run_compose
	print_link
}

main "$@"
