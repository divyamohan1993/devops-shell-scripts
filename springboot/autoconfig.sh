#!/usr/bin/env bash
# oneclick-deploy-enterprise.sh
# Spring Boot fat JAR + blue/green + optional canary + hardened systemd + Nginx (+TLS/mTLS/basic auth)
# SBOM + checksums + optional Trivy scan + optional cosign attestation + audit manifest + maintenance mode
# Idempotent. Init-from-blank-VM. Debug-first. SSH/22 is explicitly preserved.

set -Eeuo pipefail

# -------------------- Debug & Logging --------------------
DEBUG="${DEBUG:-1}"                         # 1=enable set -x and verbose logging
LOG_DIR="${LOG_DIR:-/var/log/oneclick}"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_FILE:-$LOG_DIR/$(basename "$0")-$(date +%Y%m%d_%H%M%S).log}"

if [ "$DEBUG" = "1" ]; then
  export PS4='+ [$(date -Is)] ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}() '
  set -x
fi
# Log everything to file and console
exec > >(tee -a "$LOG_FILE") 2>&1

log(){ echo ">>> $*"; }
warn(){ echo "!!! $*" >&2; }
die(){ echo "!!! $*" >&2; exit 1; }
trap 'echo "!!! failed at line $LINENO"; exit 1' ERR

retry(){ # retry <attempts> <sleep> -- cmd...
  local attempts="$1" sleep_sec="$2"; shift 2
  local n=0
  until "$@"; do
    n=$((n+1)); [ "$n" -ge "$attempts" ] && return 1
    sleep "$sleep_sec"
  done
}

free_port(){ # find a free TCP port starting at $1
  local p="$1"
  while ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$p$"; do p=$((p+1)); done
  echo "$p"
}

# -------- Config (override via env) ----------
APP_NAME="${APP_NAME:-hello-boot}"
GROUP_ID="${GROUP_ID:-com.example}"
PACKAGE="${PACKAGE:-com.example.demo}"
JAVA_RELEASE="${JAVA_RELEASE:-17}"

USE_NGINX="${USE_NGINX:-yes}"             # yes|no
DOMAIN="${DOMAIN:-}"                      # enables TLS if EMAIL provided
EMAIL="${EMAIL:-}"                        # Let's Encrypt account email

PORT_A="${PORT_A:-8081}"                  # blue
PORT_B="${PORT_B:-8082}"                  # green
KEEP_RELEASES="${KEEP_RELEASES:-5}"       # releases to keep
JDK_PKG="${JDK_PKG:-openjdk-17-jdk}"

# Nginx security/perf
RATE="${RATE:-10r/s}"                     # requests per IP
BURST="${BURST:-20}"                      # burst size
ACTUATOR_ALLOW_CIDRS="${ACTUATOR_ALLOW_CIDRS:-127.0.0.1/32,::1/128}"
ENABLE_BROTLI="${ENABLE_BROTLI:-auto}"    # auto|yes|no
BASIC_AUTH_ENABLE="${BASIC_AUTH_ENABLE:-0}"
BASIC_AUTH_USER="${BASIC_AUTH_USER:-}"
BASIC_AUTH_PASS="${BASIC_AUTH_PASS:-}"
MTLS_CA_PEM="${MTLS_CA_PEM:-}"            # path to PEM CA to enforce client certs (optional)

# Blue/Green & Canary
CANARY_PERCENT="${CANARY_PERCENT:-0}"     # 0..100 (0=off)
PROMOTE="${PROMOTE:-0}"                   # 1=promote to 100%
DRAIN_SECONDS="${DRAIN_SECONDS:-10}"      # stop old after drain

# Ops / Security
LOCKDOWN_NET="${LOCKDOWN_NET:-0}"         # 1=egress deny-all (systemd), allow with ALLOW_NET_CIDRS
ALLOW_NET_CIDRS="${ALLOW_NET_CIDRS:-}"    # e.g., "10.0.0.0/8 169.254.169.254/32"
ENABLE_TRIVY_SCAN="${ENABLE_TRIVY_SCAN:-auto}" # auto|yes|no
ENABLE_ATTESTATION="${ENABLE_ATTESTATION:-0}"  # 1=cosign local attestation (needs key)
COSIGN_KEY_PATH="${COSIGN_KEY_PATH:-}"
JAVA_TLS13_ONLY="${JAVA_TLS13_ONLY:-1}"   # 1=force TLS1.3 on JVM
CPU_QUOTA="${CPU_QUOTA:-80%}"             # systemd CPUQuota
MEMORY_MAX="${MEMORY_MAX:-0}"             # systemd MemoryMax (e.g., "1G"; 0=unset)
MAINTENANCE_FLAG="${MAINTENANCE_FLAG:-/var/www/${APP_NAME}/MAINTENANCE_ON}"  # if exists -> 503

ROLLBACK="${ROLLBACK:-0}"                 # 1=roll back to previous release
# --------------------------------------------

WORKDIR="$PWD"
PROJ_DIR="$WORKDIR/$APP_NAME"
INSTALL_DIR="/opt/$APP_NAME"
RELEASES_DIR="$INSTALL_DIR/releases"
CURRENT_DIR_LINK="$INSTALL_DIR/current"     # symlink -> release dir
CHECKSUMS_DIR="$INSTALL_DIR/checksums"
ENV_DIR="/etc/$APP_NAME"
ENV_FILE="$ENV_DIR/env"
ACTIVE_FILE="$INSTALL_DIR/active_port"
SVC_TEMPLATE="/etc/systemd/system/${APP_NAME}@.service"
NGX_SITE="/etc/nginx/sites-available/$APP_NAME"
NGX_LINK="/etc/nginx/sites-enabled/$APP_NAME"
NGX_CONF="/etc/nginx/nginx.conf"
AUDIT_DIR="$INSTALL_DIR/audit"
TS="$(date +%Y%m%d_%H%M%S)"
AUDIT_FILE="$AUDIT_DIR/manifest-${TS}.json"

