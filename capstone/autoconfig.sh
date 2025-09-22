#!/usr/bin/env bash
# Idempotent tri-service app (Next.js + Flask + Postgres) with verbose diagnostics
# Public: frontend on :12000  |  Internal only: backend<->db
# Group control watcher included (stop any one -> stop all; restart main -> restart aux)

set -Eeuo pipefail

#############################################
# Verbose error trap + diagnostics
#############################################
SCRIPT_NAME="$(basename "$0")"
APP_ROOT="/opt/triapp"
ENV_FILE="${APP_ROOT}/.env"
COMPOSE_FILE="${APP_ROOT}/docker-compose.yml"

on_err() {
  local exit_code=$?
  local line=${BASH_LINENO[0]:-0}
  local cmd=${BASH_COMMAND:-"<unknown>"}
  echo
  echo "────────────────────────────────────────────────────────────────"
  echo "[x] ${SCRIPT_NAME} failed"
  echo "    ↳ Exit code : ${exit_code}"
  echo "    ↳ At line   : ${line}"
  echo "    ↳ Command   : ${cmd}"
  echo "────────────────────────────────────────────────────────────────"
  echo "[*] Quick diagnostics:"
  echo "    - Docker version: $(docker --version 2>/dev/null || echo 'not found')"
  if command -v docker >/dev/null 2>&1; then
    echo "    - Compose version: $($COMPOSE_BIN version 2>/dev/null || echo 'not found')"
  fi

  if [[ -f "$COMPOSE_FILE" ]]; then
    echo
    echo "    ► docker compose ps"
    $COMPOSE_BIN -f "$COMPOSE_FILE" ps || true

    echo
    echo "    ► docker compose config (first 120 lines)"
    $COMPOSE_BIN -f "$COMPOSE_FILE" config | sed -n '1,120p' || true
  fi

  echo
  echo "    ► Port checks"
  FRONTEND_PORT="$(grep -E '^FRONTEND_PORT=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || echo '12000')"
  if command -v ss >/dev/null 2>&1; then
    ss -tulpn 2>/dev/null | grep -E ":${FRONTEND_PORT}\b" || echo "      (No process listening on :${FRONTEND_PORT})"
  else
    netstat -tulpn 2>/dev/null | grep -E ":${FRONTEND_PORT}\b" || echo "      (No process listening on :${FRONTEND_PORT})"
  fi

  echo
  echo "    ► Container health (db, backend, frontend)"
  if [[ -f "$COMPOSE_FILE" ]]; then
    for svc in db backend frontend; do
      cid="$($COMPOSE_BIN -f "$COMPOSE_FILE" ps -q "$svc" 2>/dev/null || true)"
      [[ -z "$cid" ]] && { echo "      - $svc: no container"; continue; }
      st="$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$cid" 2>/dev/null || echo '?')"
      echo "      - $svc: $st"
    done
  fi

  echo
  echo "    ► Last 120 lines of DB logs (if any)"
  [[ -f "$COMPOSE_FILE" ]] && $COMPOSE_BIN -f "$COMPOSE_FILE" logs --tail=120 db || true

  echo
  echo "    ► Last 120 lines of BACKEND logs (if any)"
  [[ -f "$COMPOSE_FILE" ]] && $COMPOSE_BIN -f "$COMPOSE_FILE" logs --tail=120 backend || true

  echo
  echo "    ► Last 120 lines of FRONTEND logs (if any)"
  [[ -f "$COMPOSE_FILE" ]] && $COMPOSE_BIN -f "$COMPOSE_FILE" logs --tail=120 frontend || true

  # Heuristic suggestions
  echo
  echo "[!] Suggested fixes:"
  if [[ -f "$COMPOSE_FILE" ]]; then
    db_logs="$($COMPOSE_BIN -f "$COMPOSE_FILE" logs --no-color --tail=500 db 2>/dev/null || true)"
    be_logs="$($COMPOSE_BIN -f "$COMPOSE_FILE" logs --no-color --tail=200 backend 2>/dev/null || true)"

    if echo "$db_logs" | grep -qiE 'Operation not permitted|chown|setuid|setgid'; then
      echo "    - Postgres init permissions/capabilities error. Script now avoids over-strict caps on DB."
      echo "      Rerun: sudo bash $SCRIPT_NAME up"
    fi
    if echo "$db_logs" | grep -qiE 'FATAL.*role.*root'; then
      echo "    - DB healthcheck log about role 'root' is harmless (pg_isready probe)."
    fi
    if echo "$be_logs" | grep -qiE 'SyntaxError|Traceback'; then
      echo "    - Backend Python error detected. Script now rewrites a correct backend/app.py."
      echo "      If you customized it, check the lines around routes and rerun: sudo bash $SCRIPT_NAME up"
    fi
  fi

  echo
  echo "    - If port ${FRONTEND_PORT} is taken, edit ${ENV_FILE} -> FRONTEND_PORT=<free_port> and rerun:"
  echo "        sudo bash $SCRIPT_NAME up"
  echo
  echo "[i] The script is idempotent. Fix the cause above and rerun the same command."
  echo "────────────────────────────────────────────────────────────────"
  exit "$exit_code"
}
trap on_err ERR

#############################################
# Basics / Globals
#############################################
require_root() { if [[ $EUID -ne 0 ]]; then echo "Please run with sudo or as root." >&2; exit 1; fi; }
log()  { printf "[*] %s\n" "$*"; }
warn() { printf "[!] %s\n" "$*" >&2; }
die()  { printf "[x] %s\n" "$*" >&2; exit 1; }

WATCHER_SCRIPT="${APP_ROOT}/scripts/compose-watcher.sh"
WATCHER_UNIT="/etc/systemd/system/triapp-watcher.service"
DEFAULT_APP_NAME="triapp"
DEFAULT_FRONTEND_PORT="12000"

rand_b64() { openssl rand -base64 48 | tr -d '\n'; }
rand_hex() { openssl rand -hex 32   | tr -d '\n'; }
os_id() { . /etc/os-release 2>/dev/null || true; echo "${ID:-unknown}"; }

choose_compose_cmd() {
  if docker compose version >/dev/null 2>&1; then echo "docker compose"
  elif docker-compose version >/dev/null 2>&1; then echo "docker-compose"
  else echo ""
  fi
}

