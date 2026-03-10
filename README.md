# MTProto Proxy (Fake TLS) + Traefik

Один порт **443**: по SNI трафик к домену маскировки (например `1c.ru`) уходит в MTProxy, остальное можно отдавать другим сервисам через Traefik.

- **Telemt** — современный MTProxy (Rust, distroless), поддерживает Fake TLS.
- **Traefik** — маршрутизация TCP по SNI с TLS passthrough.

## Установка на сервере (всё тянется с GitHub)

```bash
curl -sSL https://raw.githubusercontent.com/LiaNdrY/mtproto-installer/main/install.sh | bash
```

Скрипт установит Docker (если нужно), скачает `docker-compose.yml`, конфиги Traefik и шаблон Telemt из репозитория [LiaNdrY/mtproto-installer](https://github.com/LiaNdrY/mtproto-installer), сгенерирует секрет, подставит домен маскировки и запустит контейнеры. В конце выведет ссылку вида `tg://proxy?server=...&port=443&secret=...` — добавьте её в Telegram (Настройки → Данные и память → Использовать прокси).

- Домен маскировки по умолчанию: `1c.ru`. Интерактивно можно ввести другой; без TTY: `FAKE_DOMAIN=sberbank.ru curl -sSL ... | bash`.
- Каталог установки по умолчанию: `./mtproxy-data`. Другой: `INSTALL_DIR=/opt/mtproxy curl -sSL ... | bash`.

## Локальный запуск (клонирование репозитория)

После `git clone https://github.com/LiaNdrY/mtproto-installer.git && cd mtproto-installer` можно запустить `./install.sh` — скрипт по умолчанию качает файлы с того же GitHub. Либо настроить вручную и поднять без скрипта:

1. Сгенерируйте секрет: `openssl rand -hex 16`. Скопируйте `telemt.toml.example` в `telemt.toml`, подставьте секрет и при необходимости домен в `censorship.tls_domain`.
2. В `traefik/dynamic/tcp.yml` домен в `HostSNI(...)` должен совпадать с `censorship.tls_domain` в `telemt.toml`.
3. Запуск: `docker compose up -d`.
4. Ссылка: `tg://proxy?server=ВАШ_IP&port=443&secret=ВАШ_СЕКРЕТ`.

## Полезные команды

- Логи: `docker compose logs -f`
- Остановка: `docker compose down`
- Перезапуск после смены конфига: `docker compose up -d --force-recreate`

## Безопасность

- Ссылку прокси не публикуйте.
- Рекомендуется порт 443 и домен маскировки с рабочим HTTPS (1c.ru, sberbank.ru и т.п.).
- Регулярно обновляйте образы: `docker compose pull && docker compose up -d`.

## Структура (после install.sh)

```text
mtproxy-data/
├── docker-compose.yml
├── telemt.toml
└── traefik/
    ├── dynamic/
    │   └── tcp.yml    # маршрут по SNI → telemt:1234
    └── static/
```

В репозитории те же файлы приведены как примеры для ручного развёртывания.
