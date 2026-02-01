.env:
	cp example.env .env

SERVER := user@example.com
REMOTE_PATH := paas
deploy:
	rsync -avz docker-compose.yml .env $(SERVER):$(REMOTE_PATH)/

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
