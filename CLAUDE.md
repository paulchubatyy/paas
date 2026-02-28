# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A minimal Docker-based Platform as a Service providing:
- Traefik reverse proxy with automatic Let's Encrypt SSL
- PostgreSQL 18 or MariaDB 11 database (interchangeable)
- Valkey (Redis-compatible) cache
- Automated S3 backups with optional encryption

## Commands

```bash
# Setup
make .env                              # Create .env from example.env
make gen-admin-auth USER=x PASS=y      # Generate admin credentials (append >> .env)
make set-admin-auth USER=x PASS=y      # Update admin credentials in existing .env

# Services
docker compose up -d                   # Start all services
docker compose logs -f <service>       # View service logs

# Backup/Restore
make backup                            # Trigger immediate backup to S3
make restore                           # Restore from latest S3 backup (destructive!)

# Deploy to remote server
make deploy SERVER=user@host REMOTE_PATH=paas
```

## Architecture

### Per-Service Compose Files

Services are split into `compose/` files, merged via the `COMPOSE_FILE` env var in `.env`:

```env
# PostgreSQL setup (default)
COMPOSE_FILE=compose/traefik.yml:compose/postgres.yml:compose/valkey.yml

# MariaDB setup (swap one line)
COMPOSE_FILE=compose/traefik.yml:compose/mariadb.yml:compose/valkey.yml
```

### Networks (external, must be created manually)
- `proxy-net`: Connects Traefik to web-facing services
- `db-net`: Connects database and Valkey to backend services

### Compose Files
- **compose/traefik.yml**: Reverse proxy, SSL via Let's Encrypt, admin dashboard
- **compose/postgres.yml**: PostgreSQL 18 + db-backup + db-restore services
- **compose/mariadb.yml**: MariaDB 11 + db-backup + db-restore services
- **compose/valkey.yml**: Redis-compatible cache

### Backup System (`backup/` directory)
Custom Docker image based on debian:bookworm-slim with both pg-client and mariadb-client:
- `backup.sh`: Entry point - runs one-time or schedules via interval
- `do-backup.sh`: Branches on `DB_TYPE` — pg_dump or mysqldump, optional encryption, uploads to S3
- `restore.sh`: Downloads latest backup from S3, decrypts if needed, restores via psql or mysql

Supports multiple S3-compatible providers: AWS S3, Cloudflare R2, DigitalOcean Spaces, Backblaze B2, Wasabi, MinIO.

## Adding Applications

Deploy services by adding Docker labels and connecting to the external networks:
```yaml
services:
  myapp:
    networks:
      - proxy-net  # For web access via Traefik
      - db-net     # For database/cache access
    labels:
      - traefik.enable=true
      - traefik.http.routers.myapp.rule=Host(`app.domain.com`)
      - traefik.http.routers.myapp.tls=true
      - traefik.http.routers.myapp.tls.certresolver=letsencrypt
```

Internal hostnames: `postgres:5432` or `mariadb:3306`, `valkey:6379`

## Kanban Board

Default board ID: `br1rYlNG` — use this for all kardbrd queries unless otherwise specified.

## Pre-commit Hooks

The repo uses pre-commit hooks that:
- Validate compose file syntax
- Block .env file commits
- Detect hardcoded passwords/credentials in compose files
- Check Makefile uses tabs (not spaces)
