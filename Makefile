.PHONY: .env deploy gen-admin-auth set-admin-auth backup restore

.env:
	cp example.env .env

SERVER := user@example.com
REMOTE_PATH := paas
deploy:
	rsync -avz compose .env Makefile backup $(SERVER):$(REMOTE_PATH)/

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
	@docker compose run -e SCHEDULE='**None**' --rm db-backup

restore:
	@echo "WARNING: This will RESTORE database from S3 and may DESTROY existing data!"
	@echo ""
	@read -p "Type 'YES' to confirm restore operation: " confirm; \
	if [ "$$confirm" != "YES" ]; then \
		echo "Restore cancelled."; \
		exit 1; \
	fi
	@echo "Stopping db-backup..."
	@docker compose stop db-backup || true
	@echo "Running restore..."
	@docker compose --profile restore run --rm db-restore
	@echo "Restore completed! Starting db-backup..."
	@docker compose start db-backup || true
	@echo "Restore process finished"