# ------------------------- ROLLBACK -------------------------
if [ "$ROLLBACK" = "1" ]; then
  [ -d "$RELEASES_DIR" ] || die "No releases found to roll back."
  CUR="$(readlink -f "$CURRENT_DIR_LINK" || true)"
  PREV="$(ls -1dt "$RELEASES_DIR"/release-* 2>/dev/null | grep -vx "$CUR" | head -n1 || true)"
  [ -n "$PREV" ] || die "No previous release."
  sudo ln -sfn "$PREV" "$CURRENT_DIR_LINK"

  ACTIVE_PORT="$( [ -f "$ACTIVE_FILE" ] && cat "$ACTIVE_FILE" || echo "$PORT_A" )"
  INACTIVE_PORT="$PORT_B"; [ "$ACTIVE_PORT" = "$PORT_B" ] && INACTIVE_PORT="$PORT_A"

  log "Rolling back to $(basename "$PREV"); restarting ${APP_NAME}@${INACTIVE_PORT}..."
  sudo systemctl daemon-reload
  sudo systemctl restart "${APP_NAME}@${INACTIVE_PORT}"

  for i in {1..60}; do
    curl -fsS "http://127.0.0.1:${INACTIVE_PORT}/actuator/health" | grep -q '"status":"UP"' && break
    sleep 1
    [ $i -eq 60 ] && die "Rollback instance on :${INACTIVE_PORT} not healthy."
  done

  if [ -f "$NGX_SITE" ]; then
    sudo sed -i "s|server 127.0.0.1:[0-9]\+;|server 127.0.0.1:${INACTIVE_PORT};|g" "$NGX_SITE"
    sudo nginx -t && sudo systemctl reload nginx || true
  fi
  echo "$INACTIVE_PORT" | sudo tee "$ACTIVE_FILE" >/dev/null
  log "Rollback complete. Active port now $(cat "$ACTIVE_FILE")."
  exit 0
fi

# ------------------- Preflight -------------------
log "Preflight: disk/mem/network checks"
df -h /
free -h || true
ip -brief a || true

# ----------------- Install base deps ----------------
log "Installing base deps (idempotent)..."
retry 3 3 sudo apt-get update -y
retry 3 3 sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  "$JDK_PKG" maven ca-certificates curl unzip coreutils jq apache2-utils \
  nginx certbot python3-certbot-nginx iproute2 || true

# --- NEVER BREAK SSH (GCE-safe) ---
sudo apt-get install -y openssh-server
sudo systemctl enable ssh >/dev/null 2>&1 || true
sudo systemctl start  ssh >/dev/null 2>&1 || true
if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow 22/tcp >/dev/null 2>&1 || true
  REMOTE_IP="$(printf '%s' "${SSH_CONNECTION:-}" | awk '{print $1}')"
  [ -n "$REMOTE_IP" ] && sudo ufw allow from "$REMOTE_IP" to any port 22 proto tcp >/dev/null 2>&1 || true
fi
if command -v nft >/dev/null 2>&1; then
  if ! sudo nft list ruleset 2>/dev/null | grep -q 'tcp dport 22 .* accept'; then
    sudo nft add rule inet filter input tcp dport 22 ct state new,established accept >/dev/null 2>&1 || true
  fi
fi
if ! ss -ltn 2>/dev/null | grep -q ':22 '; then
  warn "Nothing listening on :22; attempting to start sshd"; sudo systemctl start ssh || true
fi

# Optional scanners/attestation
if [ "${ENABLE_TRIVY_SCAN}" != "no" ]; then sudo apt-get install -y trivy >/dev/null 2>&1 || true; fi
if [ "${ENABLE_ATTESTATION}" = "1" ]; then sudo apt-get install -y cosign >/dev/null 2>&1 || true; fi

# ----------------- Users & dirs -------------------
if ! id "$APP_NAME" >/dev/null 2>&1; then
  sudo useradd -r -m -U -d "$INSTALL_DIR" -s /usr/sbin/nologin "$APP_NAME"
fi
sudo mkdir -p "$RELEASES_DIR" "$CHECKSUMS_DIR" "$AUDIT_DIR" "$ENV_DIR"
sudo chown -R "$APP_NAME:$APP_NAME" "$INSTALL_DIR"
if [ "$USE_NGINX" = "yes" ]; then
  sudo rm -f /etc/nginx/sites-enabled/default || true
  sudo mkdir -p "$(dirname "$MAINTENANCE_FLAG")"
fi

# ---- Blue/green (auto-resolve port conflicts) ----
ACTIVE_PORT="$( [ -f "$ACTIVE_FILE" ] && cat "$ACTIVE_FILE" || echo "$PORT_A" )"
INACTIVE_PORT="$PORT_B"; [ "$ACTIVE_PORT" = "$PORT_B" ] && INACTIVE_PORT="$PORT_A"
# if inactive port is busy, pick a free one
INACTIVE_PORT="$(free_port "$INACTIVE_PORT")"

# --------------- Generate project ----------------
rm -rf "$PROJ_DIR"; mkdir -p "$PROJ_DIR"; cd "$WORKDIR"
log "Generating Spring Boot project (web + actuator + prometheus)..."
ZIP_OK=0
if curl -fsSL -G "https://start.spring.io/starter.zip" \
  --data-urlencode "type=maven-project" \
  --data-urlencode "language=java" \
  --data-urlencode "baseDir=$APP_NAME" \
  --data-urlencode "groupId=$GROUP_ID" \
  --data-urlencode "artifactId=$APP_NAME" \
  --data-urlencode "name=$APP_NAME" \
  --data-urlencode "packageName=$PACKAGE" \
  --data-urlencode "dependencies=web,actuator,prometheus" -o boot.zip; then
  unzip -qo boot.zip -d "$WORKDIR"; rm -f boot.zip; ZIP_OK=1
fi
if [ "$ZIP_OK" -ne 1 ]; then
  log "start.spring.io unreachable — scaffolding locally"
  mkdir -p "$PROJ_DIR/src/main/java/${PACKAGE//./\/}" "$PROJ_DIR/src/main/resources"
  cat > "$PROJ_DIR/pom.xml" <<'POM'
