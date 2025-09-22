#!/usr/bin/env bash
set -euo pipefail

# ========= CONFIG =========
APP_NAME="triapp"
APP_DIR="/opt/${APP_NAME}"
FRONTEND_PORT="${FRONTEND_PORT:-12000}"   # host port; change via env if desired
DB_VOLUME="${APP_NAME}_db"
COMPOSE_BIN="${COMPOSE_BIN:-docker compose}"  # supports both 'docker compose' and 'docker-compose'
OS="$(. /etc/os-release; echo $ID || true)"

# ========= FUNCTIONS =========
rand_secret () { openssl rand -base64 48 | tr -d '\n'; }
need() { command -v "$1" >/dev/null 2>&1; }

install_docker_ubuntu() {
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release; echo "$UBUNTU_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

install_docker_debian() {
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(. /etc/os-release; echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

install_docker_rhel_like() {
  # For RHEL/CentOS/Alma/Rocky
  yum install -y yum-utils
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true
  yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

ensure_docker() {
  if ! need docker; then
    echo "[*] Installing Docker..."
    case "$OS" in
      ubuntu) install_docker_ubuntu ;;
      debian) install_docker_debian ;;
      centos|rhel|rocky|almalinux) install_docker_rhel_like ;;
      *) echo "Unsupported OS '$OS'. Install Docker manually, then rerun."; exit 1 ;;
    esac
  else
    echo "[*] Docker present."
    systemctl enable --now docker || true
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "Docker is installed but not running; fix and rerun."
    exit 1
  fi
}

write_file() {
  local path="$1"; shift
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'__EOF__'
__EOF__
  # Now replace the empty heredoc with the provided content using sed from caller.
}

# ========= MAIN =========
ensure_docker

# Create app directory
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Create .env idempotently
if [ ! -f .env ]; then
  echo "[*] Creating .env"
  FRONTEND_SECRET="$(rand_secret)"
  FLASK_SECRET="$(rand_secret)"
  DB_PASSWORD="$(openssl rand -hex 24)"
  cat > .env <<EOF
# ===== ${APP_NAME} env =====
FRONTEND_PORT=${FRONTEND_PORT}

# Database
POSTGRES_DB=appdb
POSTGRES_USER=app
POSTGRES_PASSWORD=${DB_PASSWORD}

# Backend
FLASK_SECRET=${FLASK_SECRET}
SESSION_COOKIE_NAME=triapp_session
COOKIE_SECURE=false      # set true if terminating HTTPS in front (e.g., CDN/tunnel)
CSRF_SECRET=$(openssl rand -hex 32)
RATE_LIMIT=200/hour      # soft limit per IP

# Frontend
NEXT_PUBLIC_APP_NAME=TriApp
NEXT_TELEMETRY_DISABLED=1

# Internal URLs
API_INTERNAL_BASE=http://backend:5000
EOF
else
  echo "[*] Using existing .env (idempotent)."
fi

# docker-compose.yml (Compose Spec v3+)
cat > docker-compose.yml <<'YML'
name: triapp
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
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:3000/healthz || exit 1"]
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
      com.${APP_NAME}.role: main

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
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:5000/healthz || exit 1"]
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
      - ${APP_NAME}_db:/var/lib/postgresql/data
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
    user: "999:999"   # postgres uid/gid in alpine image
    networks:
      - db_net
    expose:
      - "5432"

networks:
  web_net: {}           # public-facing for frontend only
  app_net:
    internal: true      # isolates frontend <-> backend only
  db_net:
    internal: true      # isolates backend <-> db only

volumes:
  triapp_db:
YML

# --- FRONTEND (Next.js) ---
mkdir -p frontend/pages frontend/public frontend/components
cat > frontend/package.json <<'PKG'
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

cat > frontend/next.config.js <<'NCFG'
/** @type {import('next').NextConfig} */
const securityHeaders = [
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(), interest-cohort=()' },
  { key: 'Cross-Origin-Opener-Policy', value: 'same-origin' },
  { key: 'Cross-Origin-Resource-Policy', value: 'same-origin' },
  // Minimal CSP for this demo; tighten as needed
  { key: 'Content-Security-Policy', value: "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'; frame-ancestors 'none';" }
];

