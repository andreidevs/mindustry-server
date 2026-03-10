# Mindustry Server `v155.4` Beta в Docker

Конфигурация поднимает headless-сервер Mindustry `v155.4` Beta в Docker Compose и хранит все данные сервера в `./data`.

## Что внутри

- База: `eclipse-temurin:17-jre-jammy`
- Источник сервера: официальный `server-release.jar` из релиза `v155.4`
- Проверка артефакта по SHA-256 во время `docker compose build`
- Данные, карты, моды, сейвы и настройки лежат в `./data/config`

## Запуск

Docker Compose читает переменные из файла `.env`, если он существует в корне проекта. Пример значений есть в `.env.example`.

Запуск сервера:

```bash
docker compose up -d --build
```

Проверка конфигурации:

```bash
docker compose config
```

Просмотр логов:

```bash
docker compose logs -f
```

Остановка:

```bash
docker compose down
```

## Сетевые порты

Для публичного сервера откройте на firewall:

- `6567/tcp`
- `6567/udp`

Если меняете `SERVER_PORT`, откройте тот же порт для TCP и UDP.

## Управление через консоль

Контейнер запускается с `stdin_open: true` и `tty: true`, поэтому к консоли сервера можно подключиться так:

```bash
docker attach $(docker compose ps -q mindustry)
```

Полезные команды Mindustry:

- `help`
- `maps`
- `host`
- `status`
- `stop`

Для выхода из `docker attach` без остановки контейнера используйте стандартную последовательность Docker: `Ctrl-p`, затем `Ctrl-q`.

## Переменные окружения

Основные параметры задаются через `.env`:

- `MINDUSTRY_VERSION=v155.4`
- `MINDUSTRY_SHA256=cb96a68d2a9badf58a0640062607f953b1ed551ed7b4af0c2bf393d8ce8d6643`
- `JAVA_OPTS=-Xms512m -Xmx2G`
- `SERVER_NAME=Mindustry 155.4 Beta`
- `SERVER_DESC=Public beta server`
- `SERVER_PORT=6567`
- `SERVER_MODE=survival`
- `SERVER_MAP=`
- `SERVER_AUTO_HOST=true`
- `SERVER_AUTO_PAUSE=true`
- `SERVER_STRICT=true`
- `SERVER_EXTRA_COMMANDS=`

`SERVER_EXTRA_COMMANDS` передаётся как comma-separated список команд Mindustry, например:

```env
SERVER_EXTRA_COMMANDS=config autosave on,config autosaveSpacing 10
```

## Карты, моды и данные

После первого старта сервер создаст каталоги внутри `./data/config`.

- Карты: `./data/config/maps`
- Моды: `./data/config/mods`
- Сейвы, логи, настройки и админы тоже живут в `./data/config`

## Ограничение upstream

У команды `host` у headless-сервера нельзя выбрать случайную карту и одновременно передать произвольный режим кроме `survival`. Поэтому:

- если `SERVER_MAP` пустой и `SERVER_MODE=survival`, entrypoint запускает просто `host`
- если нужен другой режим, задайте `SERVER_MAP`