ensure_prereqs() {
  local os; os="$(os_id)"
  if ! command -v docker >/dev/null 2>&1; then
    log "Installing Docker..."
    case "$os" in
      ubuntu|debian)
        apt-get update -y
        apt-get install -y ca-certificates curl gnupg lsb-release
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/${os}/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        local codename; codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-$UBUNTU_CODENAME}")"
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${os} ${codename} stable" > /etc/apt/sources.list.d/docker.list
        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin jq
        ;;
      centos|rhel|rocky|almalinux)
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true
        yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin jq
        ;;
      *) die "Unsupported OS '$os'. Install Docker, Compose, and jq manually, then rerun." ;;
    esac
    systemctl enable --now docker
  else
    log "Docker present."
    systemctl enable --now docker || true
    if ! command -v jq >/dev/null 2>&1; then
      case "$os" in
        ubuntu|debian) apt-get update -y && apt-get install -y jq ;;
        centos|rhel|rocky|almalinux) yum install -y jq ;;
      esac
    fi
  fi

  COMPOSE_BIN="$(choose_compose_cmd)"
  if [[ -z "$COMPOSE_BIN" ]]; then
    if docker compose version >/dev/null 2>&1; then COMPOSE_BIN="docker compose"
    elif docker-compose version >/dev/null 2>&1; then COMPOSE_BIN="docker-compose"
    else die "No docker compose found even after install."
    fi
  fi
}