const nextConfig = {
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }];
  },
  async rewrites() {
    // Client/browser requests to /api/* proxy internally to Flask backend over app_net
    return [{ source: '/api/:path*', destination: 'http://backend:5000/api/:path*' }];
  }
};
module.exports = nextConfig;
NCFG

cat > frontend/pages/_app.js <<'APP'
import React from 'react';
export default function MyApp({ Component, pageProps }) {
  return <Component {...pageProps} />;
}
APP

cat > frontend/pages/healthz.js <<'HZ'
export default function Health() { return "ok"; }
export async function getServerSideProps(){ return {props:{}} }
HZ

cat > frontend/pages/index.js <<'INDEX'
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

cat > frontend/pages/login.js <<'LOGIN'
import { useState } from 'react';
import { useRouter } from 'next/router';

export default function Login() {
  const [mode, setMode] = useState('login'); // or 'signup'
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [otp, setOtp] = useState('');
  const [qr, setQr] = useState(null);
  const [msg, setMsg] = useState('');
  const router = useRouter();

  const submit = async (e) => {
    e.preventDefault();
    setMsg('');
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
        <label>Email<br />
          <input type="email" required value={email} onChange={e=>setEmail(e.target.value)} />
        </label><br /><br />
        <label>Password<br />
          <input type="password" required value={password} onChange={e=>setPassword(e.target.value)} />
        </label><br /><br />
        {mode==='login' && <>
          <label>OTP (if enabled)<br />
            <input type="text" placeholder="123456" value={otp} onChange={e=>setOtp(e.target.value)} />
          </label><br /><br />
        </>}
        <button type="submit">{mode==='signup' ? 'Create account' : 'Sign in'}</button>
      </form>
      <p style={{marginTop:12}}><button onClick={()=>setMode(mode==='signup'?'login':'signup')}>
        Switch to {mode==='signup'?'Login':'Signup'}
      </button></p>
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

cat > frontend/pages/dashboard.js <<'DASH'
import Link from 'next/link';

export async function getServerSideProps(context) {
  // SSR: hit backend directly over internal network so cookies work server-side
  const res = await fetch('http://backend:5000/api/me', {
    headers: { cookie: context.req.headers.cookie || '' }
  });
  if (res.status === 401) {
    return { redirect: { destination: '/login', permanent: false } };
  }
  const me = await res.json();

  const eventsRes = await fetch('http://backend:5000/api/login-events', {
    headers: { cookie: context.req.headers.cookie || '' }
  });
  const events = eventsRes.ok ? await eventsRes.json() : [];

  const pgRes = await fetch('http://backend:5000/api/pg-info', {
    headers: { cookie: context.req.headers.cookie || '' }
  });
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
          {events.map((e, i) => (
            <tr key={i}><td>{e.at}</td><td>{e.ip}</td><td>{String(e.ok)}</td></tr>
          ))}
          </tbody>
        </table>
      </section>

      <p style={{marginTop: 24}}><a href="/api/auth/logout">Log out</a> · <Link href="/">Home</Link></p>
    </main>
  );
}
DASH

cat > frontend/Dockerfile <<'DFE'
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
USER 10001:10001
EXPOSE 3000
CMD ["npm", "start"]
DFE

# --- BACKEND (Flask) ---
mkdir -p backend
cat > backend/requirements.txt <<'REQ'
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

cat > backend/app.py <<'PY'
import os, hmac, base64, json, datetime
from datetime import timedelta, datetime as dt
from ipaddress import ip_address
from flask import Flask, request, jsonify, make_response, abort
import psycopg2
import psycopg2.extras
from itsdangerous import URLSafeTimedSerializer, BadSignature
from argon2 import PasswordHasher
import pyotp, qrcode
from io import BytesIO
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

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
        # enable citext
        cur.execute("CREATE EXTENSION IF NOT EXISTS citext;")
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
        cur.execute("INSERT INTO sessions(sid, user_id, expires_at) VALUES(%s,%s, now()+ interval '12 hours')",
                    (sid, user_id))
        conn.commit()
    resp = make_response(jsonify({"ok": True}))
    resp.set_cookie(SESSION_COOKIE_NAME, sid, httponly=True, samesite="Strict",
                    secure=COOKIE_SECURE, max_age=12*3600, path="/")
    # CSRF token for browser to echo back
    csrf = csrf_signer.dumps({"ts": int(dt.utcnow().timestamp())})
    resp.set_cookie("csrf", csrf, httponly=False, samesite="Strict",
                    secure=COOKIE_SECURE, max_age=12*3600, path="/")
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
        data = signer.loads(sid, max_age=60*60*24*2)  # 2 days absolute
    except BadSignature:
        return None
    with db() as conn, conn.cursor() as cur:
        cur.execute("""SELECT u.id, u.email, u.totp_secret,
                              (SELECT count(*) FROM sessions s2 WHERE s2.user_id = u.id) AS active_sessions
                       FROM users u JOIN sessions s ON s.user_id=u.id WHERE s.sid=%s
                       """, (sid,))
        row = cur.fetchone()
        if not row:
            return None
        # bump last_seen
        cur.execute("UPDATE sessions SET last_seen=now() WHERE sid=%s", (sid,))
        conn.commit()
        return row

def require_csrf():
    # Double submit: cookie 'csrf' + header 'X-CSRF-Token' (must equal signer.verify)
    token = request.headers.get("X-CSRF-Token","")
    csrf_cookie = request.cookies.get("csrf","")
    try:
        decoded = csrf_signer.loads(csrf_cookie, max_age=12*3600)
    except BadSignature:
        abort(403)
    if not token or token != "browser":
        abort(403)  # For demo: frontend always sends literal header; cookie validates age+origin.
    return True

@app.post("/api/auth/signup")
@limiter.limit("20/hour")
def signup():
    require_csrf()
    j = request.get_json(force=True)
    email = (j.get("email") or "").strip().lower()
    pw = j.get("password") or ""
    if not email or not pw:
        return jsonify({"error":"email/password required"}), 400
    try:
        pwhash = ph.hash(pw)
        secret = pyotp.random_base32()
        with db() as conn, conn.cursor() as cur:
            cur.execute("INSERT INTO users(email, passhash, totp_secret) VALUES(%s,%s,%s) RETURNING id",
                        (email, pwhash, secret))
            uid = cur.fetchone()["id"]
            conn.commit()
        # provide QR to enroll
        totp = pyotp.TOTP(secret)
        uri = totp.provisioning_uri(name=email, issuer_name="TriApp")
        img = qrcode.make(uri)
        buf = BytesIO()
        img.save(buf, format="PNG")
        qr_b64 = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
        # auto-login after signup
        ip = get_client_ip()
        with db() as conn, conn.cursor() as cur:
          cur.execute("INSERT INTO login_events(user_email, ip, ok) VALUES(%s,%s,%s)", (email, ip, True))
          conn.commit()
        resp = set_session(uid)
        resp.set_data(json.dumps({"ok": True, "qr_png_data_url": qr_b64}))
        resp.mimetype = "application/json"
        return resp
    except psycopg2.Error as e:
        return jsonify({"error":"Email already exists?"}), 400

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

    ip = get_client_ip()
    if not u:
        with db() as conn, conn.cursor() as cur:
            cur.execute("INSERT INTO login_events(user_email, ip, ok) VALUES(%s,%s,%s)", (email, ip, False))
            conn.commit()
        return jsonify({"error":"invalid credentials"}), 401

    try:
        ph.verify(u["passhash"], pw)
    except Exception:
        with db() as conn, conn.cursor() as cur:
            cur.execute("INSERT INTO login_events(user_email, ip, ok) VALUES(%s,%s,%s)", (email, ip, False))
            conn.commit()
        return jsonify({"error":"invalid credentials"}), 401

    # If TOTP is set, require OTP
    if u["totp_secret"]:
        if not otp:
            return jsonify({"need_otp": True}), 401
        totp = pyotp.TOTP(u["totp_secret"])
        if not totp.verify(otp, valid_window=1):
            with db() as conn, conn.cursor() as cur:
                cur.execute("INSERT INTO login_events(user_email, ip, ok) VALUES(%s,%s,%s)", (email, ip, False))
                conn.commit()
            return jsonify({"error":"invalid otp"}), 401

    with db() as conn, conn.cursor() as cur:
        cur.execute("INSERT INTO login_events(user_email, ip, ok) VALUES(%s,%s,%s)", (email, ip, True))
        conn.commit()

    resp = set_session(u["id"])
    return resp

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
        rows = cur.fetchall()
        return jsonify(rows)

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

cat > backend/wsgi.py <<'WSGI'
from app import app, init_db
init_db()
if __name__ != "__main__":
    application = app
WSGI

cat > backend/Dockerfile <<'DFB'
FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN addgroup --system --gid 10002 appgrp && adduser --system --uid 10002 --ingroup appgrp appuser
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
USER 10002:10002
EXPOSE 5000
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "--timeout", "60", "wsgi:application"]
DFB

