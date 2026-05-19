# Matrix Synapse — HQ Deployment

Корпоративний месенджер на базі Matrix Synapse з підтримкою голосових та відеодзвінків через Element Call + LiveKit, автентифікацією через Active Directory (LDAP) та федерацією між офісами.

---

## Стек

| Компонент | Образ | Призначення |
|---|---|---|
| **Synapse** | `matrixdotorg/synapse:latest` + `matrix-synapse-ldap3` | Matrix homeserver |
| **PostgreSQL** | `postgres:16-alpine` | База даних Synapse |
| **Element Web** | `vectorim/element-web:latest` | Веб-клієнт |
| **Element Call** | `ghcr.io/element-hq/element-call:latest` | Відеодзвінки |
| **LiveKit** | `livekit/livekit-server:latest` | SFU для WebRTC |
| **lk-jwt-service** | `ghcr.io/element-hq/lk-jwt-service:latest` | Токени LiveKit ↔ Matrix |
| **Coturn** | `coturn/coturn:latest` | TURN/STUN для NAT traversal |
| **nginx** | `nginx:alpine` | Reverse proxy + TLS |

---

## Архітектура

```
Клієнти (Element Web / Mobile)
        │
        ▼
   nginx (443 / 8448)
   ├── /_matrix/*        → Synapse :8008
   ├── /call/            → Element Call :8080
   ├── /_livekit/jwt/    → lk-jwt-service :8080
   ├── /livekit          → LiveKit :7880 (WebSocket)
   └── /                 → Element Web :80
        │
        ├── PostgreSQL (внутрішня мережа)
        ├── LiveKit (WebRTC media UDP 50000-50100)
        └── Coturn (TURN UDP 3478 / TURNS TCP 5349)
```

---

## Вимоги

- **ОС:** Debian 12/13
- **RAM:** 8 GB+
- **Диск:** 200 GB+
- **Docker Engine:** 24.x+
- **Docker Compose:** v2.x+
- **Публічний IP** з відкритими портами

---

## Порти (фаєрвол / роутер)

| Порт | Протокол | Призначення |
|---|---|---|
| `80` | TCP | HTTP → HTTPS redirect + certbot |
| `443` | TCP | HTTPS (Matrix API, Element Web, Element Call) |
| `8448` | TCP | Matrix Federation fallback |
| `3478` | UDP | TURN/STUN (Coturn) |
| `5349` | TCP + UDP | TURNS/STUNS (Coturn TLS) |
| `7881` | TCP | LiveKit WebRTC fallback |
| `49152–65535` | UDP | Coturn медіапотоки |
| `50000–50100` | UDP | LiveKit медіапотоки |

---

## Розгортання

### 1. Встановлення Docker

```bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update && sudo apt-get install -y \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

### 2. Клонування репозиторію

```bash
git clone git@github.com:gkfs-it/matrix.git /opt/matrix
cd /opt/matrix
```

### 3. Підготовка конфігів із секретами

Скопіювати шаблони та заповнити реальними значеннями:

```bash
cp docker-compose.yml.example docker-compose.yml
cp synapse/homeserver.yaml.example synapse/homeserver.yaml
cp livekit/livekit.yaml.example livekit/livekit.yaml
cp coturn/turnserver.conf.example coturn/turnserver.conf
```

Згенерувати секрети для `homeserver.yaml`:

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

Згенерувати LiveKit API key/secret:

```bash
openssl rand -hex 16        # key
openssl rand -base64 32     # secret
```

### 4. Отримання TLS-сертифіката

```bash
sudo apt-get install -y certbot
sudo certbot certonly --standalone -d YOUR_DOMAIN \
  --non-interactive --agree-tos -m admin@YOUR_DOMAIN
```

### 5. Генерація конфігурації Synapse

```bash
sudo docker run --rm \
  -v /opt/matrix/synapse:/data \
  -e SYNAPSE_SERVER_NAME=YOUR_DOMAIN \
  -e SYNAPSE_REPORT_STATS=no \
  matrixdotorg/synapse:latest generate
```

### 6. Збірка та запуск

```bash
sudo docker compose build synapse
sudo docker compose up -d
sudo docker compose logs -f synapse
```

---

## LDAP / Active Directory

Автентифікація через `matrix-synapse-ldap3`. Налаштовується в `synapse/homeserver.yaml`:

```yaml
modules:
  - module: ldap_auth_provider.LdapAuthProviderModule
    config:
      enabled: true
      uri:
        - "ldap://DC1_HOSTNAME:389"
        - "ldap://DC2_HOSTNAME:389"
      start_tls: false
      base: "DC=domain,DC=local"
      attributes:
        uid: "sAMAccountName"
      bind_dn: "CN=ldap_read,OU=ServiceAccounts,DC=domain,DC=local"
      bind_password: "LDAP_BIND_PASSWORD"
```

Користувач входить через **Windows-логін** (`sAMAccountName`) без домену.

---

## Деактивація користувача

При відключенні акаунта в AD необхідно також анулювати сесії в Synapse:

```bash
./deactivate-user.sh <username> <admin_token>
# Приклад:
./deactivate-user.sh ivanov.i syt_xxxxxxxxxxxx
```

---

## Корисні команди

```bash
# Статус контейнерів
docker compose ps

# Логи Synapse
docker compose logs -f synapse

# Перезапуск після зміни homeserver.yaml
docker compose restart synapse

# Оновлення образів
docker compose pull
docker compose up -d

# Список користувачів (PostgreSQL)
docker exec -it synapse-postgres psql -U synapse -c \
  "SELECT name, admin, deactivated FROM users ORDER BY creation_ts;"
```

---

## Структура репозиторію

```
matrix/
├── Dockerfile.synapse              # Synapse + LDAP плагін
├── docker-compose.yml.example      # Шаблон docker-compose (без секретів)
├── element-config.json             # Налаштування Element Web
├── element-call-config.json        # Налаштування Element Call
├── deactivate-user.sh              # Деактивація користувача
├── list_users.sh                   # Список користувачів
├── nginx/
│   └── nginx.conf                  # Reverse proxy конфіг
├── synapse/
│   ├── homeserver.yaml.example     # Шаблон конфігу Synapse (без секретів)
│   └── hq.gkfs.com.ua.log.config   # Конфіг логування
├── livekit/
│   └── livekit.yaml.example        # Шаблон конфігу LiveKit (без секретів)
└── coturn/
    └── turnserver.conf.example     # Шаблон конфігу Coturn (без секретів)
```

> Файли з реальними секретами (`homeserver.yaml`, `docker-compose.yml`, `livekit.yaml`, `turnserver.conf`) додані до `.gitignore` і не зберігаються в репозиторії.

---

## Ліцензія

Внутрішня документація GKFS IT. Конфіденційно.
