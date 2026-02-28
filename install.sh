#!/usr/bin/env bash
set -euo pipefail

# Override these to install from a fork or different branch:
#   PAAS_REPO=https://github.com/you/paas PAAS_BRANCH=dev curl ... | bash
PAAS_REPO="${PAAS_REPO:-https://github.com/paulchubatyy/paas}"
PAAS_BRANCH="${PAAS_BRANCH:-main}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[-]${NC} $1" >&2; }
fatal() { error "$1"; exit 1; }

ask() {
    local prompt="$1" var="$2"
    printf "${BLUE}[?]${NC} %s" "$prompt" >&2
    read -r "${var?}" </dev/tty
}

# --- Preflight ---

preflight() {
    if [ "$(id -u)" -eq 0 ]; then
        fatal "Don't run as root. The script will use sudo when needed."
    fi

    if ! sudo -v 2>/dev/null; then
        fatal "This script requires sudo access."
    fi

    if [ ! -f /etc/os-release ]; then
        fatal "Cannot detect OS. This script requires Ubuntu 22.04+."
    fi

    # shellcheck disable=SC1091
    . /etc/os-release

    if [ "$ID" != "ubuntu" ]; then
        fatal "This script requires Ubuntu. Detected: $ID"
    fi

    local major_version
    major_version=$(echo "$VERSION_ID" | cut -d. -f1)
    if [ "$major_version" -lt 22 ]; then
        fatal "Ubuntu 22.04+ required. Detected: $VERSION_ID"
    fi

    if snap list docker 2>/dev/null | grep -q docker; then
        fatal "Snap Docker detected. Remove it first: sudo snap remove docker"
    fi

    log "Preflight checks passed (Ubuntu $VERSION_ID)"
}

# --- System packages ---

install_packages() {
    log "Installing system packages..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker.io docker-compose-v2 apache2-utils ufw wget >/dev/null

    sudo systemctl enable --now docker >/dev/null 2>&1

    if ! groups "$USER" | grep -qw docker; then
        sudo usermod -aG docker "$USER"
        warn "Added $USER to docker group (takes effect after re-login)."
    fi

    log "Packages installed"
}

# --- UFW + ufw-docker ---

setup_ufw() {
    log "Configuring firewall..."

    sudo ufw allow OpenSSH >/dev/null 2>&1
    sudo ufw allow 80/tcp >/dev/null 2>&1
    sudo ufw allow 443/tcp >/dev/null 2>&1
    sudo ufw --force enable >/dev/null 2>&1

    if [ ! -f /usr/local/bin/ufw-docker ]; then
        sudo wget -qO /usr/local/bin/ufw-docker \
            https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker
        sudo chmod +x /usr/local/bin/ufw-docker
    fi

    sudo ufw-docker install >/dev/null 2>&1
    sudo systemctl restart ufw >/dev/null 2>&1

    log "Firewall configured (ufw + ufw-docker)"
}

# --- Interactive prompts ---

prompt_config() {
    echo ""
    echo -e "${BOLD}Configure your PaaS${NC}"
    echo ""

    # Install path
    local default_path="$HOME/paas"
    ask "Install path [$default_path]: " INSTALL_PATH
    INSTALL_PATH="${INSTALL_PATH:-$default_path}"

    # Admin dashboard
    ask "Admin dashboard domain (e.g. admin.example.com): " ADMIN_HOSTNAME
    [ -z "$ADMIN_HOSTNAME" ] && fatal "Domain is required."

    ask "Email for Let's Encrypt certificates: " ADMIN_EMAIL
    [ -z "$ADMIN_EMAIL" ] && fatal "Email is required."

    # Database
    echo ""
    echo "  1) PostgreSQL (default)"
    echo "  2) MariaDB"
    ask "Database [1]: " DB_CHOICE
    DB_CHOICE="${DB_CHOICE:-1}"

    case "$DB_CHOICE" in
        1|postgres|pg)
            DB_TYPE="postgres"
            ask "PostgreSQL user [postgres]: " PG_USER
            PG_USER="${PG_USER:-postgres}"
            ask "PostgreSQL password: " PG_PASS
            [ -z "$PG_PASS" ] && fatal "Password is required."
            ask "PostgreSQL database [postgres]: " PG_DB
            PG_DB="${PG_DB:-postgres}"
            ;;
        2|mariadb|mysql)
            DB_TYPE="mariadb"
            ask "MariaDB root password: " MYSQL_ROOT_PASS
            [ -z "$MYSQL_ROOT_PASS" ] && fatal "Root password is required."
            ask "MariaDB user [mariadb]: " MYSQL_USER
            MYSQL_USER="${MYSQL_USER:-mariadb}"
            ask "MariaDB user password: " MYSQL_PASS
            [ -z "$MYSQL_PASS" ] && fatal "Password is required."
            ask "MariaDB database [app]: " MYSQL_DB
            MYSQL_DB="${MYSQL_DB:-app}"
            ;;
        *)
            fatal "Invalid choice: $DB_CHOICE"
            ;;
    esac

    # Admin credentials
    echo ""
    ask "Admin username [admin]: " ADMIN_USER
    ADMIN_USER="${ADMIN_USER:-admin}"
    ask "Admin password: " ADMIN_PASS
    [ -z "$ADMIN_PASS" ] && fatal "Admin password is required."
}