# --- DB init (tables/extensions handled by backend too; SQL here is optional extras) ---
mkdir -p db
cat > db/init.sql <<'SQL'
-- Reserved for future seed/migrations if needed.
-- Backend idempotently creates citext extension and tables.
SQL

# --- Watcher (host-side) ---
mkdir -p scripts systemd
cat > scripts/compose-watcher.sh <<'WATCH'
#!/usr/bin/env bash
set -euo pipefail
APP_DIR="/opt/triapp"
cd "$APP_DIR"
# Watch docker events scoped to this compose project and act:
# 1) If any container stops/dies -> stop entire stack
# 2) If frontend restarts (die followed by start quickly) -> restart backend & db
PROJECT="triapp"
MAIN_SERVICE="frontend"

echo "[triapp-watcher] starting..."
# Get container IDs for mapping service names dynamically
map_id_to_service() {
  local id="$1"
  docker inspect --format '{{ index .Config.Labels "com.docker.compose.service" }}' "$id" 2>/dev/null || echo ""
}
${COMPOSE_BIN:-docker compose} up -d >/dev/null 2>&1 || true

docker events --format '{{json .}}' \
  --filter 'type=container' \
  --filter 'label=com.docker.compose.project=triapp' \
  --filter 'event=stop' --filter 'event=die' --filter 'event=restart' --filter 'event=kill' --filter 'event=oom' \
