# Mindustry Server `v155.4` Beta в Docker

Конфигурация поднимает headless-сервер Mindustry `v155.4` Beta в Docker Compose и хранит все данные сервера в `./data`.

## Что внутри

- База: `eclipse-temurin:17-jdk-jammy`
- Источник сервера: официальный `server-release.jar` из релиза `v155.4`
- Проверка артефакта по SHA-256 во время `docker compose build`
- Данные инстанса лежат в `${SERVER_WORKDIR}/config`, для текущего основного сервера это по умолчанию `./data/config`

## Запуск

По умолчанию Docker Compose использует файл `.env` из корня проекта. Шаблон значений лежит в `.env.example`. Для дополнительных инстансов можно передавать другой env-файл через `--env-file`.

Запуск обоих серверов из `docker-compose.yml`:

```bash
docker compose up -d --build
```

Запуск только первого сервера:

```bash
docker compose up -d --build mindustry
```

Запуск только второго сервера:

```bash
docker compose up -d --build mindustry-2
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
- `6568/tcp`
- `6568/udp`

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

Основные параметры задаются через `.env` или через альтернативный файл, переданный в `docker compose --env-file ...`:

- `MINDUSTRY_VERSION=v155.4`
- `MINDUSTRY_SHA256=cb96a68d2a9badf58a0640062607f953b1ed551ed7b4af0c2bf393d8ce8d6643`
- `JAVA_OPTS=-Xms512m -Xmx2G`
- `SERVER_WORKDIR=/data`
- `SERVER_NAME=Mindustry 155.4 Beta`
- `SERVER_DESC=Public beta server`
- `SERVER_PORT=6567`
- `SERVER_MODE=survival`
- `SERVER_MAP=Tar_Fields`
- `SERVER_AUTO_HOST=true`
- `SERVER_AUTO_PAUSE=true`
- `SERVER_STRICT=true`
- `SERVER_BOOTSTRAP_MODE=auto`
- `SERVER_BOOTSTRAP_SAVE_SLOT=222`
- `SERVER_EXTRA_COMMANDS=`
- `ENABLE_EXOGENESIS=true`
- `ENABLE_NEW_HORIZON=false`
- `NEW_HORIZON_VERSION=2.0_v154_1`
- `NEW_HORIZON_URL=https://github.com/Yuria-Shikibe/NewHorizonMod/releases/download/2.0_v154_1/NewHorizonMod.2.0_v154_1.jar`
- `NEW_HORIZON_SHA256=052545941e5a306b2ca03cb80e90d4138efc4d78db21c44138dd55e5830d0003`

`SERVER_EXTRA_COMMANDS` передаётся как comma-separated список команд Mindustry, например:

```env
SERVER_EXTRA_COMMANDS=config autosave on,config autosaveSpacing 10
```

`SERVER_BOOTSTRAP_MODE=auto` меняет порядок старта сервера:

- если в `${SERVER_WORKDIR}/config/saves` уже есть `auto_*.msav`, entrypoint выполнит `loadautosave`
- если autosave ещё нет, но в образ включён seed-сейв, entrypoint выполнит `load <slot>`
- если ни autosave, ни seed-сейва нет, entrypoint вернётся к обычному `host <map> <mode>`

`SERVER_BOOTSTRAP_SAVE_SLOT` опционален. Если он не указан и в образ включён ровно один seed-сейв, слот определится автоматически по имени файла без `.msav`.

## Карты, моды и данные

После первого старта сервер создаст каталог `${SERVER_WORKDIR}/config`.

- Для текущего основного сервера при `SERVER_WORKDIR=/data` это будет `./data/config`
- Для второго инстанса с `SERVER_WORKDIR=/data/instances/server-2` это будет `./data/instances/server-2/config`
- Карты: `${SERVER_WORKDIR}/config/maps`
- Моды: `${SERVER_WORKDIR}/config/mods`
- Сейвы: `${SERVER_WORKDIR}/config/saves`
- Сейвы, логи, настройки и админы тоже живут в `${SERVER_WORKDIR}/config`

Если положить `.msav` в `docker/seeds/saves`, этот файл попадёт внутрь Docker image и на первом старте будет автоматически скопирован в `${SERVER_WORKDIR}/config/saves`. Это удобно для удалённого сервера: достаточно закоммитить seed-сейв в репозиторий, сделать `git pull` и `docker compose up -d --build`, без отдельного `scp` на машину.

Если `ENABLE_NEW_HORIZON=true`, entrypoint автоматически скачает зафиксированный релиз New Horizon в `${SERVER_WORKDIR}/config/mods`, проверит его SHA-256 и затем применит локальный headless-патч для dedicated-сервера.

Для `SERVER_MAP=Tar_Fields` entrypoint автоматически извлекает встроенную campaign-карту `Tar Fields` из `server-release.jar` в `${SERVER_WORKDIR}/config/maps`. Это нужно, потому что у headless-сервера такая карта не хостится напрямую как встроенная.

Если `ENABLE_EXOGENESIS=true`, entrypoint автоматически скачает зафиксированный snapshot `Exogenesis` в `${SERVER_WORKDIR}/config/mods/exogenesis` и сервер снова будет требовать этот мод у клиентов.

## Несколько инстансов без потери прогресса

Текущий сервер можно оставить как есть: он продолжит использовать `./data/config`, и его прогресс не потеряется.

В `docker-compose.yml` уже добавлен второй сервис `mindustry-2`:

- `mindustry` использует `./data/config`, порт `6567`, карту из `SERVER_MAP`
- `mindustry-2` использует `./data/instances/server-2/config`, порт `6568`, карту из `SERVER2_MAP`

Для каждого нового сервера нужны три уникальные вещи:

- отдельный `SERVER_WORKDIR`
- отдельный `SERVER_PORT`
- отдельный project name у Docker Compose

Пример для второго сервера:

```bash
cp instances/server-2.env.example instances/server-2.env
```

Измените в `instances/server-2.env` как минимум:

- `SERVER_WORKDIR=/data/instances/server-2`
- `SERVER_PORT=6568`
- `SERVER_NAME=andreidev-2`

Запуск второго сервера:

```bash
docker compose --project-name mindustry-server-2 --env-file instances/server-2.env up -d --build
```

Логи второго сервера:

```bash
docker compose --project-name mindustry-server-2 --env-file instances/server-2.env logs -f
```

Остановка второго сервера:

```bash
docker compose --project-name mindustry-server-2 --env-file instances/server-2.env down
```

Подключение к консоли второго сервера:

```bash
docker attach $(docker compose --project-name mindustry-server-2 --env-file instances/server-2.env ps -q mindustry)
```

Важно:

- не запускайте два контейнера с одним и тем же `SERVER_WORKDIR`
- не используйте один и тот же `SERVER_PORT` у двух инстансов
- если нужен третий сервер, создайте ещё один env-файл с новым `SERVER_WORKDIR`, новым `SERVER_PORT` и новым `--project-name`
- несколько инстансов не должны делить один и тот же прогресс одновременно; один каталог данных = один серверный процесс

## Ограничение upstream

У команды `host` у headless-сервера нельзя выбрать случайную карту и одновременно передать произвольный режим кроме `survival`. Поэтому:

- если `SERVER_MAP` задан, entrypoint запускает `host <map> <mode>`
- если намеренно оставить `SERVER_MAP` пустым и `SERVER_MODE=survival`, entrypoint запускает просто `host`
- для любого режима кроме `survival` карта обязательна
