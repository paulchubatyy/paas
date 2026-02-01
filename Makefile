.env:
	cp example.env .env

SERVER := user@example.com
REMOTE_PATH := paas
deploy:
	rsync -avz docker-compose.yml .env Makefile backup/ $(SERVER):$(REMOTE_PATH)/

gen-admin-auth:
	@if [ -z "$(USER)" ] || [ -z "$(PASS)" ]; then \
		echo "Usage: make gen-admin-auth USER=admin PASS=secret"; \
		echo "Or: make gen-admin-auth USER=admin PASS=secret >> .env"; \
		exit 1; \
	fi
	@echo "ADMIN_CREDENTIALS=$$(htpasswd -nbB '$(USER)' '$(PASS)')"

set-admin-auth:
	@if [ -z "$(USER)" ] || [ -z "$(PASS)" ]; then \
		echo "Usage: make set-admin-auth USER=admin PASS=secret"; \
		exit 1; \
	fi
	@grep -v "^ADMIN_CREDENTIALS=" .env > .env.tmp || true
	@echo "ADMIN_CREDENTIALS=$$(htpasswd -nbB '$(USER)' '$(PASS)')" >> .env.tmp
	@mv .env.tmp .env
	@echo "Updated .env with new admin credentials for user: $(USER)"

backup:
	@echo "Starting manual backup..."
	@echo "Database: $$(grep '^POSTGRES_DB=' .env | cut -d'=' -f2)"
	@echo "S3 Bucket: $$(grep '^S3_BUCKET=' .env | cut -d'=' -f2)"
	@echo "S3 Prefix: $$(grep '^S3_PREFIX=' .env | cut -d'=' -f2)"
	@echo ""
	@docker compose run -e SCHEDULE='**None**' --rm postgres-backup
	@echo "✓ Backup completed"

restore:
	@echo "⚠️  WARNING: This will RESTORE database from S3 and may DESTROY existing data!"
	@echo "⚠️  Ensure PostgreSQL backup container is stopped during restore!"
	@echo ""
	@echo "Database: $$(grep '^POSTGRES_DB=' .env | cut -d'=' -f2)"
	@echo "S3 Bucket: $$(grep '^S3_BUCKET=' .env | cut -d'=' -f2)"
	@echo "S3 Prefix: $$(grep '^S3_PREFIX=' .env | cut -d'=' -f2)"
	@echo ""
	@read -p "Type 'YES' to confirm restore operation: " confirm; \
	if [ "$$confirm" != "YES" ]; then \
		echo "Restore cancelled."; \
		exit 1; \
	fi
	@echo "Stopping postgres-backup..."
	@docker compose stop postgres-backup || true
	@echo "Running restore..."
	@docker compose --profile restore run --rm postgres-restore
	@echo "Restore completed! Starting postgres-backup..."
	@docker compose start postgres-backup || true
	@echo "✓ Restore process finished"