<project xmlns="http://maven.apache.org/POM/4.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.4</version>
    <relativePath/>
  </parent>
  <groupId>__GROUP_ID__</groupId>
  <artifactId>__APP_NAME__</artifactId>
  <version>1.0.0</version>
  <name>__APP_NAME__</name>
  <properties><java.version>__JAVA__</java.version></properties>
  <dependencies>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web"/></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-actuator"/></dependency>
    <dependency><groupId>io.micrometer</groupId><artifactId>micrometer-registry-prometheus"/></dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin"/></plugin>
    </plugins>
  </build>
</project>
POM
  sed -i "s|__GROUP_ID__|$GROUP_ID|; s|__APP_NAME__|$APP_NAME|g; s|__JAVA__|$JAVA_RELEASE|" "$PROJ_DIR/pom.xml"
  cat > "$PROJ_DIR/src/main/java/${PACKAGE//./\/}/DemoApplication.java" <<JAVA
package $PACKAGE;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
@SpringBootApplication public class DemoApplication {
  public static void main(String[] args){ SpringApplication.run(DemoApplication.class,args); }
}
JAVA
fi

# Controller + config
mkdir -p "$PROJ_DIR/src/main/java/${PACKAGE//./\/}" "$PROJ_DIR/src/main/resources"
cat > "$PROJ_DIR/src/main/java/${PACKAGE//./\/}/HelloController.java" <<JAVA
package $PACKAGE;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;
@RestController
public class HelloController {
  @GetMapping("/") public String root(){ return "It works! 🎉 ($APP_NAME)"; }
  @GetMapping("/api/hello") public Map<String,String> api(){ return Map.of("ok","true","app","$APP_NAME"); }
}
JAVA

cat > "$PROJ_DIR/src/main/resources/application.properties" <<PROPS
server.forward-headers-strategy=framework
management.endpoints.web.exposure.include=health,info,prometheus
management.endpoint.health.probes.enabled=true
management.health.livenessstate.enabled=true
management.health.readinessstate.enabled=true
PROPS

# -------------- Build + SBOM + checksums -------------
log "Building fat JAR + SBOM..."
cd "$PROJ_DIR"
# keep a persistent Maven cache under /opt/<app> for faster idempotent builds
M2_LOCAL="$INSTALL_DIR/.m2/repository"; sudo mkdir -p "$M2_LOCAL"; sudo chown -R "$USER":"$USER" "$INSTALL_DIR/.m2"
mvn -q -Dmaven.repo.local="$M2_LOCAL" -DskipTests package
mvn -q -Dmaven.repo.local="$M2_LOCAL" -DskipTests org.cyclonedx:cyclonedx-maven-plugin:2.8.0:makeAggregateBom || true

JAR_BUILT="$(find target -maxdepth 1 -type f -name "*.jar" ! -name "*sources.jar" | head -n1)"
[ -n "$JAR_BUILT" ] || die "Build failed: no JAR."
RELEASE_DIR="$RELEASES_DIR/release-${TS}"
sudo mkdir -p "$RELEASE_DIR"
sudo cp -f "$JAR_BUILT" "$RELEASE_DIR/app.jar"
[ -f "target/bom.xml" ] && sudo cp -f target/bom.xml "$RELEASE_DIR/SBOM-cyclonedx.xml" || true
sudo sha256sum "$RELEASE_DIR/app.jar" | sudo tee "$CHECKSUMS_DIR/app-${TS}.sha256" >/dev/null
sudo ln -sfn "$RELEASE_DIR" "$CURRENT_DIR_LINK"
sudo chown -R "$APP_NAME:$APP_NAME" "$INSTALL_DIR"

# Optional Trivy scan (non-blocking)
if command -v trivy >/dev/null 2>&1; then
  log "Trivy scan (best-effort)..."
  trivy fs --quiet --scanners vuln,secret "$RELEASE_DIR" || true
fi
# Optional cosign attestation
if [ "$ENABLE_ATTESTATION" = "1" ] && command -v cosign >/dev/null 2>&1 && [ -n "$COSIGN_KEY_PATH" ]; then
  log "Generating local cosign attestation..."
  (cd "$RELEASE_DIR" && cosign attest --predicate SBOM-cyclonedx.xml --key "$COSIGN_KEY_PATH" --type cyclonedx ./app.jar) || true
fi

# Retention
CNT="$(ls -1dt "$RELEASES_DIR"/release-* 2>/dev/null | wc -l || echo 0)"
if [ "$CNT" -gt "$KEEP_RELEASES" ]; then
  ls -1dt "$RELEASES_DIR"/release-* | tail -n +"$((KEEP_RELEASES+1))" | xargs -r sudo rm -rf --
fi

# --------------- systemd hardened template ---------------
sudo bash -c "cat > '$ENV_FILE'" <<ENVV
JAVA_OPTS="-XX:+UseZGC -Xms256m -Xmx512m -XX:MaxRAMPercentage=75"
SPRING_PROFILES_ACTIVE="prod"
ENVV
if [ "$JAVA_TLS13_ONLY" = "1" ]; then
  echo 'JAVA_OPTS="$JAVA_OPTS -Djdk.tls.client.protocols=TLSv1.3 -Djdk.tls.server.protocols=TLSv1.3 -Dhttps.protocols=TLSv1.3"' | sudo tee -a "$ENV_FILE" >/dev/null
fi
sudo chown "$APP_NAME:$APP_NAME" "$ENV_FILE"; sudo chmod 0644 "$ENV_FILE"

sudo bash -c "cat > '$SVC_TEMPLATE'" <<'UNIT'
[Unit]
Description=%i Spring Boot (hardened)
Wants=network-online.target
After=network-online.target

[Service]
User=__USER__
EnvironmentFile=__ENV_FILE__
WorkingDirectory=__INSTALL_DIR__
ExecStart=/usr/bin/java $JAVA_OPTS -jar __CURRENT__/app.jar --server.port=%i
Restart=always
RestartSec=2
SuccessExitStatus=143
StandardOutput=journal
StandardError=journal
KillSignal=SIGTERM