#############################################
# .env management (idempotent, user-overridable)
#############################################
declare -A ENVV
load_env_file() {
  ENVV=()
  if [[ -f "$ENV_FILE" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      [[ "$line" != *"="* ]] && continue
      local key="${line%%=*}"; local val="${line#*=}"; val="${val%$'\r'}"
      ENVV["$key"]="$val"
    done < "$ENV_FILE"
  fi
}
getv() { local k="$1" d="$2"; echo "${ENVV[$k]:-$d}"; }

write_env_file() {
  mkdir -p "$APP_ROOT"
  load_env_file

  local APP_NAME FRONTEND_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD
  local FLASK_SECRET SESSION_COOKIE_NAME COOKIE_SECURE CSRF_SECRET RATE_LIMIT
  local NEXT_PUBLIC_APP_NAME NEXT_TELEMETRY_DISABLED API_INTERNAL_BASE

  APP_NAME="$(getv APP_NAME "$DEFAULT_APP_NAME")"
  FRONTEND_PORT="$(getv FRONTEND_PORT "$DEFAULT_FRONTEND_PORT")"

  POSTGRES_DB="$(getv POSTGRES_DB "appdb")"
  POSTGRES_USER="$(getv POSTGRES_USER "app")"
  POSTGRES_PASSWORD="$(getv POSTGRES_PASSWORD "$(openssl rand -hex 24)")"

  FLASK_SECRET="$(getv FLASK_SECRET "$(rand_b64)")"
  SESSION_COOKIE_NAME="$(getv SESSION_COOKIE_NAME "triapp_session")"
  COOKIE_SECURE="$(getv COOKIE_SECURE "false")"
  CSRF_SECRET="$(getv CSRF_SECRET "$(rand_hex)")"
  RATE_LIMIT="$(getv RATE_LIMIT "200/hour")"

  NEXT_PUBLIC_APP_NAME="$(getv NEXT_PUBLIC_APP_NAME "TriApp")"
  NEXT_TELEMETRY_DISABLED="$(getv NEXT_TELEMETRY_DISABLED "1")"
  API_INTERNAL_BASE="$(getv API_INTERNAL_BASE "http://backend:5000")"

  cat > "$ENV_FILE" <<EOF
# ====== TriApp environment (.env) ======
# Edit as needed and rerun autoconfig.sh; changes will be applied.
APP_NAME=${APP_NAME}
FRONTEND_PORT=${FRONTEND_PORT}

# Database
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# Backend
FLASK_SECRET=${FLASK_SECRET}
SESSION_COOKIE_NAME=${SESSION_COOKIE_NAME}
COOKIE_SECURE=${COOKIE_SECURE}
CSRF_SECRET=${CSRF_SECRET}
RATE_LIMIT=${RATE_LIMIT}

# Frontend
NEXT_PUBLIC_APP_NAME=${NEXT_PUBLIC_APP_NAME}
NEXT_TELEMETRY_DISABLED=${NEXT_TELEMETRY_DISABLED}

# Internal URLs
API_INTERNAL_BASE=${API_INTERNAL_BASE}
EOF
}

#############################################
# Compose + App files
#############################################
write_compose_file() {
  # DB keeps default capabilities (needed at init). Backend/Frontend drop caps.
  cat > "$COMPOSE_FILE" <<'YML'
name: ${APP_NAME}
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    environment:
      - NEXT_PUBLIC_APP_NAME=${NEXT_PUBLIC_APP_NAME}
      - API_INTERNAL_BASE=${API_INTERNAL_BASE}
    ports:
      - "${FRONTEND_PORT:-12000}:3000"
    depends_on:
      backend:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:3000/healthz || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 10
    security_opt:
      - no-new-privileges:true
    cap_drop: ["ALL"]
    read_only: true
    tmpfs: ["/tmp"]
    user: "10001:10001"
    networks:
      - web_net
      - app_net
    labels:
      com.triapp.role: main

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    environment:
      - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      - FLASK_SECRET=${FLASK_SECRET}
      - SESSION_COOKIE_NAME=${SESSION_COOKIE_NAME}
      - COOKIE_SECURE=${COOKIE_SECURE}
      - CSRF_SECRET=${CSRF_SECRET}
      - RATE_LIMIT=${RATE_LIMIT}
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:5000/healthz || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 10
    security_opt:
      - no-new-privileges:true
    cap_drop: ["ALL"]
    read_only: true
    tmpfs: ["/tmp"]
    user: "10002:10002"
    networks:
      - app_net
      - db_net
    expose:
      - "5000"

  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - triapp_db:/var/lib/postgresql/data
      - ./db/init.sql:/docker-entrypoint-initdb.d/001_init.sql:ro
    restart: unless-stopped
    healthcheck:
      # Credential-agnostic server readiness
      test: ["CMD-SHELL", "pg_isready -q -h 127.0.0.1 -p 5432 || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 30
    networks:
      - db_net
    expose:
      - "5432"

networks:
  web_net: {}            # public-facing for frontend only
  app_net:
    internal: true       # frontend <-> backend only
  db_net:
    internal: true       # backend  <-> db only

volumes:
  triapp_db:
YML
}

write_frontend() {
  mkdir -p "${APP_ROOT}/frontend/pages" "${APP_ROOT}/frontend/public" "${APP_ROOT}/frontend/components"
  cat > "${APP_ROOT}/frontend/package.json" <<'PKG'
{
  "name": "triapp-frontend",
  "private": true,
  "scripts": { "build": "next build", "start": "next start -p 3000", "dev": "next dev -p 3000" },
  "dependencies": { "next": "14.2.5", "react": "18.2.0", "react-dom": "18.2.0" }
}
PKG

  cat > "${APP_ROOT}/frontend/next.config.js" <<'NCFG'
/** @type {import('next').NextConfig} */
const securityHeaders = [
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(), interest-cohort=()' },
  // COOP removed for HTTP to avoid console noise. Re-enable under HTTPS.
  { key: 'Cross-Origin-Resource-Policy', value: 'same-origin' },
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      "img-src 'self' data:",
      "style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com",
      "script-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com",
      "font-src 'self' https://cdnjs.cloudflare.com data:",
      "connect-src 'self'"
    ].join('; ')
  }
];
const nextConfig = {
  async headers() { return [{ source: '/(.*)', headers: securityHeaders }]; },
  async rewrites() { return [{ source: '/api/:path*', destination: 'http://backend:5000/api/:path*' }]; }
};
module.exports = nextConfig;
NCFG

  cat > "${APP_ROOT}/frontend/pages/_app.js" <<'APP'
import React from 'react';
import Head from 'next/head';

export default function MyApp({ Component, pageProps }) {
  return (
    <>
      <Head>
        {/* Bootstrap 5 */}
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.3/css/bootstrap.min.css" crossOrigin="anonymous" referrerPolicy="no-referrer" />
        <script defer src="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.3/js/bootstrap.bundle.min.js" crossOrigin="anonymous" referrerPolicy="no-referrer"></script>
        {/* Animate.css */}
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/animate.css/4.1.1/animate.min.css" crossOrigin="anonymous" referrerPolicy="no-referrer" />
        {/* SweetAlert2 */}
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/limonte-sweetalert2/11.12.4/sweetalert2.min.css" crossOrigin="anonymous" referrerPolicy="no-referrer" />
        <script defer src="https://cdnjs.cloudflare.com/ajax/libs/limonte-sweetalert2/11.12.4/sweetalert2.all.min.js" crossOrigin="anonymous" referrerPolicy="no-referrer"></script>
        {/* Font Awesome */}
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.6.0/css/all.min.css" crossOrigin="anonymous" referrerPolicy="no-referrer" />
        <title>{process.env.NEXT_PUBLIC_APP_NAME || 'TriApp'}</title>
      </Head>
      <div className="bg-light min-vh-100">
        <nav className="navbar navbar-expand-lg navbar-dark bg-dark">
          <div className="container">
            <a className="navbar-brand" href="/">{process.env.NEXT_PUBLIC_APP_NAME || 'TriApp'}</a>
            <div className="d-flex gap-2">
              <a className="btn btn-outline-light btn-sm" href="/login">Login / Signup</a>
            </div>
          </div>
        </nav>
        <main className="container py-5">
          <Component {...pageProps} />
        </main>
        <footer className="text-center text-muted py-4">
          <small>© {new Date().getFullYear()} TriApp</small>
        </footer>
      </div>
    </>
  );
}
APP

  cat > "${APP_ROOT}/frontend/pages/healthz.js" <<'HZ'
export default function Health() { return "ok"; }
export async function getServerSideProps(){ return {props:{}} }
HZ

  cat > "${APP_ROOT}/frontend/pages/index.js" <<'INDEX'
import Link from 'next/link';

export default function Home() {
  return (
    <div className="row justify-content-center text-center animate__animated animate__fadeInUp">
      <div className="col-lg-8">
        <h1 className="display-5 fw-bold mb-3">{process.env.NEXT_PUBLIC_APP_NAME || 'TriApp'}</h1>
        <p className="lead text-muted">Secure, containerized Next.js + Flask + Postgres starter with enterprise‑grade auth.</p>
        <div className="d-flex gap-3 justify-content-center mt-4">
          <Link className="btn btn-primary btn-lg" href="/login"><i className="fa-solid fa-right-to-bracket me-2"></i>Login / Sign up</Link>
          <a className="btn btn-outline-secondary btn-lg" href="#features"><i className="fa-solid fa-shield-halved me-2"></i>Security</a>
        </div>
        <img alt="hero" src="data:image/svg+xml;base64,PHN2ZyB3aWR0aD0nNjQwJyBoZWlnaHQ9JzMyMCcgeG1sbnM9J2h0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnJz48cmVjdCB3aWR0aD0nNjQwJyBoZWlnaHQ9JzMyMCcgcng9JzIwJyBmaWxsPSIjZWVlIi8+PHRleHQgeD0iNTAlIiB5PSIxNjAiIGR5PSIuMzVlbSIgZm9udC1zaXplPSI0MHB4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjY2NjIj5OZXh0LmpzICsgRmxhc2sgKyBQb3N0Z3JlczwvdGV4dD48L3N2Zz4=" className="img-fluid rounded shadow mt-4" />
        <div id="features" className="row mt-5 g-3">
          <div className="col-md-4"><div className="card h-100"><div className="card-body"><i className="fa-solid fa-lock fa-2x mb-2"></i><h5>CSRF + HttpOnly Sessions</h5><p className="text-muted">Secure-by-default auth with rate limiting.</p></div></div></div>
          <div className="col-md-4"><div className="card h-100"><div className="card-body"><i className="fa-solid fa-box fa-2x mb-2"></i><h5>Dockerized</h5><p className="text-muted">Separate containers and internal networks.</p></div></div></div>
          <div className="col-md-4"><div className="card h-100"><div className="card-body"><i className="fa-solid fa-gauge-high fa-2x mb-2"></i><h5>Fast & Minimal</h5><p className="text-muted">Production‑ready structure with sane defaults.</p></div></div></div>
        </div>
      </div>
    </div>
  );
}
INDEX

  cat > "${APP_ROOT}/frontend/pages/login.js" <<'LOGIN'
import { useState, useEffect } from 'react';
import { useRouter } from 'next/router';

export default function Login() {
  const [mode, setMode] = useState('login'); // 'login' | 'signup'
  const [signupStep, setSignupStep] = useState('form'); // 'form' | 'verify'
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [otp, setOtp] = useState('');
  const [qr, setQr] = useState(null);
  const [confirmToken, setConfirmToken] = useState('');
  const [msg, setMsg] = useState('');
  const [secondsLeft, setSecondsLeft] = useState(180);
  const router = useRouter();

  // Prime CSRF cookie so POSTs don't 403
  useEffect(() => { fetch('/api/csrf', { method: 'GET', credentials: 'include' }).catch(() => {}); }, []);

  // Countdown while QR is visible
  useEffect(() => {
    if (mode === 'signup' && signupStep === 'verify') {
      const t = setInterval(() => setSecondsLeft((s) => (s > 0 ? s - 1 : 0)), 1000);
      return () => clearInterval(t);
    }
  }, [mode, signupStep]);

  const handleSignup = async (e) => {
    e.preventDefault(); setMsg('');
    try {
      const res = await fetch('/api/auth/signup', {
        method: 'POST',
        headers: {'Content-Type':'application/json', 'X-CSRF-Token': 'browser'},
        credentials: 'include',
        body: JSON.stringify({ email, password }),
      });
      const ct = res.headers.get('content-type') || '';
      const data = ct.includes('application/json') ? await res.json() : { error: (await res.text()).slice(0, 200) };
      if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
      setQr(data.qr_png_data_url);
      setConfirmToken(data.confirm_token);
      setSignupStep('verify');
      setSecondsLeft(180);
      setOtp('');
      setMsg('');
      // Fancy toast
      window.Swal?.fire({ icon:'success', title:'Account created!', text:'Scan the QR with an Authenticator app, then enter the 6‑digit code.', timer:2200, showConfirmButton:false });
    } catch (err) {
      setMsg(err.message);
    }
  };

  const confirm2FA = async (e) => {
    e?.preventDefault?.();
    setMsg('');
    try {
      const res = await fetch('/api/auth/confirm-2fa', {
        method: 'POST',
        headers: {'Content-Type':'application/json', 'X-CSRF-Token': 'browser'},
        credentials: 'include',
        body: JSON.stringify({ token: confirmToken, otp }),
      });
      const data = await res.json().catch(async () => ({ error: (await res.text()).slice(0,200) }));
      if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
      window.Swal?.fire({ icon:'success', title:'2FA enabled', text:'Welcome! Redirecting to your dashboard...', timer:1600, showConfirmButton:false });
      setTimeout(()=> router.push('/dashboard'), 900);
    } catch (err) {
      setMsg(err.message);
    }
  };

  const login = async (e) => {
    e.preventDefault(); setMsg('');
    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: {'Content-Type':'application/json', 'X-CSRF-Token': 'browser'},
        credentials: 'include',
        body: JSON.stringify({ email, password, otp }),
      });
      const data = await res.json().catch(async () => ({ error: (await res.text()).slice(0,200) }));
      if (res.status === 401 && data.need_otp) {
        setMsg('Enter your 6‑digit code from the authenticator and submit again.');
        return;
      }
      if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
      window.Swal?.fire({ icon:'success', title:'Logged in', timer:1200, showConfirmButton:false });
      router.push('/dashboard');
    } catch (err) { setMsg(err.message); }
  };

  const cardClasses = "card shadow-sm animate__animated animate__fadeInUp";
  return (
    <div className="row justify-content-center">
      <div className="col-md-6 col-lg-5">
        <div className={cardClasses}>
          <div className="card-body p-4">
            <h1 className="h3 mb-3 fw-bold">{mode === 'signup'
              ? (signupStep === 'verify' ? 'Enable 2FA' : 'Sign up')
              : 'Login'}</h1>

            {mode === 'signup' && signupStep === 'form' && (
              <form onSubmit={handleSignup} className="needs-validation" noValidate>
                <div className="mb-3">
                  <label className="form-label">Email</label>
                  <input type="email" className="form-control" required value={email} onChange={e=>setEmail(e.target.value)} />
                </div>
                <div className="mb-3">
                  <label className="form-label">Password</label>
                  <input type="password" className="form-control" required value={password} onChange={e=>setPassword(e.target.value)} />
                </div>
                <button className="btn btn-primary w-100" type="submit">
                  <i className="fa-solid fa-user-plus me-2"></i>Create account
                </button>
                <p className="text-center mt-3">
                  <button type="button" className="btn btn-link" onClick={()=>{setMode('login'); setMsg('');}}>Switch to Login</button>
                </p>
              </form>
            )}

            {mode === 'signup' && signupStep === 'verify' && (
              <>
                <div className="alert alert-info d-flex align-items-center" role="alert">
                  <i className="fa-solid fa-shield-halved me-2"></i>
                  Scan the QR in Google Authenticator, 1Password, Authy, etc., then enter the current 6‑digit code.
                </div>
                <div className="text-center my-3">
                  {qr && <img alt="TOTP QR" src={qr} className="img-fluid rounded border" style={{maxWidth:260}} />}
                  <div className="mt-2 text-muted small">Time left to scan: {secondsLeft}s</div>
                </div>
                <form onSubmit={confirm2FA}>
                  <div className="mb-3">
                    <label className="form-label">Authenticator code</label>
                    <input type="text" inputMode="numeric" pattern="[0-9]*" className="form-control" placeholder="123456" value={otp} onChange={e=>setOtp(e.target.value)} required />
                  </div>
                  <button className="btn btn-success w-100" type="submit">
                    <i className="fa-solid fa-check me-2"></i>Confirm & continue
                  </button>
                </form>
                <p className="text-center mt-3">
                  <button type="button" className="btn btn-link" onClick={()=>{ setSignupStep('form'); setOtp(''); setQr(null); setMsg(''); }}>
                    Start over
                  </button>
                </p>
              </>
            )}

            {mode === 'login' && (
              <form onSubmit={login}>
                <div className="mb-3">
                  <label className="form-label">Email</label>
                  <input type="email" className="form-control" required value={email} onChange={e=>setEmail(e.target.value)} />
                </div>
                <div className="mb-3">
                  <label className="form-label">Password</label>
                  <input type="password" className="form-control" required value={password} onChange={e=>setPassword(e.target.value)} />
                </div>
                <div className="mb-3">
                  <label className="form-label">OTP (if enabled)</label>
                  <input type="text" className="form-control" placeholder="123456" value={otp} onChange={e=>setOtp(e.target.value)} />
                </div>
                <button className="btn btn-primary w-100" type="submit">
                  <i className="fa-solid fa-right-to-bracket me-2"></i>Sign in
                </button>
                <p className="text-center mt-3">
                  <button type="button" className="btn btn-link" onClick={()=>{ setMode('signup'); setSignupStep('form'); setOtp(''); setMsg(''); }}>
                    Switch to Signup
                  </button>
                </p>
              </form>
            )}

            {msg && <p className="mt-2 text-danger">{msg}</p>}
          </div>
        </div>
      </div>
    </div>
  );
}
LOGIN

  cat > "${APP_ROOT}/frontend/pages/dashboard.js" <<'DASH'
