#!/usr/bin/env bash
# Idempotent tri-service app installer/manager for:
#   - Next.js (frontend, public on :12000)
#   - Flask (backend, internal only)
#   - Postgres (db, internal only)
# Includes a watcher that coordinates group stop/restart behavior.

set -Eeuo pipefail

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run with sudo or as root." >&2
    exit 1
  fi
}

# --------------- Config (constants) ---------------
APP_ROOT="/opt/triapp"           # Keep a stable path independent of APP_NAME
ENV_FILE="${APP_ROOT}/.env"
COMPOSE_FILE="${APP_ROOT}/docker-compose.yml"
WATCHER_SCRIPT="${APP_ROOT}/scripts/compose-watcher.sh"
WATCHER_UNIT="/etc/systemd/system/triapp-watcher.service"
DEFAULT_APP_NAME="triapp"
DEFAULT_FRONTEND_PORT="12000"

# --------------- Utilities ---------------
log() { printf "[*] %s\n" "$*"; }
warn() { printf "[!] %s\n" "$*" >&2; }
die() { printf "[x] %s\n" "$*" >&2; exit 1; }

rand_b64() { openssl rand -base64 48 | tr -d '\n'; }
rand_hex() { openssl rand -hex 32 | tr -d '\n'; }

os_id() { . /etc/os-release 2>/dev/null || true; echo "${ID:-unknown}"; }

choose_compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif docker-compose version >/dev/null 2>&1; then
    echo "docker-compose"
  else
    echo ""  # will trigger install in ensure_prereqs
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
      *)
        die "Unsupported OS '$os'. Install Docker, Compose, and jq manually, then rerun."
        ;;
    esac
    systemctl enable --now docker
  else
    log "Docker present."
    systemctl enable --now docker || true
    # jq might still be missing
    if ! command -v jq >/dev/null 2>&1; then
      case "$os" in
        ubuntu|debian) apt-get update -y && apt-get install -y jq ;;
        centos|rhel|rocky|almalinux) yum install -y jq ;;
      esac
    fi
  fi

  COMPOSE_BIN="$(choose_compose_cmd)"
  if [[ -z "$COMPOSE_BIN" ]]; then
    # Docker compose plugin should be installed above; re-check
    if docker compose version >/dev/null 2>&1; then
      COMPOSE_BIN="docker compose"
    elif docker-compose version >/dev/null 2>&1; then
      COMPOSE_BIN="docker-compose"
    else
      die "No docker compose found even after install."
    fi
  fi
}