# Hardening (see systemd.exec(5))
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
ProtectKernelLogs=yes
ProtectProc=invisible
ProcSubset=pid
RestrictRealtime=yes
RestrictSUIDSGID=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes
CapabilityBoundingSet=
AmbientCapabilities=
SystemCallArchitectures=native
RestrictAddressFamilies=AF_INET AF_INET6
LimitNOFILE=65535
TasksMax=2000
TimeoutStartSec=90
TimeoutStopSec=25

# Resource controls (see systemd.resource-control(5))
CPUQuota=__CPU_QUOTA__
# MemoryMax can be empty -> ignored
__MEMORY_MAX_LINE__
UNIT
MEM_LINE=""
[ "$MEMORY_MAX" != "0" ] && MEM_LINE="MemoryMax=$MEMORY_MAX"
sudo sed -i \
  -e "s|__USER__|$APP_NAME|" \
  -e "s|__ENV_FILE__|$ENV_FILE|" \
  -e "s|__INSTALL_DIR__|$INSTALL_DIR|" \
  -e "s|__CURRENT__|$CURRENT_DIR_LINK|" \
  -e "s|__CPU_QUOTA__|$CPU_QUOTA|" \
  -e "s|__MEMORY_MAX_LINE__|$MEM_LINE|" \
  "$SVC_TEMPLATE"

# Optional egress lockdown
if [ "$LOCKDOWN_NET" = "1" ]; then
  ALLOW_LINES=""
  for cidr in $ALLOW_NET_CIDRS; do ALLOW_LINES="${ALLOW_LINES}IPAddressAllow=${cidr}\n"; done
  sudo awk -v allows="$ALLOW_LINES" '
    /ProtectHostname=yes/ && !x { print; print "IPAddressDeny=any\n" allows; x=1; next }1
  ' "$SVC_TEMPLATE" | sudo tee "$SVC_TEMPLATE.tmp" >/dev/null
  sudo mv -f "$SVC_TEMPLATE.tmp" "$SVC_TEMPLATE"
fi

sudo systemctl daemon-reload

# ---------------- Start new color & health gate --------------
log "Starting new instance on :$INACTIVE_PORT ..."
sudo systemctl restart "${APP_NAME}@${INACTIVE_PORT}" || sudo systemctl start "${APP_NAME}@${INACTIVE_PORT}"

for i in {1..60}; do
  if curl -fsS "http://127.0.0.1:${INACTIVE_PORT}/actuator/health" | grep -q '"status":"UP"'; then
    log "New instance healthy."
    break
  fi
  sleep 1
  if [ $i -eq 60 ]; then
    sudo journalctl -u "${APP_NAME}@${INACTIVE_PORT}" -n 200 --no-pager || true
    die "Instance on :${INACTIVE_PORT} did not become healthy."
  fi
done

# ------------------- Nginx site (advanced) ------------------
if [ "$USE_NGINX" = "yes" ]; then
  # Optionally enable brotli module (best-effort)
  if [ "$ENABLE_BROTLI" != "no" ]; then
    if [ "$ENABLE_BROTLI" = "yes" ] || sudo apt-get install -y libnginx-mod-brotli >/dev/null 2>&1; then
      sudo ln -sf /usr/lib/nginx/modules/ngx_http_brotli_filter_module.so /etc/nginx/modules-enabled/50-mod-brotli-filter.conf 2>/dev/null || true
      sudo ln -sf /usr/lib/nginx/modules/ngx_http_brotli_static_module.so /etc/nginx/modules-enabled/50-mod-brotli-static.conf 2>/dev/null || true
    fi
  fi

  # Upstream (canary or single)
  if [ "$CANARY_PERCENT" -gt 0 ] && systemctl is-active --quiet "${APP_NAME}@${ACTIVE_PORT}"; then
    OLD_W=$((100-CANARY_PERCENT)); NEW_W=$CANARY_PERCENT
    UPSTREAM_BLOCK="upstream ${APP_NAME}_upstream { server 127.0.0.1:${INACTIVE_PORT} weight=${NEW_W}; server 127.0.0.1:${ACTIVE_PORT} weight=${OLD_W}; }"
    log "Canary enabled: ${NEW_W}% new on :${INACTIVE_PORT}, ${OLD_W}% old on :${ACTIVE_PORT}"
  else
    UPSTREAM_BLOCK="upstream ${APP_NAME}_upstream { server 127.0.0.1:${INACTIVE_PORT}; }"
  fi

  # Allowlist for /actuator
  ALLOW_LINES=""
  IFS=',' read -ra CIDRS <<< "$ACTUATOR_ALLOW_CIDRS"
  for c in "${CIDRS[@]}"; do c_trim="$(echo "$c" | xargs)"; [ -n "$c_trim" ] && ALLOW_LINES="${ALLOW_LINES}    allow ${c_trim};\n"; done

  # Basic auth (optional)
  AUTH_LINES=""
  if [ "$BASIC_AUTH_ENABLE" = "1" ] && [ -n "$BASIC_AUTH_USER" ] && [ -n "$BASIC_AUTH_PASS" ]; then
    sudo mkdir -p /etc/nginx/auth
    # create/replace htpasswd file (APR1)
    printf "%s:%s\n" "$BASIC_AUTH_USER" "$(openssl passwd -apr1 "$BASIC_AUTH_PASS")" | sudo tee /etc/nginx/auth/${APP_NAME}.htpasswd >/dev/null
    AUTH_LINES='auth_basic "Restricted"; auth_basic_user_file /etc/nginx/auth/'"${APP_NAME}"'.htpasswd;'
  fi

  # mTLS (optional, only effective when TLS enabled below)
  MTLS_LINES=""
  if [ -n "$MTLS_CA_PEM" ] && [ -f "$MTLS_CA_PEM" ]; then
    sudo install -m 0644 "$MTLS_CA_PEM" /etc/nginx/${APP_NAME}-mtls-ca.pem
    MTLS_LINES=$'ssl_client_certificate /etc/nginx/'"${APP_NAME}"$'-mtls-ca.pem;\nssl_verify_client on;'
  fi

  sudo bash -c "cat > '$NGX_SITE'" <<NGX