import Link from 'next/link';
import { useState } from 'react';

export async function getServerSideProps(context) {
  const cookie = context.req.headers.cookie || '';
  const res = await fetch('http://backend:5000/api/me', { headers: { cookie } });
  if (res.status === 401) return { redirect: { destination: '/login', permanent: false } };
  const me = await res.json();

  const eventsRes = await fetch('http://backend:5000/api/login-events', { headers: { cookie } });
  const events = eventsRes.ok ? await eventsRes.json() : [];

  const pgRes = await fetch('http://backend:5000/api/pg-info', { headers: { cookie } });
  const pg = pgRes.ok ? await pgRes.json() : {};

  return { props: { me, events, pg } };
}

export default function Dashboard({ me, events, pg }) {
  const [totp, setTotp] = useState(!!me.totp_enabled);

  const enable2FA = async () => {
    try {
      const res = await fetch('/api/auth/setup-2fa', { method:'POST', headers:{'X-CSRF-Token':'browser'}, credentials:'include' });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Failed to start 2FA setup');
      const { qr_png_data_url, confirm_token } = data;
      const html = `
        <div class="text-center">
          <img src="${qr_png_data_url}" class="img-fluid rounded border mb-3" style="max-width:240px" />
          <div class="mb-2">Scan with your authenticator, then enter the 6‑digit code:</div>
          <input id="otp-input" class="swal2-input" placeholder="123456" inputmode="numeric" maxlength="6" />
        </div>`;
      const r = await window.Swal.fire({
        title: 'Enable 2FA',
        html, focusConfirm: false, showCancelButton: true, confirmButtonText: 'Confirm',
        preConfirm: () => document.getElementById('otp-input')?.value || ''
      });
      if (!r.isConfirmed) return;
      const otp = r.value;
      const res2 = await fetch('/api/auth/confirm-2fa', {
        method:'POST', headers:{'Content-Type':'application/json','X-CSRF-Token':'browser'}, credentials:'include',
        body: JSON.stringify({ token: confirm_token, otp })
      });
      const data2 = await res2.json();
      if (!res2.ok) throw new Error(data2.error || 'Invalid code');
      setTotp(true);
      await window.Swal.fire({ icon:'success', title:'2FA enabled', timer:1400, showConfirmButton:false });
    } catch (e) {
      window.Swal.fire({ icon:'error', title:'Failed', text: e.message });
    }
  };

  const disable2FA = async () => {
    const r = await window.Swal.fire({
      title: 'Disable 2FA',
      html: `<input id="pw" type="password" class="swal2-input" placeholder="Confirm your password" />`,
      showCancelButton: true, confirmButtonText: 'Disable'
    });
    if (!r.isConfirmed) return;
    const pw = document.getElementById('pw')?.value || '';
    try {
      const res = await fetch('/api/auth/disable-2fa', {
        method:'POST', headers:{'Content-Type':'application/json','X-CSRF-Token':'browser'}, credentials:'include',
        body: JSON.stringify({ password: pw })
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Failed');
      setTotp(false);
      await window.Swal.fire({ icon:'success', title:'2FA disabled', timer:1400, showConfirmButton:false });
    } catch (e) {
      window.Swal.fire({ icon:'error', title:'Failed', text: e.message });
    }
  };

  return (
    <div className="animate__animated animate__fadeIn">
      <div className="row g-4">
        <div className="col-lg-8">
          <div className="card shadow-sm">
            <div className="card-body">
              <h1 className="h4 mb-0">Welcome, {me.email}</h1>
              <div className="text-muted">Live Postgres: v{pg.version || '—'} · {pg.now || '—'}</div>
              <hr/>
              <h2 className="h5">Recent logins</h2>
              <div className="table-responsive">
                <table className="table table-sm align-middle">
                  <thead className="table-light"><tr><th>When (UTC)</th><th>IP</th><th>Success</th></tr></thead>
                  <tbody>
                  {events.map((e, i) => (<tr key={i}><td>{e.at}</td><td>{e.ip}</td><td>{String(e.ok)}</td></tr>))}
                  {!events.length && <tr><td colSpan={3} className="text-center text-muted">No events</td></tr>}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>

        <div className="col-lg-4">
          <div className="card shadow-sm">
            <div className="card-body">
              <h2 className="h5 mb-3">Security Center</h2>
              <div className="d-flex align-items-center mb-3">
                <i className={`fa-solid ${totp ? 'fa-shield-halved text-success' : 'fa-shield text-secondary'} me-2`}></i>
                <span>2FA: <b>{totp ? 'Enabled' : 'Disabled'}</b></span>
              </div>
              {totp ? (
                <button className="btn btn-outline-danger w-100" onClick={disable2FA}>
                  <i className="fa-solid fa-toggle-off me-2"></i>Disable 2FA
                </button>
              ) : (
                <button className="btn btn-outline-primary w-100" onClick={enable2FA}>
                  <i className="fa-solid fa-toggle-on me-2"></i>Enable 2FA
                </button>
              )}
              <hr/>
              <a className="btn btn-secondary w-100" href="/api/auth/logout">Log out</a>
              <p className="text-center mt-2"><Link href="/">Home</Link></p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

DASH

  cat > "${APP_ROOT}/frontend/Dockerfile" <<'DFE'
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json ./
RUN npm install --no-audit --no-fund

FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN addgroup -g 10001 nodeapp && adduser -D -H -u 10001 -G nodeapp nodeapp
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/.next ./.next
COPY --from=build /app/public ./public
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/package.json ./
RUN addgroup -g 10001 nodeapp && adduser -D -H -u 10001 -G nodeapp nodeapp
RUN apk add --no-cache curl
USER 10001:10001
EXPOSE 3000
CMD ["npm", "start"]
DFE
}

write_backend() {
  mkdir -p "${APP_ROOT}/backend"
  cat > "${APP_ROOT}/backend/requirements.txt" <<'REQ'
Flask==3.0.3
itsdangerous==2.1.2
psycopg2-binary==2.9.9
argon2-cffi==23.1.0
pyotp==2.9.0
qrcode==7.4.2
Pillow==10.3.0
Flask-Limiter==3.7.0
gunicorn==21.2.0
REQ

  # FIXED: removed invalid "u = ...; if not u: ..." one-liner; now proper multi-line.
  cat > "${APP_ROOT}/backend/app.py" <<'PY'
import os, base64, json
from datetime import datetime as dt
from flask import Flask, request, jsonify, make_response, abort
import psycopg2, psycopg2.extras
from itsdangerous import URLSafeTimedSerializer, BadSignature
from argon2 import PasswordHasher
import pyotp, qrcode
from io import BytesIO
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from ipaddress import ip_address

DATABASE_URL = os.environ.get("DATABASE_URL")
FLASK_SECRET = os.environ.get("FLASK_SECRET", "dev")
SESSION_COOKIE_NAME = os.environ.get("SESSION_COOKIE_NAME", "triapp_session")
COOKIE_SECURE = os.environ.get("COOKIE_SECURE", "false").lower() == "true"
CSRF_SECRET = os.environ.get("CSRF_SECRET", "dev")
RATE_LIMIT = os.environ.get("RATE_LIMIT", "200/hour")

app = Flask(__name__)
app.config.update(SESSION_COOKIE_NAME=SESSION_COOKIE_NAME)
limiter = Limiter(get_remote_address, app=app, default_limits=[RATE_LIMIT])

ph = PasswordHasher()
signer = URLSafeTimedSerializer(FLASK_SECRET, salt="session-signer")
csrf_signer = URLSafeTimedSerializer(CSRF_SECRET, salt="csrf-signer")

def db():
    return psycopg2.connect(DATABASE_URL, cursor_factory=psycopg2.extras.RealDictCursor)

def init_db():
    with db() as conn, conn.cursor() as cur:
        cur.execute("CREATE EXTENSION IF NOT EXISTS citext;")
        cur.execute("""
        CREATE TABLE IF NOT EXISTS users(
            id SERIAL PRIMARY KEY,
            email CITEXT UNIQUE NOT NULL,
            passhash TEXT NOT NULL,
            totp_secret TEXT,
            created_at TIMESTAMPTZ DEFAULT now()
        );
        CREATE TABLE IF NOT EXISTS sessions(
            sid TEXT PRIMARY KEY,
            user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMPTZ DEFAULT now(),
            last_seen TIMESTAMPTZ DEFAULT now(),
            expires_at TIMESTAMPTZ NOT NULL
        );
        CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON sessions(user_id);
        CREATE TABLE IF NOT EXISTS login_events(
            id BIGSERIAL PRIMARY KEY,
            user_email CITEXT,
            ip inet,
            ok BOOLEAN,
            at TIMESTAMPTZ DEFAULT now()
        );
        """)
        conn.commit()

@app.route("/healthz")
def healthz():
    return "ok", 200

@app.get("/api/csrf")
def issue_csrf():
    """Prime a CSRF cookie for first-time clients so POSTs don't 403."""
    csrf = csrf_signer.dumps({"ts": int(dt.utcnow().timestamp())})
    resp = make_response(jsonify({"ok": True}))
    resp.set_cookie("csrf", csrf, httponly=False, samesite="Strict", secure=COOKIE_SECURE, max_age=12*3600, path="/")
    return resp

def get_client_ip():
    fwd = request.headers.get("X-Forwarded-For", "").split(",")[0].strip()
    ip = fwd or request.remote_addr or "0.0.0.0"
    try:
        ip_address(ip)
    except Exception:
        ip = "0.0.0.0"
    return ip

def set_session(user_id: int):
    sid_raw = base64.urlsafe_b64encode(os.urandom(32)).decode().rstrip("=")
    sid = signer.dumps({"sid": sid_raw})
    with db() as conn, conn.cursor() as cur:
        cur.execute("INSERT INTO sessions(sid, user_id, expires_at) VALUES(%s,%s, now()+ interval '12 hours')", (sid, user_id))
        conn.commit()
    resp = make_response(jsonify({"ok": True}))
    resp.set_cookie(SESSION_COOKIE_NAME, sid, httponly=True, samesite="Strict", secure=COOKIE_SECURE, max_age=12*3600, path="/")
    csrf = csrf_signer.dumps({"ts": int(dt.utcnow().timestamp())})
    resp.set_cookie("csrf", csrf, httponly=False, samesite="Strict", secure=COOKIE_SECURE, max_age=12*3600, path="/")
    return resp

def clear_session():
    sid = request.cookies.get(SESSION_COOKIE_NAME)
    if sid:
        with db() as conn, conn.cursor() as cur:
            cur.execute("DELETE FROM sessions WHERE sid=%s", (sid,))
            conn.commit()
    resp = make_response(jsonify({"ok": True}))
    resp.set_cookie(SESSION_COOKIE_NAME, "", max_age=0, path="/")
    resp.set_cookie("csrf", "", max_age=0, path="/")
    return resp

def current_user():
    sid = request.cookies.get(SESSION_COOKIE_NAME)
    if not sid:
        return None
    try:
        signer.loads(sid, max_age=60*60*24*2)
    except BadSignature:
        return None
    with db() as conn, conn.cursor() as cur:
        cur.execute("""SELECT u.id, u.email, u.passhash, u.totp_secret,
                              (SELECT count(*) FROM sessions s2 WHERE s2.user_id = u.id) AS active_sessions
                       FROM users u JOIN sessions s ON s.user_id=u.id WHERE s.sid=%s""", (sid,))
        row = cur.fetchone()
        if not row:
            return None
        cur.execute("UPDATE sessions SET last_seen=now() WHERE sid=%s", (sid,))
        conn.commit()
        return row

def require_csrf():
    token = request.headers.get("X-CSRF-Token","")
    csrf_cookie = request.cookies.get("csrf","")
    try:
        csrf_signer.loads(csrf_cookie, max_age=12*3600)
    except BadSignature:
        abort(403)
    if token != "browser":
        abort(403)
    return True

# ---------- Auth & 2FA ----------

@app.post("/api/auth/signup")
@limiter.limit("20/hour")
def signup():
    """
    Create the user WITHOUT enabling 2FA yet.
    Return a QR + a signed confirm_token (uid+secret).
    The client will call /api/auth/confirm-2fa with the OTP to enable 2FA and create a session.
    """
    require_csrf()
    j = request.get_json(force=True)
    email = (j.get("email") or "").strip().lower()
    pw = j.get("password") or ""
    if not email or not pw:
        return jsonify({"error":"email/password required"}), 400
    try:
        pwhash = ph.hash(pw)
        with db() as conn, conn.cursor() as cur:
            cur.execute("INSERT INTO users(email, passhash, totp_secret) VALUES(%s,%s,%s) RETURNING id", (email, pwhash, None))
            uid = cur.fetchone()["id"]; conn.commit()
        # Generate TOTP secret but DO NOT store it yet
        secret = pyotp.random_base32()
        uri = pyotp.TOTP(secret).provisioning_uri(name=email, issuer_name="TriApp")
        img = qrcode.make(uri); buf = BytesIO(); img.save(buf, format="PNG")
        qr_b64 = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
        token = signer.dumps({"uid": uid, "secret": secret, "purpose": "setup2fa"})
        return jsonify({"ok": True, "qr_png_data_url": qr_b64, "confirm_token": token})
    except psycopg2.Error:
        return jsonify({"error":"Email already exists?"}), 400

@app.post("/api/auth/confirm-2fa")
@limiter.limit("40/hour")
def confirm_2fa():
    """Verify OTP for the provided confirm_token; on success, enable 2FA and start a session."""
    require_csrf()
    j = request.get_json(force=True)
    token = j.get("token") or ""
    otp = (j.get("otp") or "").strip()
    if not token or not otp:
        return jsonify({"error":"token and otp required"}), 400
    try:
        payload = signer.loads(token, max_age=15*60)  # 15 minutes
    except BadSignature:
        return jsonify({"error":"invalid or expired token"}), 400
    if payload.get("purpose") != "setup2fa":
        return jsonify({"error":"invalid token purpose"}), 400
    uid = int(payload["uid"]); secret = payload["secret"]
    if not pyotp.TOTP(secret).verify(otp, valid_window=1):
        return jsonify({"error":"invalid otp"}), 401
    with db() as conn, conn.cursor() as cur:
        cur.execute("UPDATE users SET totp_secret=%s WHERE id=%s", (secret, uid)); conn.commit()
        cur.execute("SELECT email FROM users WHERE id=%s", (uid,)); email = cur.fetchone()["email"]
        cur.execute("INSERT INTO login_events(user_email, ip, ok) VALUES(%s,%s,%s)", (email, get_client_ip(), True)); conn.commit()
    # Start session now
    return set_session(uid)

@app.post("/api/auth/setup-2fa")
def setup_2fa():
    """For logged-in users: generate a new secret & QR, but do NOT enable until confirmed via /confirm-2fa."""
    require_csrf()
    u = current_user()
    if not u:
        return jsonify({"error":"unauthorized"}), 401
    secret = pyotp.random_base32()
    uri = pyotp.TOTP(secret).provisioning_uri(name=u["email"], issuer_name="TriApp")
    img = qrcode.make(uri); buf = BytesIO(); img.save(buf, format="PNG")
    qr_b64 = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
    token = signer.dumps({"uid": int(u["id"]), "secret": secret, "purpose": "setup2fa"})
    return jsonify({"ok": True, "qr_png_data_url": qr_b64, "confirm_token": token})

@app.post("/api/auth/disable-2fa")
def disable_2fa():
    """Disable 2FA for the current user after password verification."""
    require_csrf()
    u = current_user()
    if not u:
        return jsonify({"error":"unauthorized"}), 401
    j = request.get_json(force=True)
    pw = j.get("password") or ""
    try:
        ph.verify(u["passhash"], pw)
    except Exception:
        return jsonify({"error":"incorrect password"}), 401
    with db() as conn, conn.cursor() as cur:
        cur.execute("UPDATE users SET totp_secret=NULL WHERE id=%s", (int(u["id"]),)); conn.commit()
    return jsonify({"ok": True})

@app.post("/api/auth/login")
@limiter.limit("30/hour")
def login():
    require_csrf()
    j = request.get_json(force=True)
    email = (j.get("email") or "").strip().lower()
    pw = j.get("password") or ""
    otp = (j.get("otp") or "").strip()
    if not email or not pw:
        return jsonify({"error":"email/password required"}), 400
    with db() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, passhash, totp_secret FROM users WHERE email=%s", (email,))
        u = cur.fetchone()
    if not u:
        with db() as conn, conn.cursor() as cur:
            cur.execute("INSERT INTO login_events(user_email, ip, ok) VALUES(%s,%s,%s)", (email, get_client_ip(), False)); conn.commit()
        return jsonify({"error":"invalid credentials"}), 401
    try:
        ph.verify(u["passhash"], pw)
    except Exception:
        with db() as conn, conn.cursor() as cur:
            cur.execute("INSERT INTO login_events(user_email, ip, ok) VALUES(%s,%s,%s)", (email, get_client_ip(), False)); conn.commit()
        return jsonify({"error":"invalid credentials"}), 401
    if u["totp_secret"]:
        if not otp:
            return jsonify({"need_otp": True}), 401
        if not pyotp.TOTP(u["totp_secret"]).verify(otp, valid_window=1):
            with db() as conn, conn.cursor() as cur:
                cur.execute("INSERT INTO login_events(user_email, ip, ok) VALUES(%s,%s,%s)", (email, get_client_ip(), False)); conn.commit()
            return jsonify({"error":"invalid otp"}), 401
    with db() as conn, conn.cursor() as cur:
        cur.execute("INSERT INTO login_events(user_email, ip, ok) VALUES(%s,%s,%s)", (email, get_client_ip(), True)); conn.commit()
    return set_session(u["id"])

@app.get("/api/auth/logout")
def logout():
    return clear_session()

@app.get("/api/me")
def me():
    u = current_user()
    if not u:
        return jsonify({"error": "unauthorized"}), 401
    return jsonify({"email": u["email"], "totp_enabled": bool(u["totp_secret"]), "active_sessions": int(u["active_sessions"])})

@app.get("/api/login-events")
def login_events():
    u = current_user()
    if not u:
        return jsonify([]), 401
    with db() as conn, conn.cursor() as cur:
        cur.execute("SELECT to_char(at AT TIME ZONE 'UTC','YYYY-MM-DD HH24:MI:SS') as at, host(ip) as ip, ok FROM login_events WHERE user_email=%s ORDER BY id DESC LIMIT 25", (u["email"],))
        return jsonify(cur.fetchall())

@app.get("/api/pg-info")
def pg_info():
    u = current_user()
    if not u:
        return jsonify({}), 401
    with db() as conn, conn.cursor() as cur:
        cur.execute("SELECT version(), now()")
        r = cur.fetchone()
        return jsonify({"version": r["version"], "now": str(r["now"])})

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)
PY

  cat > "${APP_ROOT}/backend/wsgi.py" <<'WSGI'
from app import app, init_db
init_db()
if __name__ != "__main__":
    application = app
WSGI

  cat > "${APP_ROOT}/backend/Dockerfile" <<'DFB'
FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN addgroup --system --gid 10002 appgrp && adduser --system --uid 10002 --ingroup appgrp appuser
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
USER 10002:10002
EXPOSE 5000
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "--timeout", "60", "wsgi:application"]
DFB
}

write_db_seed() {
  mkdir -p "${APP_ROOT}/db"
  cat > "${APP_ROOT}/db/init.sql" <<'SQL'
-- Reserved for seed/migrations; backend also ensures extensions/tables are present.
SQL
}

#############################################
# Watcher (group control)
#############################################
write_watcher() {
  mkdir -p "${APP_ROOT}/scripts" "${APP_ROOT}/systemd"
  cat > "$WATCHER_SCRIPT" <<'WATCH'
#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR="/opt/triapp"; cd "$APP_DIR"
APP_NAME="$(grep -E '^APP_NAME=' .env 2>/dev/null | cut -d= -f2- || true)"; APP_NAME="${APP_NAME:-triapp}"
choose_compose(){ if docker compose version >/dev/null 2>&1; then echo "docker compose"; elif docker-compose version >/dev/null 2>&1; then echo "docker-compose"; else echo "docker compose"; fi; }
COMPOSE_BIN="$(choose_compose)"
MAIN_SERVICE="frontend"; IGNORE_AUX_STOP_UNTIL=0; MAIN_RESTART_WINDOW_UNTIL=0
now(){ date +%s; } log(){ printf "[watcher] %s\n" "$*"; }
$COMPOSE_BIN -f "$APP_DIR/docker-compose.yml" up -d >/dev/null 2>&1 || true
docker events --format '{{json .}}' \
  --filter type=container \
  --filter "label=com.docker.compose.project=${APP_NAME}" \
  --filter event=stop --filter event=restart --filter event=start \
| while read -r line; do
    status="$(echo "$line" | jq -r '.status // empty')"
    svc="$(echo "$line"   | jq -r '.Actor.Attributes["com.docker.compose.service"] // empty')"
    [[ -z "$svc" || -z "$status" ]] && continue
    tnow="$(now)"
    if [[ "$svc" != "$MAIN_SERVICE" && "$status" == "stop" && $tnow -lt $IGNORE_AUX_STOP_UNTIL ]]; then
      log "ignoring stop on $svc (aux restart in progress)"; continue
    fi
    if [[ "$svc" == "$MAIN_SERVICE" && "$status" == "restart" ]]; then
      MAIN_RESTART_WINDOW_UNTIL=$((tnow + 20)); log "main restart detected; will restart aux after main starts"; continue
    fi
    if [[ "$svc" == "$MAIN_SERVICE" && "$status" == "start" && $tnow -lt $MAIN_RESTART_WINDOW_UNTIL ]]; then
      log "main started after restart; restarting backend & db"
      IGNORE_AUX_STOP_UNTIL=$((tnow + 20))
      $COMPOSE_BIN -f "$APP_DIR/docker-compose.yml" restart backend db || true
      MAIN_RESTART_WINDOW_UNTIL=0; continue
    fi
    if [[ "$status" == "stop" ]]; then
      log "container '$svc' stopped -> stopping entire stack"
      $COMPOSE_BIN -f "$APP_DIR/docker-compose.yml" stop || true
      continue
    fi
  done
WATCH
  chmod +x "$WATCHER_SCRIPT"

  cat > "${APP_ROOT}/systemd/triapp-watcher.service" <<'UNIT'
[Unit]
Description=TriApp Compose Watcher
Requires=docker.service
After=docker.service

[Service]
Type=simple
ExecStart=/bin/bash /opt/triapp/scripts/compose-watcher.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

  cp -f "${APP_ROOT}/systemd/triapp-watcher.service" "$WATCHER_UNIT"
  systemctl daemon-reload
  systemctl enable --now triapp-watcher.service
}

#############################################
# Preflight + bring-up
#############################################
wait_for_health() {
  # wait_for_health <service> <timeout_sec>
  local service="$1" timeout="${2:-180}" elapsed=0 status cid
  local project; project="$(grep -E '^APP_NAME=' "$ENV_FILE" | cut -d= -f2-)"
  while (( elapsed < timeout )); do
    cid="$(docker ps -a --filter "label=com.docker.compose.project=${project}" \
                     --filter "label=com.docker.compose.service=${service}" \
                     --format '{{.ID}}' | head -n 1)"
    if [[ -n "$cid" ]]; then
      status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || true)"
      if [[ "$status" == "healthy" || "$status" == "running" ]]; then return 0; fi
      if [[ "$status" == "exited" || "$status" == "dead" ]]; then return 1; fi
    fi
    sleep 3; elapsed=$((elapsed+3))
  done
  return 1
}