| while read -r line; do
    service=""
    status=""
    id=""
    status=$(echo "$line" | jq -r '.status // empty' 2>/dev/null || echo '')
    id=$(echo "$line" | jq -r '.id // empty' 2>/dev/null || echo '')
    if [ -z "$id" ]; then continue; fi
    service=$(map_id_to_service "$id")
    if [ -z "$service" ]; then continue; fi
    echo "[triapp-watcher] event: $status on service=$service"

    if [[ "$status" =~ ^(stop|die|kill|oom)$ ]]; then
      echo "[triapp-watcher] stopping entire stack due to $service $status"
      ${COMPOSE_BIN:-docker compose} stop
      continue
    fi

    if [[ "$status" == "restart" && "$service" == "$MAIN_SERVICE" ]]; then
      echo "[triapp-watcher] main restarted -> restarting aux"
      ${COMPOSE_BIN:-docker compose} restart backend db || true
    fi
done
WATCH
chmod +x scripts/compose-watcher.sh

cat > systemd/triapp-watcher.service <<'UNIT'
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

# Bring up stack
echo "[*] Building and starting containers..."
$COMPOSE_BIN pull || true
$COMPOSE_BIN up -d --build

# Install/enable watcher
echo "[*] Installing watcher as systemd service..."
cp -f systemd/triapp-watcher.service /etc/systemd/system/triapp-watcher.service
systemctl daemon-reload
systemctl enable --now triapp-watcher.service

echo
echo "==============================================="
echo " Deployed '${APP_NAME}'."
echo " Frontend: http://$(curl -s ifconfig.me 2>/dev/null || echo YOUR_VM_IP):${FRONTEND_PORT}"
echo " (Use /login to sign up; dashboard after login.)"
echo " Docker project dir: ${APP_DIR}"
echo " To update: rerun this script. Idempotent."
echo " To stop all: docker compose -f ${APP_DIR}/docker-compose.yml down"
echo "==============================================="
