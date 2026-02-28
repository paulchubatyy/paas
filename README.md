# Docker PaaS Platform

A minimal Docker-based Platform as a Service providing reverse proxy with automatic SSL, PostgreSQL or MariaDB database, Valkey cache, and automated S3 backups.

## Prerequisites

- Docker and Docker Compose
- Domain name with DNS pointing to your server
- Apache Bench (for password generation)

## Quick Start

1. Copy environment template:
   ```bash
   make .env
   ```

2. Configure `.env` with your settings:
   - `COMPOSE_FILE` — pick your services (PostgreSQL or MariaDB)
   - Domain names and email for Let's Encrypt
   - Database credentials
   - S3 backup configuration

3. Generate admin credentials:
   ```bash
   make gen-admin-auth USER=admin PASS=securepassword >> .env
   ```

4. Create external networks:
   ```bash
   docker network create proxy-net
   docker network create db-net
   ```

5. Start services:
   ```bash
   docker compose up -d
   ```

## Choosing a Database

Set `COMPOSE_FILE` in `.env` to pick PostgreSQL or MariaDB:

```bash
# PostgreSQL (default)
COMPOSE_FILE=compose/traefik.yml:compose/postgres.yml:compose/valkey.yml

# MariaDB
COMPOSE_FILE=compose/traefik.yml:compose/mariadb.yml:compose/valkey.yml
```

Then configure the matching database credentials in `.env`. See `example.env` for details.

## Configuration

### Required Environment Variables

```bash
# Admin Access
ADMIN_HOSTNAME=admin.yourdomain.com
ADMIN_EMAIL=you@example.com
ADMIN_CREDENTIALS=admin:$apr1$hash...

# PostgreSQL
POSTGRES_USER=postgres
POSTGRES_PASSWORD=changeme
POSTGRES_DB=postgres

# OR MariaDB
MYSQL_ROOT_PASSWORD=changeme_root
MYSQL_USER=mariadb
MYSQL_PASSWORD=changeme
MYSQL_DATABASE=app
```

### S3 Backup Setup

Configure one S3-compatible provider in `.env`:

**AWS S3:**
```bash
S3_ACCESS_KEY_ID=your_key
S3_SECRET_ACCESS_KEY=your_secret
S3_BUCKET=my-backup-bucket
S3_REGION=us-east-1
```

**Cloudflare R2:**
```bash
S3_ACCESS_KEY_ID=your_key
S3_SECRET_ACCESS_KEY=your_secret
S3_BUCKET=my-backup-bucket
S3_REGION=auto
S3_ENDPOINT=https://<account_id>.r2.cloudflarestorage.com
```

**Other supported providers:** DigitalOcean Spaces, Backblaze B2, Wasabi, MinIO

See `example.env` for complete provider configurations.

### Backup Settings

```bash
SCHEDULE=@daily
S3_PREFIX=paas/db
ENCRYPTION_PASSWORD=optional_encryption_key
BACKUP_ALL=false
EXTRA_OPTS=
DROP_PUBLIC=yes  # Restore: drops public schema (PG) or recreates DB (MariaDB)
```

## Adding Applications

Deploy services to the platform by adding Docker labels:

```yaml
services:
  myapp:
    image: myapp:latest
    networks:
      - proxy-net
      - db-net
    labels:
      - traefik.enable=true
      - traefik.http.routers.myapp.rule=Host(`app.yourdomain.com`)
      - traefik.http.routers.myapp.tls=true
      - traefik.http.routers.myapp.tls.certresolver=letsencrypt
```

**Database connection:** `postgres:5432` or `mariadb:3306` on `db-net`

**Valkey connection:** `valkey:6379` on `db-net`

## Make Commands

- `make .env` - Copy environment template
- `make gen-admin-auth USER=admin PASS=secret` - Generate admin credentials
- `make set-admin-auth USER=admin PASS=secret` - Update admin credentials in `.env`
- `make deploy` - Deploy compose files, .env, Makefile, and backup/ to remote server
- `make backup` - Trigger an immediate manual backup to S3
- `make restore` - Restore database from latest S3 backup

## Backing Up

To create an immediate backup:

```bash
make backup
```

This manually triggers a backup to S3, independent of the scheduled backups.

**Note:** Scheduled backups run automatically based on the `SCHEDULE` setting in `.env` (default: `@daily`).

## Restoring from Backup

**WARNING:** Restore operations destroy existing database data!

To restore the latest backup from S3:

```bash
make restore
```

The restore process:
1. Prompts for confirmation (type "YES" to proceed)
2. Stops the db-backup service
3. Downloads and restores the latest backup from S3
4. Restarts the db-backup service

### Restore Configuration

Set `DROP_PUBLIC=yes` in `.env` to drop existing schema before restore (default). For PostgreSQL this drops the public schema; for MariaDB it drops and recreates the database.

## Accessing Services

- **Traefik Dashboard:** `https://ADMIN_HOSTNAME` (uses basic auth)
- **PostgreSQL:** `localhost:5432` (internally: `postgres:5432`)
- **MariaDB:** `localhost:3306` (internally: `mariadb:3306`)
- **Valkey:** `localhost:6379` (internally: `valkey:6379`)

## Services

- **traefik** - Reverse proxy with automatic HTTPS
- **postgres** or **mariadb** - Database (choose via `COMPOSE_FILE`)
- **valkey** - Redis-compatible cache
- **db-backup** - Automated S3 backups (built from `backup/`)
- **db-restore** - On-demand restore from S3 (run with `make restore`)

## Security

Pre-commit hooks prevent:
- Hardcoded passwords and credentials
- S3 credential exposure
- Invalid Docker Compose configurations
- Environment file commits

## License

MIT