compose_up() {
  ( cd "$APP_ROOT" && $COMPOSE_BIN pull || true )
  ( cd "$APP_ROOT" && $COMPOSE_BIN up -d --build )

  echo "[*] Waiting for database to become healthy..."
  if wait_for_health "db" 180; then
    echo "[*] DB healthy. Ensuring backend becomes healthy..."
    ( cd "$APP_ROOT" && $COMPOSE_BIN up -d backend || true )
    if wait_for_health "backend" 240; then
      echo "[*] Backend healthy. Bringing up frontend..."
      ( cd "$APP_ROOT" && $COMPOSE_BIN up -d frontend || true )
    else
      echo
      echo "[x] Backend did NOT become healthy within timeout."
      echo "    ► Show last 200 lines of BACKEND logs:"
      ( cd "$APP_ROOT" && $COMPOSE_BIN logs --tail=200 backend || true )
      die "Backend unhealthy."
    fi
  else
    echo
    echo "[x] Database did NOT become healthy within timeout."
    echo "    ► Show last 200 lines of DB logs:"
    ( cd "$APP_ROOT" && $COMPOSE_BIN logs --tail=200 db || true )
    echo
    echo "[!] Common causes & fixes:"
    echo "    - Disk space or corrupted volume:"
    echo "        df -h"
    echo "        sudo bash ${SCRIPT_NAME} destroy   # WARNING: deletes DB data"
    echo "        sudo bash ${SCRIPT_NAME} up"
    die "Database unhealthy."
  fi

  # UFW permissive for :12000 if enabled (doesn't touch 22)
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow 12000/tcp >/dev/null 2>&1 || true
  fi
}

