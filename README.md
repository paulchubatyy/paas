# Docker PaaS Platform

A minimal Docker-based Platform as a Service providing reverse proxy with automatic SSL, PostgreSQL database, Valkey cache, and automated S3 backups.

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
   - Domain names
   - Email for Let's Encrypt
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

## Configuration

### Required Environment Variables

```bash
# Admin Access
ADMIN_HOSTNAME=admin.yourdomain.com
ADMIN_EMAIL=you@example.com
ADMIN_CREDENTIALS=admin:$apr1$hash...

# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=changeme
POSTGRES_DB=postgres
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
S3_PREFIX=paas/postgres
ENCRYPTION_PASSWORD=optional_encryption_key
POSTGRES_BACKUP_ALL=false
POSTGRES_EXTRA_OPTS='--schema=public --blobs'
DROP_PUBLIC=yes  # Restore setting: drops public schema before restore
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

**Database connection:** Connect to `postgres:5432` on `db-net`

**Valkey connection:** Connect to `valkey:6379` on `db-net`

## Make Commands

- `make .env` - Copy environment template
- `make gen-admin-auth USER=admin PASS=secret` - Generate admin credentials
- `make set-admin-auth USER=admin PASS=secret` - Update admin credentials in `.env`
- `make deploy` - Deploy docker-compose.yml, .env, Makefile, and backup/ to remote server (set `SERVER` and `REMOTE_PATH`)
- `make backup` - Trigger an immediate manual backup to S3
- `make restore` - Restore database from latest S3 backup

## Backing Up

To create an immediate backup:

```bash
make backup
```

This manually triggers a backup to S3, independent of the scheduled backups. The command displays the database and S3 location before uploading.

**Note:** Scheduled backups run automatically based on the `SCHEDULE` setting in `.env` (default: `@daily`).

## Restoring from Backup

**⚠️ WARNING:** Restore operations destroy existing database data!

To restore the latest backup from S3:

```bash
make restore
```

The restore process:
1. Prompts for confirmation (type "YES" to proceed)
2. Displays target database and S3 location
3. Stops the postgres-backup service
4. Downloads and restores the latest backup from S3
5. Restarts the postgres-backup service

### Restore Configuration

Set `DROP_PUBLIC=yes` in `.env` to drop existing schema before restore (default).

**Important:** The restore operation uses the "latest" backup based on file timestamps. Ensure your S3 bucket only contains backups you want to restore.

**Safety Note:** Consider testing restores in a staging environment before production use.

## Accessing Services

- **Traefik Dashboard:** `https://ADMIN_HOSTNAME` (uses basic auth)
- **PostgreSQL:** `localhost:5432` (internally: `postgres:5432`)
- **Valkey:** `localhost:6379` (internally: `valkey:6379`)

## Services

- **traefik** - Reverse proxy with automatic HTTPS
- **postgres** - PostgreSQL 18 database
- **valkey** - Redis-compatible cache
- **postgres-backup** - Custom backup service (built from `backup/`) for automated S3 backups
- **postgres-restore** - On-demand restore from S3 (run with `make restore`)

## Security

Pre-commit hooks prevent:
- Hardcoded passwords and credentials
- S3 credential exposure
- Invalid Docker Compose configurations
- Environment file commits

## License

MIT