$UPSTREAM_BLOCK

map \$http_upgrade \$connection_upgrade { default upgrade; '' close; }

server {
  listen 80;
  listen [::]:80;
  server_name ${DOMAIN:-_};
  server_tokens off;

  # Security headers (OWASP secure headers)
  add_header X-Content-Type-Options "nosniff" always;
  add_header X-Frame-Options "DENY" always;
  add_header Referrer-Policy "strict-origin-when-cross-origin" always;
  add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
  add_header Content-Security-Policy "default-src 'self'; frame-ancestors 'none'" always;
  add_header X-Release "${TS}" always;

  # Rate limit (leaky bucket)
  limit_req zone=reqs burst=${BURST} nodelay;

  gzip on;
  gzip_types text/plain text/css application/json application/javascript application/xml application/xhtml+xml image/svg+xml;
  brotli on;
  brotli_comp_level 5;
  brotli_types text/plain text/css application/json application/javascript application/xml application/xhtml+xml image/svg+xml;

  # Maintenance mode: create ${MAINTENANCE_FLAG} to return 503
  if (-f ${MAINTENANCE_FLAG}) { return 503; }
  error_page 503 @maint;
  location @maint { return 503 "Service under maintenance"; add_header Retry-After "120" always; }

  # Actuator — restrict by CIDR and protect with basic auth if enabled
  location /actuator/ {
${ALLOW_LINES}    deny all;
    $AUTH_LINES
    proxy_pass http://${APP_NAME}_upstream;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }

  # App
  location / {
    $AUTH_LINES
    proxy_pass http://${APP_NAME}_upstream;
    proxy_http_version 1.1;
    proxy_set_header Connection "\$connection_upgrade";
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_read_timeout 60s;
  }

  access_log /var/log/nginx/${APP_NAME}.access.log;
}
NGX

  # Ensure global rate limit zone exists (respect RATE)
  sudo bash -c "grep -q 'limit_req_zone' '$NGX_CONF' || sed -i \"1i limit_req_zone \\$binary_remote_addr zone=reqs:10m rate=${RATE};\" '$NGX_CONF'"

  # Logrotate for app access log (weekly, 8 rotations)
  sudo tee /etc/logrotate.d/nginx-${APP_NAME} >/dev/null <<ROT
/var/log/nginx/${APP_NAME}.access.log {
  weekly
  rotate 8
  missingok
  compress
  delaycompress
  notifempty
  create 0640 www-data adm
  sharedscripts
  postrotate
    [ -s /run/nginx.pid ] && kill -USR1 \`cat /run/nginx.pid\`
  endscript
}
ROT

  # Validate and reload Nginx; restore on failure
  if ! sudo nginx -t; then
    warn "nginx -t failed; reverting Nginx site changes."
    sudo rm -f "$NGX_SITE" || true
    sudo nginx -t && sudo systemctl reload nginx || true
  else
    sudo ln -sf "$NGX_SITE" "$NGX_LINK"
    sudo systemctl reload nginx
  fi
fi

# ---------------- Flip or keep canary ----------------
if [ "$USE_NGINX" = "yes" ] && [ "$CANARY_PERCENT" -eq 0 -o "$PROMOTE" = "1" ]; then
  if systemctl is-active --quiet "${APP_NAME}@${ACTIVE_PORT}"; then
    log "Draining old instance on :$ACTIVE_PORT for ${DRAIN_SECONDS}s..."
    sleep "$DRAIN_SECONDS"
    sudo systemctl stop "${APP_NAME}@${ACTIVE_PORT}" || true
  fi
fi
echo "$INACTIVE_PORT" | sudo tee "$ACTIVE_FILE" >/dev/null

# ---------------- TLS / mTLS (optional) ----------------
if [ -n "$DOMAIN" ] && [ -n "$EMAIL" ] && [ "$USE_NGINX" = "yes" ]; then
  log "Requesting/renewing Let's Encrypt cert for $DOMAIN ..."
  sudo ufw allow 80/tcp >/dev/null 2>&1 || true
  sudo ufw allow 443/tcp >/dev/null 2>&1 || true
  sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" || true
  # Harden TLS & enable HTTP/2; apply mTLS if configured
  if [ -n "$MTLS_LINES" ]; then
    sudo awk -v mtls="$MTLS_LINES" '
      /server_name/ && !x { print; print "  listen 443 ssl http2;"; print "  " mtls; print "  ssl_protocols TLSv1.2 TLSv1.3;"; x=1; next }1
    ' "$NGX_SITE" | sudo tee "$NGX_SITE.tmp" >/dev/null
  else
    sudo awk '
      /server_name/ && !x { print; print "  listen 443 ssl http2;"; print "  ssl_protocols TLSv1.2 TLSv1.3;"; x=1; next }1
    ' "$NGX_SITE" | sudo tee "$NGX_SITE.tmp" >/dev/null
  fi
  sudo mv -f "$NGX_SITE.tmp" "$NGX_SITE"
  sudo nginx -t && sudo systemctl reload nginx
fi

# ---------------- Audit / Drift manifest ----------------
JAVA_VER="$(java -version 2>&1 | tr '\n' ' ' | sed 's/"/\\"/g')"
NGX_VER="$(nginx -v 2>&1 | sed 's|nginx version: ||' || true)"
APP_JAR_SHA256="$(sha256sum "$CURRENT_DIR_LINK/app.jar" | awk '{print $1}')"
NGX_SITE_SHA256="$(sha256sum "$NGX_SITE" 2>/dev/null | awk '{print $1}')"
SVC_SHA256="$(sha256sum "$SVC_TEMPLATE" | awk '{print $1}')"
sudo bash -c "cat > '$AUDIT_FILE'" <<JSON
{
  "timestamp": "$TS",
  "app": "$APP_NAME",
  "active_port": "$(cat "$ACTIVE_FILE")",
  "release": "$(basename "$(readlink -f "$CURRENT_DIR_LINK")")",
  "jar_sha256": "$APP_JAR_SHA256",
  "sbom": "$( [ -f "$CURRENT_DIR_LINK/SBOM-cyclonedx.xml" ] && echo present || echo absent )",
  "nginx_site_sha256": "${NGX_SITE_SHA256:-absent}",
  "systemd_unit_sha256": "$SVC_SHA256",
  "java_version": "$JAVA_VER",
  "nginx_version": "$NGX_VER",
  "debug_enabled": "$DEBUG"
}
JSON

# ---------------- Final probe & summary ----------------
IP="$(hostname -I | awk '{print $1}')"
PUBLIC_URL="${DOMAIN:+https://$DOMAIN/}"; [ -z "$PUBLIC_URL" ] && PUBLIC_URL="http://$IP/"

log "Probing ${PUBLIC_URL} ..."
curl -fsS "$PUBLIC_URL" >/dev/null && echo "OK" || echo "Probe failed (service may still be warming)."

echo "------------------------------------------------------------"
echo "App         : $APP_NAME"
echo "Active port : $(cat "$ACTIVE_FILE")"
echo "Install dir : $INSTALL_DIR  (current -> $(readlink -f "$CURRENT_DIR_LINK"))"
echo "SBOM        : $(readlink -f "$CURRENT_DIR_LINK")/SBOM-cyclonedx.xml (if generated)"
echo "Checksums   : $CHECKSUMS_DIR"
echo "Audit file  : $AUDIT_FILE"
echo "Service     : ${APP_NAME}@<port>   e.g. systemctl status ${APP_NAME}@$(cat "$ACTIVE_FILE")"
echo "Nginx site  : $NGX_SITE"
echo "URL         : ${PUBLIC_URL}"
if [ "$CANARY_PERCENT" -gt 0 ] && [ "$PROMOTE" = "0" ]; then
  echo "Canary      : ${CANARY_PERCENT}% new on :$INACTIVE_PORT (PROMOTE=1 to finalize)"
fi
echo "SSH Safety  : OpenSSH ensured active; 22/tcp allow persisted. No firewall tightening performed."
echo "Logs        : $LOG_FILE  (set DEBUG=0 to reduce verbosity)"
echo "------------------------------------------------------------"
# Contents

1. [Foundations (Start Here)](#1-foundations-start-here)
2. [Workload Manifests (YAML that ships)](#2-workload-manifests-yaml-that-ships)
3. [Packaging & Templates (Helm & Kustomize)](#3-packaging--templates-helm--kustomize)
4. [Daily Workflow (kubectl, contexts, namespaces)](#4-daily-workflow-kubectl-contexts-namespaces)
5. [Scheduling & Runtime (reliability knobs)](#5-scheduling--runtime-reliability-knobs)
6. [Data & Storage (PVs, PVCs, CSI)](#6-data--storage-pvs-pvcs-csi)
7. [Networking (Services, Ingress/Gateway, NetworkPolicy)](#7-networking-services-ingressgateway-networkpolicy)
8. [Observability (logs, metrics, traces, events)](#8-observability-logs-metrics-traces-events)
9. [Security Hardening (RBAC, PSA, policy)](#9-security-hardening-rbac-psa-policy)
10. [Supply Chain & Registries (images, signing, pulls)](#10-supply-chain--registries-images-signing-pulls)
11. [Cluster Operations (upgrades, nodes, config)](#11-cluster-operations-upgrades-nodes-config)
12. [GPUs & Specialized Runtimes (device plugins)](#12-gpus--specialized-runtimes-device-plugins)
13. [Cross-Platform & Cloud (EKS/GKE/AKS specifics)](#13-crossplatform--cloud-eksgkeaks-specifics)
14. [CI/CD with Kubernetes (GitOps & rollout)](#14-cicd-with-kubernetes-gitops--rollout)
15. [Troubleshooting Playbook](#15-troubleshooting-playbook)
16. [Patterns, Anti-Patterns & Architecture](#16-patterns-anti-patterns--architecture)
17. [Platform & Control-Plane Security](#17-platform--controlplane-security)
18. [Real-World Ops Runbook](#18-realworld-ops-runbook)

---

## 1) Foundations (Start Here)

**Topics (sub-categories):**

* What Kubernetes is (declarative API, controllers, reconciliation)
* Cluster anatomy: control plane vs nodes; CRI (containerd), CNI, CSI
* Install & verify: kubectl, a local cluster (kind/minikube), kubeconfig & contexts
* Object basics: metadata/spec/status; labels, selectors, annotations

**Learning objectives (80/20)**

* Explain how a Deployment becomes Pods via controllers.
* Switch clusters/namespaces with kubeconfig confidently.
* Read any YAML and tell what it creates and how it’s selected.

**Hands-on (80/20 sprint)**

1. Install kubectl; create a kind cluster; `kubectl get nodes -o wide`.
2. Deploy `nginx` as a Deployment; `kubectl get deploy,rs,pods`.
3. Create a second namespace; switch contexts; list only that ns.

**Proof-of-skill**

* One-page diagram of control plane & node workflow + the exact `kubectl` used.

---

## 2) Workload Manifests (YAML that ships)

**Topics:**

* Pods (init, sidecar, ephemeral containers), Deployments & ReplicaSets
* StatefulSets, DaemonSets, Jobs & CronJobs
* Probes (liveness/readiness/startup), env, volumes, resources
* Strategy: rolling updates, revision history, rollbacks

**Learning objectives (80/20)**

* Write clean manifests for Deployments and Jobs with probes & resources.
* Roll forward/back safely; understand when to use StatefulSet vs Deployment.
* Add a sidecar (e.g., log shipper) without breaking readiness.

**Hands-on**

1. Deployment with `readinessProbe` & resource requests/limits.
2. CronJob that runs a script and writes to a PVC.
3. Add a sidecar container for access logs and prove it’s healthy.

**Proof-of-skill**

* Repo with `/manifests` and a README explaining object choices & probes.

---

## 3) Packaging & Templates (Helm & Kustomize)

**Topics:**

* Helm: charts, values, templating, lint/test; dependency mgmt
* Kustomize: bases/overlays, patches, strategic vs JSON6902
* When to prefer Helm vs Kustomize; mixing sanely
* Jsonnet/YTT (awareness) for platform teams

**Learning objectives**

* Package an app as a Helm chart with sane defaults.
* Build env-specific overlays with Kustomize (dev/stage/prod).
* Avoid values sprawl; document the contract (`values.yaml`).

**Hands-on**

1. Convert raw YAML → Helm chart; publish to an internal chart repo.
2. Create Kustomize overlays for dev/prod toggling replicas, resources, Ingress.
3. `helm test` and `helm upgrade --install` in a test namespace.

**Proof-of-skill**

* `packaging.md` comparing Helm vs Kustomize + a runnable example of both.

---

## 4) Daily Workflow (kubectl, contexts, namespaces)

**Topics:**

* CRUD with `kubectl apply`/`delete`; `--dry-run=server`, `-o yaml`
* Logs, exec, port-forward; `kubectl debug` & ephemeral containers
* Context/namespace helpers; shell autocomplete; `krew` plugins

**Learning objectives**

* Diagnose Pods with logs/exec/describe in minutes.
* Use ephemeral debug containers to triage broken images.
* Maintain a tidy kubeconfig with named contexts.

**Hands-on**

1. Break a Pod (bad env); fix it with `kubectl describe` & logs.
2. Use `kubectl debug` to add tools into a running Pod.
3. Port-forward a DB and run a smoke query.

**Proof-of-skill**

* “Golden kubectl” cheat sheet tailored to your team.

---

## 5) Scheduling & Runtime (reliability knobs)

**Topics:**

* Requests/limits → QoS classes; CPU/mem management
* Probes & graceful termination; `terminationGracePeriodSeconds`
* Taints/tolerations; node/pod affinity & anti-affinity
* Topology spread constraints; PDBs; draining; priority/preemption

**Learning objectives**

* Keep apps highly available across zones using spread + PDB.
* Prevent noisy neighbors with correct requests/limits.
* Drain nodes safely without violating availability SLOs.

**Hands-on**

1. Add topology spread to a Deployment; simulate a zone failure.
2. Create a PDB; roll a node drain and observe behavior.
3. Pin a system DaemonSet via tolerations/affinity.

**Proof-of-skill**

* Runbook showing safe drain/upgrade steps with screenshots/logs.

---

## 6) Data & Storage (PVs, PVCs, CSI)

**Topics:**

* Volumes vs PVC/PV; StorageClasses; dynamic provisioning
* Access modes (RWO/RWX), `ReadWriteOncePod`; reclaim policy
* Volume snapshots & restore; ephemeral volumes; CSI drivers

**Learning objectives**

* Choose the right StorageClass & access mode for each workload.
* Snapshot and restore a stateful app quickly.
* Migrate data safely across StorageClasses.

**Hands-on**

1. Deploy Postgres with a PVC; take a VolumeSnapshot; restore to new PVC.
2. Change reclaim policy and observe behavior on delete.
3. Benchmark RWX vs RWO for a test workload.

**Proof-of-skill**

* Backup/restore SOP with commands and verification steps.

---

## 7) Networking (Services, Ingress/Gateway, NetworkPolicy)

**Topics:**

* Services: ClusterIP/NodePort/LoadBalancer; EndpointSlice; internalTrafficPolicy
* Ingress vs Gateway API; controllers (NGINX, cloud L7)
* DNS in cluster; kube-proxy modes; MTU & hairpin NAT awareness
* NetworkPolicy: default-deny + allow rules; egress control

**Learning objectives**

* Expose services via Ingress/Gateway with TLS and path routing.
* Implement default-deny east/west and permit only required traffic.
* Debug DNS/Service selection issues quickly.

**Hands-on**

1. Deploy a web app with TLS via Gateway or Ingress.
2. Implement `default-deny` NetworkPolicy + explicit allows.
3. Verify EndpointSlices, internal traffic policy, and service reachability.

**Proof-of-skill**

* `networking.md` diagrams of North-South & East-West paths + working manifests.

---

## 8) Observability (logs, metrics, traces, events)

**Topics:**

* Events & structured app logs; cluster logging patterns
* metrics-server, kube-state-metrics; Prometheus fundamentals
* Grafana dashboards (golden signals); Alerting rules
* Tracing with OpenTelemetry Operator

**Learning objectives**

* Surface workload & cluster health with SLO-aligned dashboards.
* Set alerts that catch real issues (not noise).
* Instrument a service with distributed tracing.

**Hands-on**

1. Install metrics-server + kube-prometheus-stack.
2. Create service-level SLO dashboards (RPS/latency/errors/saturation).
3. Add OpenTelemetry sidecar/SDK and view a trace.

**Proof-of-skill**

* Screens of dashboards + alert rules in git.

---

## 9) Security Hardening (RBAC, PSA, policy)

**Topics:**

* RBAC design (least privilege, verbs, aggregation)
* Pod Security Admission (baseline/restricted)
* Policy as code (Kyverno/Gatekeeper): image rules, labels, PSS, defaults
* ImagePullSecrets, private registries, minimal images

**Learning objectives**

* Lock down namespaces with restricted PSA + required labels.
* Enforce policies blocking root, privileged, hostPath, \:latest tags.
* Delegate least-privilege roles to teams safely.

**Hands-on**

1. Apply restricted PSA; verify it blocks bad Pods.
2. Add Kyverno/Gatekeeper policies and test violations.
3. Create a read-only role for a team and bind it.

**Proof-of-skill**

* Security policy bundle in git + proof of denied/allowed workloads.

---

## 10) Supply Chain & Registries (images, signing, pulls)

**Topics:**

* Signed images (cosign/notation); admission checks
* Pull secrets & registry auth; private ECR/GCR/ACR/GHCR
* Image provenance & SBOMs; pinned digests
* Quarantine & promotion repos; retention & GC

**Learning objectives**

* Verify image signatures on admission.
* Pin by digest for prod; keep SBOM artifacts.
* Operate a private registry with retention and GC.

**Hands-on**

1. Sign an image; enforce signature verification via policy.
2. Configure ImagePullSecrets and pull from private registry.
3. Promote images between repos with digest pinning.

**Proof-of-skill**

* `supply-chain.md` with policy screenshots and CI logs.

---

## 11) Cluster Operations (upgrades, nodes, config)

**Topics:**

* Version skew & safe upgrades (control plane first)
* Node lifecycle: cordon/drain/uncordon; autoscaling groups
* Cluster autoscaler (infra), cloud controllers
* Config management: admission configs, API server flags (awareness)

**Learning objectives**

* Plan and execute minor version upgrades without downtime.
* Rotate/replace nodes safely and predictably.
* Keep cluster config in git and auditable.

**Hands-on**

1. Practice a minor upgrade on a test cluster.
2. Rotate a node pool with PDB checks.
3. Validate cluster after upgrade with smoke tests.

**Proof-of-skill**

* Upgrade runbook + success criteria and rollback steps.

---

## 12) GPUs & Specialized Runtimes (device plugins)

**Topics:**

* NVIDIA device plugin & runtimeClass; CDI awareness
* Scheduling GPU workloads; resource quotas for GPUs
* Other device plugins (SR-IOV, AI accelerators)

**Learning objectives**

* Run a GPU workload & verify device visibility.
* Control GPU access via quotas and namespace policy.

**Hands-on**

1. Install NVIDIA plugin; run a CUDA sample Pod; `nvidia-smi`.
2. Add ResourceQuota limiting GPU consumption in a namespace.

**Proof-of-skill**

* GPU quickstart with manifests and benchmark numbers.

---

## 13) Cross-Platform & Cloud (EKS/GKE/AKS specifics)

**Topics:**

* Cloud LB controllers (ALB/NLB, GCLB, App Gateway), annotations
* IAM integration (IRSA/Workload Identity/Managed Identity)
* Regional/zone topologies; multi-cluster ingress/gateway (awareness)
* Costs: node types, spot/preemptible, autoscaling

**Learning objectives**

* Ship a production Ingress with TLS and health checks on your cloud.
* Attach Pods to cloud IAM securely (no node-wide secrets).
* Control cost via node mix & autoscaling.

**Hands-on**

1. Deploy an app with cloud L7/L4 ingress & TLS.
2. Configure workload IAM (e.g., IRSA) and access a secret store.
3. Prove cost deltas between instance types with a load test.

**Proof-of-skill**

* Cloud-specific guide with annotations & IAM config.

---

## 14) CI/CD with Kubernetes (GitOps & rollout)

**Topics:**

* GitOps (Argo CD/Flux): drift detection, app-of-apps, promotion flows
* Progressive delivery (Argo Rollouts): canary/blue-green
* Pre-deploy checks: policy, scans, dry-runs

**Learning objectives**

* Bootstrap GitOps and deploy via pull requests.
* Roll out a canary with automated analysis & rollback.
* Enforce policy/scans in the pipeline before sync.

**Hands-on**

1. Install Argo CD; sync a sample app from git.
2. Add Argo Rollouts with a 10%→50%→100% canary.
3. Break policy in a PR and show it getting blocked.

**Proof-of-skill**

* CI/CD YAML + Argo screenshots + a rollback event.

---

## 15) Troubleshooting Playbook

**Topics:**

* CrashLoopBackOff & OOMKill triage; probe failures
* “Pending” Pods (quota, PDB, affinity, taints)
* Service/Ingress 502/503; DNS issues; EndpointSlice gaps
* PVC/PV binding & node mount errors; Events great-circle

**Learning objectives**

* Identify failures fast from `describe`, Events, and logs.
* Map symptoms → subsystem (sched/net/storage/security).

**Hands-on**

1. Reproduce: bad readiness probe; fix and confirm.
2. Reproduce: Pending Pod due to quota/taint; resolve.
3. Reproduce: PVC stuck; fix StorageClass/binding.

**Proof-of-skill**

* `troubleshooting.md`: symptom → commands → root cause → fix.

---

## 16) Patterns, Anti-Patterns & Architecture

**Topics:**

* 12-factor defaults for k8s; config via env/Secrets; stdout logs
* Multi-tenancy: namespaces, quotas, PSA; team templates
* Don’t: hostPath, privileged, \:latest, in-cluster DBs (for prod)
* Move from single cluster → multi-cluster (when/why)

**Learning objectives**

* Ship “boring good” k8s apps by default.
* Choose tenancy boundaries and templates wisely.

**Hands-on**

1. Create a “Golden Namespace” template with quotas/PSA/labels.
2. Rework a legacy app to 12-factor + readiness + resource caps.

**Proof-of-skill**

* Architecture note with trade-offs and defaults.

---

## 17) Platform & Control-Plane Security

**Topics:**

* API server audit logs; admission webhooks; rate limits
* etcd security (encryption at rest, TLS, snapshots)
* Securing the kubelet & node OS; restricted SSH; minimal AMIs
* Secret stores (Vault/Cloud KMS via CSI); rotation runbooks

**Learning objectives**

* Capture/audit sensitive API actions.
* Protect etcd and rotate snapshots/keys.
* Offload secrets to external stores with CSI.

**Hands-on**

1. Enable/collect audit logs and search for a risky action.
2. Take/restore an etcd snapshot in a sandbox.
3. Mount a secret from a provider via CSI & rotate it.

**Proof-of-skill**

* `platform-security.md` + evidence (logs, snapshots, policies).

---

## 18) Real-World Ops Runbook

**Topics:**

* Weekly: image/signature verification, log & event review
* Monthly: base image refresh, Helm/Kustomize dependency bumps
* Quarterly: upgrade rehearsal, backup/DR game day, policy audit
* Pre-release: canary, health checks, capacity & PDB review

**Learning objectives**

* Treat the cluster like a product with time-boxed maintenance.
* Keep evidence (dashboards, logs, tickets) for audits.

**Hands-on**

1. Calendar jobs/pipelines for scans, bumps, and audits.
2. Run a DR drill: restore a namespace from backup.

**Proof-of-skill**

* `ops-runbook.md` with checklists, scripts, and sample reports.