compose_stop() {
  if [[ -f "$COMPOSE_FILE" ]]; then
    ( cd "$APP_ROOT" && $COMPOSE_BIN stop || true )
  else
    warn "No compose file at $COMPOSE_FILE; nothing to stop."
  fi
}

compose_destroy() {
  systemctl disable --now triapp-watcher.service >/dev/null 2>&1 || true
  rm -f "$WATCHER_UNIT"; systemctl daemon-reload || true
  if [[ -f "$COMPOSE_FILE" ]]; then
    ( cd "$APP_ROOT" && $COMPOSE_BIN down -v --remove-orphans || true )
  fi
  # Remove both common volume name patterns (idempotent)
  docker volume rm -f triapp_triapp_db >/dev/null 2>&1 || true
  if [[ -f "$ENV_FILE" ]]; then
    appn="$(grep -E '^APP_NAME=' "$ENV_FILE" | cut -d= -f2- || echo "triapp")"
    docker volume rm -f "${appn}_triapp_db" >/dev/null 2>&1 || true
  fi
  rm -rf "$APP_ROOT"
  log "Destroyed all services, data, and watcher."
}

#############################################
# Menu + main actions
#############################################
menu() {
  echo
  echo "==== autoconfig.sh ===="
  echo "1) Create / Update & Run"
  echo "2) Stop containers"
  echo "3) Destroy EVERYTHING (containers, networks, volume, watcher)"
  echo "q) Quit"
  echo -n "Choose: "
}