# --- Download project files ---

download_files() {
    if [ -d "$INSTALL_PATH" ] && [ -f "$INSTALL_PATH/example.env" ]; then
        warn "$INSTALL_PATH already exists, skipping download."
        return
    fi

    log "Downloading PaaS files..."
    mkdir -p "$INSTALL_PATH"

    local tarball_url="$PAAS_REPO/archive/$PAAS_BRANCH.tar.gz"
    curl -fsSL "$tarball_url" | tar xz --strip-components=1 -C "$INSTALL_PATH"

    log "Files downloaded to $INSTALL_PATH"
}

# --- Generate .env ---

generate_env() {
    if [ -f "$INSTALL_PATH/.env" ]; then
        warn ".env already exists, skipping generation."
        return
    fi

    log "Generating .env..."
    cp "$INSTALL_PATH/example.env" "$INSTALL_PATH/.env"

    local envfile="$INSTALL_PATH/.env"

    # COMPOSE_FILE — swap to mariadb if chosen
    if [ "$DB_TYPE" = "mariadb" ]; then
        sed -i 's|^COMPOSE_FILE=compose/traefik.yml:compose/postgres.yml|# COMPOSE_FILE=compose/traefik.yml:compose/postgres.yml|' "$envfile"
        sed -i 's|^# COMPOSE_FILE=compose/traefik.yml:compose/mariadb.yml|COMPOSE_FILE=compose/traefik.yml:compose/mariadb.yml|' "$envfile"
    fi

    # Database credentials
    if [ "$DB_TYPE" = "postgres" ]; then
        sed -i "s|^POSTGRES_USER=.*|POSTGRES_USER=$PG_USER|" "$envfile"
        sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$PG_PASS|" "$envfile"
        sed -i "s|^POSTGRES_DB=.*|POSTGRES_DB=$PG_DB|" "$envfile"
    else
        sed -i "s|^# MYSQL_ROOT_PASSWORD=.*|MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASS|" "$envfile"
        sed -i "s|^# MYSQL_USER=.*|MYSQL_USER=$MYSQL_USER|" "$envfile"
        sed -i "s|^# MYSQL_PASSWORD=.*|MYSQL_PASSWORD=$MYSQL_PASS|" "$envfile"
        sed -i "s|^# MYSQL_DATABASE=.*|MYSQL_DATABASE=$MYSQL_DB|" "$envfile"
    fi

    # Admin dashboard
    local admin_creds
    admin_creds=$(htpasswd -nbB "$ADMIN_USER" "$ADMIN_PASS" | sed 's/\$/\$\$/g')

    {
        echo ""
        echo "# --- Admin dashboard ---"
        echo "ADMIN_HOSTNAME=$ADMIN_HOSTNAME"
        echo "ADMIN_EMAIL=$ADMIN_EMAIL"
        echo "ADMIN_CREDENTIALS=$admin_creds"
    } >> "$envfile"

    # Clear the trap encryption password
    sed -i 's|^ENCRYPTION_PASSWORD=.*|ENCRYPTION_PASSWORD=|' "$envfile"

    log ".env generated"
}

# --- Start services ---

start_services() {
    # Docker group isn't active in this session, use sudo
    sudo docker network inspect proxy-net >/dev/null 2>&1 || sudo docker network create proxy-net >/dev/null
    sudo docker network inspect db-net >/dev/null 2>&1 || sudo docker network create db-net >/dev/null

    mkdir -p "$INSTALL_PATH/acme"

    log "Starting services..."
    cd "$INSTALL_PATH"
    sudo docker compose up -d

    log "Services started"
}

# --- Post-install summary ---

post_install() {
    echo ""
    echo -e "${GREEN}${BOLD}PaaS installed successfully!${NC}"
    echo ""
    echo "  Install path:  $INSTALL_PATH"
    echo "  Dashboard:     https://$ADMIN_HOSTNAME"
    echo "  Database:      $DB_TYPE"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Review and edit $INSTALL_PATH/.env"
    echo "     - Configure S3 backup (uncomment one provider section)"
    echo "     - Adjust backup schedule, encryption, etc."
    echo "  2. Restart backup after configuring S3:"
    echo "     cd $INSTALL_PATH && docker compose restart db-backup"
    echo "  3. Log out and back in (or: newgrp docker) for docker group"
    echo ""
}

# --- Main ---

main() {
    echo ""
    echo -e "${BOLD}Docker PaaS Installer${NC}"
    echo ""

    preflight
    install_packages
    setup_ufw
    prompt_config
    download_files
    generate_env
    start_services
    post_install
}

main "$@"