# Parse existing .env into an associative array (safe-ish: only KEY=VALUE lines)
declare -A ENVV
load_env_file() {
  ENVV=()
  if [[ -f "$ENV_FILE" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      [[ "$line" != *"="* ]] && continue
      local key="${line%%=*}"
      local val="${line#*=}"
      # Trim possible CR
      val="${val%$'\r'}"
      ENVV["$key"]="$val"
    done < "$ENV_FILE"
  fi
}

# Get value from ENVV or default
getv() { local k="$1" d="$2"; echo "${ENVV[$k]:-$d}"; }

write_env_file() {
  mkdir -p "$APP_ROOT"
  load_env_file

  # Defaults (respect existing if present)
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
  COOKIE_SECURE="$(getv COOKIE_SECURE "false")"  # set true when TLS is fronted
  CSRF_SECRET="$(getv CSRF_SECRET "$(rand_hex)")"
  RATE_LIMIT="$(getv RATE_LIMIT "200/hour")"

  NEXT_PUBLIC_APP_NAME="$(getv NEXT_PUBLIC_APP_NAME "TriApp")"
  NEXT_TELEMETRY_DISABLED="$(getv NEXT_TELEMETRY_DISABLED "1")"
  API_INTERNAL_BASE="$(getv API_INTERNAL_BASE "http://backend:5000")"

  # Persist
  cat > "$ENV_FILE" <<EOF
# ====== TriApp environment (.env) ======
# You may edit values here and rerun autoconfig.sh; changes will be applied.
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

write_compose_file() {
  # Use constant volume name 'triapp_db' to avoid surprises across APP_NAME changes
  # Only frontend is bound to host port; backend and db are internal-only.
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
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} -h 127.0.0.1"]
      interval: 10s
      timeout: 5s
      retries: 20
    security_opt:
      - no-new-privileges:true
    cap_drop: ["ALL"]
    read_only: false
    networks:
      - db_net
    expose:
      - "5432"

networks:
  web_net: {}
  app_net:
    internal: true
  db_net:
    internal: true

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
  "scripts": {
    "build": "next build",
    "start": "next start -p 3000",
    "dev": "next dev -p 3000"
  },
  "dependencies": {
    "next": "14.2.5",
    "react": "18.2.0",
    "react-dom": "18.2.0"
  }
}
PKG

  cat > "${APP_ROOT}/frontend/next.config.js" <<'NCFG'
/** @type {import('next').NextConfig} */
const securityHeaders = [
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(), interest-cohort=()' },
  { key: 'Cross-Origin-Opener-Policy', value: 'same-origin' },
  { key: 'Cross-Origin-Resource-Policy', value: 'same-origin' },
  { key: 'Content-Security-Policy', value: "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'; frame-ancestors 'none';" }
];

const nextConfig = {
  async headers() { return [{ source: '/(.*)', headers: securityHeaders }]; },
  async rewrites() {
    return [{ source: '/api/:path*', destination: 'http://backend:5000/api/:path*' }];
  }
};
module.exports = nextConfig;
NCFG

  cat > "${APP_ROOT}/frontend/pages/_app.js" <<'APP'
import React from 'react';
export default function MyApp({ Component, pageProps }) { return <Component {...pageProps} />; }
APP

  cat > "${APP_ROOT}/frontend/pages/healthz.js" <<'HZ'
export default function Health() { return "ok"; }
export async function getServerSideProps(){ return {props:{}} }
HZ

  cat > "${APP_ROOT}/frontend/pages/index.js" <<'INDEX'
import Link from 'next/link';
export default function Home() {
  return (
    <main style={{maxWidth: 720, margin: '40px auto', fontFamily: 'system-ui, sans-serif'}}>
      <h1>{process.env.NEXT_PUBLIC_APP_NAME}</h1>
      <p>A minimal, secure, three-container app: Next.js + Flask + Postgres.</p>
      <ul>
        <li>Frontend (this) on port {process.env.NEXT_PUBLIC_PORT || '12000'}.</li>
        <li>Backend only reachable internally.</li>
        <li>Database isolated from the world.</li>
      </ul>
      <p><Link href="/login">Login / Sign up →</Link></p>
    </main>
  );
}
INDEX

  cat > "${APP_ROOT}/frontend/pages/login.js" <<'LOGIN'
import { useState } from 'react';
import { useRouter } from 'next/router';

export default function Login() {
  const [mode, setMode] = useState('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [otp, setOtp] = useState('');
  const [qr, setQr] = useState(null);
  const [msg, setMsg] = useState('');
  const router = useRouter();

  const submit = async (e) => {
    e.preventDefault(); setMsg('');
    try {
      const url = mode === 'signup' ? '/api/auth/signup' : '/api/auth/login';
      const body = mode === 'signup' ? { email, password } : { email, password, otp };
      const res = await fetch(url, {
        method: 'POST',
        headers: {'Content-Type':'application/json', 'X-CSRF-Token': 'browser'},
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Request failed');
      if (data.qr_png_data_url) setQr(data.qr_png_data_url);
      if (data.ok) {
        await router.push('/dashboard');
      } else if (data.need_otp) {
        setMsg('Enter your 6-digit OTP from authenticator and submit again.');
      } else {
        setMsg('Done.');
      }
    } catch (err) { setMsg(err.message); }
  };

  return (
    <main style={{maxWidth: 420, margin: '40px auto', fontFamily: 'system-ui, sans-serif'}}>
      <h1>{mode === 'signup' ? 'Sign up' : 'Login'}</h1>
      <form onSubmit={submit}>
        <label>Email<br /><input type="email" required value={email} onChange={e=>setEmail(e.target.value)} /></label><br /><br />
        <label>Password<br /><input type="password" required value={password} onChange={e=>setPassword(e.target.value)} /></label><br /><br />
        {mode==='login' && <>
          <label>OTP (if enabled)<br /><input type="text" placeholder="123456" value={otp} onChange={e=>setOtp(e.target.value)} /></label><br /><br />
        </>}
        <button type="submit">{mode==='signup' ? 'Create account' : 'Sign in'}</button>
      </form>
      <p style={{marginTop:12}}><button onClick={()=>setMode(mode==='signup'?'login':'signup')}>Switch to {mode==='signup'?'Login':'Signup'}</button></p>
      {qr && <>
        <h3>Scan in your Authenticator</h3>
        <img alt="TOTP QR" src={qr} style={{maxWidth:'100%'}} />
        <p>After scanning, enter OTP above and click Login.</p>
      </>}
      {msg && <p style={{color:'crimson'}}>{msg}</p>}
    </main>
  );
}
LOGIN

  cat > "${APP_ROOT}/frontend/pages/dashboard.js" <<'DASH'
import Link from 'next/link';

export async function getServerSideProps(context) {
  const res = await fetch('http://backend:5000/api/me', { headers: { cookie: context.req.headers.cookie || '' } });
  if (res.status === 401) return { redirect: { destination: '/login', permanent: false } };
  const me = await res.json();

  const eventsRes = await fetch('http://backend:5000/api/login-events', { headers: { cookie: context.req.headers.cookie || '' } });
  const events = eventsRes.ok ? await eventsRes.json() : [];

  const pgRes = await fetch('http://backend:5000/api/pg-info', { headers: { cookie: context.req.headers.cookie || '' } });
  const pg = pgRes.ok ? await pgRes.json() : {};

  return { props: { me, events, pg } };
}

export default function Dashboard({ me, events, pg }) {
  return (
    <main style={{maxWidth: 900, margin: '40px auto', fontFamily: 'system-ui, sans-serif'}}>
      <h1>Welcome, {me.email}</h1>
      <p><em>Security Center</em>: 2FA: <b>{me.totp_enabled ? 'Enabled' : 'Disabled'}</b> &mdash; Sessions: <b>{me.active_sessions}</b></p>
      <section style={{marginTop: 24}}>
        <h2>Valuable after-login content</h2>
        <ul>
          <li>Live Postgres info: version <b>{pg.version}</b>, current time <b>{pg.now}</b>.</li>
          <li>Your recent login events (IP, time, outcome) below.</li>
          <li>Rotating, HttpOnly session with CSRF protection already in place.</li>
        </ul>
      </section>
      <section style={{marginTop: 24}}>
        <h2>Recent logins</h2>
        <table border="1" cellPadding="6" style={{borderCollapse:'collapse', width:'100%'}}>
          <thead><tr><th>When</th><th>IP</th><th>Success</th></tr></thead>
          <tbody>
          {events.map((e, i) => (<tr key={i}><td>{e.at}</td><td>{e.ip}</td><td>{String(e.ok)}</td></tr>))}
          </tbody>
        </table>
      </section>
      <p style={{marginTop: 24}}><a href="/api/auth/logout">Log out</a> · <Link href="/">Home</Link></p>
    </main>
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
    if not sid: return None
    try:
        signer.loads(sid, max_age=60*60*24*2)
    except BadSignature:
        return None
    with db() as conn, conn.cursor() as cur:
        cur.execute("""SELECT u.id, u.email, u.totp_secret,
                              (SELECT count(*) FROM sessions s2 WHERE s2.user_id = u.id) AS active_sessions
                       FROM users u JOIN sessions s ON s.user_id=u.id WHERE s.sid=%s""", (sid,))
        row = cur.fetchone()
        if not row: return None
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

@app.post("/api/auth/signup")
@limiter.limit("20/hour")
def signup():
    require_csrf()
    j = request.get_json(force=True)
    email = (j.get("email") or "").strip().lower()
    pw = j.get("password") or ""
    if not email or not pw: return jsonify({"error":"email/password required"}), 400
    try:
        pwhash = ph.hash(pw)
        secret = pyotp.random_base32()
        with db() as conn, conn.cursor() as cur:
            cur.execute("INSERT INTO users(email, passhash, totp_secret) VALUES(%s,%s,%s) RETURNING id", (email, pwhash, secret))
            uid = cur.fetchone()["id"]; conn.commit()
        totp = pyotp.TOTP(secret)
        uri = totp.provisioning_uri(name=email, issuer_name="TriApp")
        img = qrcode.make(uri); buf = BytesIO(); img.save(buf, format="PNG")
        qr_b64 = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
        with db() as conn, conn.cursor() as cur:
            cur.execute("INSERT INTO login_events(user_email, ip, ok) VALUES(%s,%s,%s)", (email, get_client_ip(), True)); conn.commit()
        resp = set_session(uid)
        resp.set_data(json.dumps({"ok": True, "qr_png_data_url": qr_b64})); resp.mimetype = "application/json"
        return resp
    except psycopg2.Error:
        return jsonify({"error":"Email already exists?"}), 400

@app.post("/api/auth/login")
@limiter.limit("30/hour")
def login():
    require_csrf()
    j = request.get_json(force=True)
    email = (j.get("email") or "").strip().lower()
    pw = j.get("password") or ""
    otp = (j.get("otp") or "").strip()
    if not email or not pw: return jsonify({"error":"email/password required"}), 400
    with db() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, passhash, totp_secret FROM users WHERE email=%s", (email,))
        u = cur.fetchone()
    if not u: 
        with db() as conn, conn.cursor() as cur:
            cur.execute("INSERT INTO login_events(user_email, ip, ok) VALUES(%s,%s,%s)", (email, get_client_ip(), False)); conn.commit()
        return jsonify({"error":"invalid credentials"}), 401
    try:
        from argon2.exceptions import VerifyMismatchError
        ph.verify(u["passhash"], pw)
    except Exception:
        with db() as conn, conn.cursor() as cur:
            cur.execute("INSERT INTO login_events(user_email, ip, ok) VALUES(%s,%s,%s)", (email, get_client_ip(), False)); conn.commit()
        return jsonify({"error":"invalid credentials"}), 401
    if u["totp_secret"]:
        if not otp: return jsonify({"need_otp": True}), 401
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
    if not u: return jsonify({"error": "unauthorized"}), 401
    return jsonify({"email": u["email"], "totp_enabled": bool(u["totp_secret"]), "active_sessions": int(u["active_sessions"])})

@app.get("/api/login-events")
def login_events():
    u = current_user()
    if not u: return jsonify([]), 401
    with db() as conn, conn.cursor() as cur:
        cur.execute("SELECT to_char(at AT TIME ZONE 'UTC','YYYY-MM-DD HH24:MI:SS') as at, host(ip) as ip, ok FROM login_events WHERE user_email=%s ORDER BY id DESC LIMIT 25", (u["email"],))
        return jsonify(cur.fetchall())

@app.get("/api/pg-info")
def pg_info():
    u = current_user()
    if not u: return jsonify({}), 401
    with db() as conn, conn.cursor() as cur:
        cur.execute("SELECT version(), now()"); r = cur.fetchone()
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

write_watcher() {
  mkdir -p "${APP_ROOT}/scripts" "${APP_ROOT}/systemd"
  cat > "$WATCHER_SCRIPT" <<'WATCH'
#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="/opt/triapp"
cd "$APP_DIR"

# Read APP_NAME from .env (fallback to 'triapp')
APP_NAME="$(grep -E '^APP_NAME=' .env 2>/dev/null | cut -d= -f2- || true)"
APP_NAME="${APP_NAME:-triapp}"

choose_compose() {
  if docker compose version >/dev/null 2>&1; then echo "docker compose"
  elif docker-compose version >/dev/null 2>&1; then echo "docker-compose"
  else echo "docker compose"; fi
}
COMPOSE_BIN="$(choose_compose)"

MAIN_SERVICE="frontend"
IGNORE_AUX_STOP_UNTIL=0
MAIN_RESTART_WINDOW_UNTIL=0

now() { date +%s; }

log(){ printf "[watcher] %s\n" "$*"; }

# Ensure stack is up (no-op if already up)
$COMPOSE_BIN -f "$APP_DIR/docker-compose.yml" up -d >/dev/null 2>&1 || true

# Listen only to our compose project
docker events --format '{{json .}}' \
  --filter type=container \
  --filter "label=com.docker.compose.project=${APP_NAME}" \
  --filter event=stop --filter event=restart --filter event=start \
| while read -r line; do
    status="$(echo "$line" | jq -r '.status // empty')"
    svc="$(echo "$line"   | jq -r '.Actor.Attributes["com.docker.compose.service"] // empty')"
    [[ -z "$svc" || -z "$status" ]] && continue

    tnow="$(now)"

    # If we just restarted aux ourselves, ignore their stop events briefly
    if [[ "$svc" != "$MAIN_SERVICE" && "$status" == "stop" && $tnow -lt $IGNORE_AUX_STOP_UNTIL ]]; then
      log "ignoring stop on $svc (aux restart in progress)"
      continue
    fi

    if [[ "$svc" == "$MAIN_SERVICE" && "$status" == "restart" ]]; then
      MAIN_RESTART_WINDOW_UNTIL=$((tnow + 20))
      log "main restart detected; will restart aux after main starts"
      continue
    fi

    if [[ "$svc" == "$MAIN_SERVICE" && "$status" == "start" && $tnow -lt $MAIN_RESTART_WINDOW_UNTIL ]]; then
      log "main started after restart; restarting backend & db"
      IGNORE_AUX_STOP_UNTIL=$((tnow + 20))
      $COMPOSE_BIN -f "$APP_DIR/docker-compose.yml" restart backend db || true
      MAIN_RESTART_WINDOW_UNTIL=0
      continue
    fi

    if [[ "$status" == "stop" ]]; then
      # Any manual stop of any service stops the entire stack
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

compose_up() {
  ( cd "$APP_ROOT" && $COMPOSE_BIN pull || true )
  ( cd "$APP_ROOT" && $COMPOSE_BIN up -d --build )
}

compose_stop() {
  if [[ -f "$COMPOSE_FILE" ]]; then
    ( cd "$APP_ROOT" && $COMPOSE_BIN stop || true )
  else
    warn "No compose file found at $COMPOSE_FILE; nothing to stop."
  fi
}

compose_destroy() {
  systemctl disable --now triapp-watcher.service >/dev/null 2>&1 || true
  rm -f "$WATCHER_UNIT"; systemctl daemon-reload || true

  if [[ -f "$COMPOSE_FILE" ]]; then
    ( cd "$APP_ROOT" && $COMPOSE_BIN down -v --remove-orphans || true )
  fi

  # Remove named volume explicitly (idempotent)
  docker volume rm -f triapp_db >/dev/null 2>&1 || true

  rm -rf "$APP_ROOT"
  log "Destroyed all services, data, and watcher."
}

menu() {
  echo
  echo "==== autoconfig.sh ===="
  echo "1) Create / Update & Run"
  echo "2) Stop containers"
  echo "3) Destroy EVERYTHING (containers, networks, volume, watcher)"
  echo "q) Quit"
  echo -n "Choose: "
}

main_up() {
  ensure_prereqs
  mkdir -p "$APP_ROOT"
  write_env_file
  write_compose_file
  write_frontend
  write_backend
  write_db_seed
  compose_up
  write_watcher

  # Output access info
  local port; port="$(grep -E '^FRONTEND_PORT=' "$ENV_FILE" | cut -d= -f2-)"
  local ip; ip="$(curl -fsS ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo '<YOUR_VM_IP>')"
  echo
  echo "==============================================="
  echo " Deployed. Frontend: http://${ip}:${port}"
  echo " Compose project: $(grep -E '^APP_NAME=' "$ENV_FILE" | cut -d= -f2-)"
  echo " App dir: ${APP_ROOT}"
  echo " Rerun autoconfig.sh anytime to apply changes."
  echo "==============================================="
}

main_stop()   { ensure_prereqs; compose_stop; }
main_destroy(){ ensure_prereqs; compose_destroy; }

# ---------------- Entry ----------------
require_root
ensure_prereqs   # So we can use $COMPOSE_BIN in all branches

action="${1:-}"
case "$action" in
  up|create|update|run) main_up ;;
  stop) main_stop ;;
  destroy|down|reset) main_destroy ;;
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