write_all() {
  mkdir -p "$APP_ROOT"
  write_env_file
  write_compose_file
  write_frontend
  write_backend
  write_db_seed
}

main_up() {
  ensure_prereqs
  write_all
  compose_up
  write_watcher

  local port ip
  port="$(grep -E '^FRONTEND_PORT=' "$ENV_FILE" | cut -d= -f2-)"
  ip="$(curl -fsS ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo '<YOUR_VM_IP>')"
  echo
  echo "==============================================="
  echo " Deployed. Frontend: http://${ip}:${port}"
  echo " Compose project: $(grep -E '^APP_NAME=' "$ENV_FILE" | cut -d= -f2-)"
  echo " App dir: ${APP_ROOT}"
  echo " Rerun autoconfig.sh anytime to apply changes."
  echo "==============================================="

  echo
  echo "[*] Post-run status:"
  $COMPOSE_BIN -f "$COMPOSE_FILE" ps || true
}

main_stop()    { ensure_prereqs; ( [[ -f "$COMPOSE_FILE" ]] && $COMPOSE_BIN -f "$COMPOSE_FILE" stop ) || warn "Nothing to stop"; }
main_destroy() { ensure_prereqs; compose_destroy; }

#############################################
# Entry
#############################################
require_root
ensure_prereqs

action="${1:-}"
case "$action" in
  up|create|update|run) main_up ;;
  stop)                 main_stop ;;
  destroy|down|reset)   main_destroy ;;
  *)
    while true; do
      menu; read -r ans
      case "$ans" in
        1) main_up; break ;;
        2) main_stop; break ;;
        3) main_destroy; break ;;
        q|Q) exit 0 ;;
        *) echo "Invalid choice."; ;;
      esac
    done
    ;;
esac
