#!/usr/bin/env bash
# autoinstall.sh — Install k3s + Argo CD and expose Argo CD on external port 13243 (GCE Ubuntu)
# Idempotent, debug-friendly, minimal assumptions about the host.
set -Eeuo pipefail

# ===== Config =====
: "${DEBUG:=1}"                 # 1=verbose bash xtrace, 0=quiet
: "${ARGOCD_NS:=argocd}"
: "${EXPOSE_PORT:=13243}"       # external port on VM
: "${ARGOCD_MANIFEST_URL:=https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"
: "${TIMEOUT:=600}"             # seconds to wait for components
: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
export KUBECONFIG

[[ "${DEBUG}" == "1" ]] && set -x

# ===== Helpers =====
log()  { printf "\n[%s] %s\n" "$(date +'%F %T')" "$*" >&2; }
die()  { printf "\n[ERROR] %s\n" "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

SUDO="" ; [[ $EUID -ne 0 ]] && SUDO="sudo"

trap 'rc=$?; [[ $rc -ne 0 ]] && echo "[FATAL] Script failed (exit $rc)." >&2' EXIT

# Return first non-empty value
first_nonempty() { for v in "$@"; do [[ -n "${v:-}" ]] && { echo "$v"; return 0; }; done; }

# ===== System prep =====
log "Updating apt and installing prerequisites..."
$SUDO apt-get update -y
$SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  ca-certificates curl jq apt-transport-https gnupg lsb-release

need curl
need jq

# ===== k3s install (idempotent) =====
if ! command -v k3s >/dev/null 2>&1; then
  log "Installing k3s (lightweight Kubernetes)..."
  # k3s bundles containerd, flannel CNI, Traefik (80/443), and ServiceLB (Klipper LB).
  curl -sfL https://get.k3s.io | $SUDO sh -s - --write-kubeconfig-mode 0644
else
  log "k3s already installed. Ensuring service is running..."
  $SUDO systemctl enable --now k3s
fi

# ensure kubectl available (k3s installs a kubectl symlink)
if ! command -v kubectl >/dev/null 2>&1; then
  log "Ensuring kubectl symlink present..."
  $SUDO ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl || true
fi
need kubectl

# allow current user to read kubeconfig
$SUDO chmod 0644 "$KUBECONFIG" || true

log "Waiting for k3s node to be Ready..."
kubectl wait --for=condition=Ready node --all --timeout="${TIMEOUT}s" || \
  die "k3s node did not become Ready in ${TIMEOUT}s"

# ===== Argo CD install (idempotent) =====
log "Creating namespace '${ARGOCD_NS}' (idempotent)..."
kubectl create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl apply -f -

log "Applying Argo CD install manifest..."
kubectl apply -n "${ARGOCD_NS}" -f "${ARGOCD_MANIFEST_URL}"

log "Waiting for Argo CD server Deployment to be Available..."
kubectl -n "${ARGOCD_NS}" rollout status deploy/argocd-server --timeout="${TIMEOUT}s"

# ===== Expose Argo CD on EXPOSE_PORT via k3s ServiceLB (hostPort) =====
# We replace the Service ports to avoid conflicts with Traefik's 80/443.
log "Patching 'argocd-server' Service to type=LoadBalancer on port ${EXPOSE_PORT}..."
if kubectl -n "${ARGOCD_NS}" get svc argocd-server >/dev/null 2>&1; then
  current_ports="$(kubectl -n "${ARGOCD_NS}" get svc argocd-server -o jsonpath='{.spec.ports[*].port}' || true)"
  svc_type="$(kubectl -n "${ARGOCD_NS}" get svc argocd-server -o jsonpath='{.spec.type}' || true)"
  need_patch="no"
  [[ "${svc_type}" != "LoadBalancer" ]] && need_patch="yes"
  grep -q -w "${EXPOSE_PORT}" <<<"${current_ports:-}" || need_patch="yes"

  if [[ "${need_patch}" == "yes" ]]; then
    # JSONPatch fully replaces the ports list with a single port to avoid 80/443 conflicts.
    patch_json=$(jq -n --argjson port "${EXPOSE_PORT}" '[{"op":"replace","path":"/spec/type","value":"LoadBalancer"}, {"op":"replace","path":"/spec/ports","value":[{"name":"https-'"${EXPOSE_PORT}"'","protocol":"TCP","port":'"${EXPOSE_PORT}"',"targetPort":8080}]}]')
    kubectl -n "${ARGOCD_NS}" patch svc argocd-server --type=json -p "${patch_json}"
  else
    log "Service already exposed as LoadBalancer on port ${EXPOSE_PORT}."
  fi
else
  die "Service argocd-server not found; install may have failed."
fi

# Wait until ServiceLB assigns an ingress IP (k3s will use node external IP)
log "Waiting for LoadBalancer ingress IP on argocd-server Service..."
SECS=0
ARGOCD_IP=""
while [[ $SECS -lt $TIMEOUT ]]; do
  ARGOCD_IP="$(kubectl -n "${ARGOCD_NS}" get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || true)"
  [[ -n "${ARGOCD_IP}" ]] && break
  sleep 3; SECS=$((SECS+3))
done
[[ -z "${ARGOCD_IP}" ]] && log "No LB IP reported yet; will fall back to VM external IP."

# ===== Open instance firewall if UFW is active (GCE VPC firewall must also allow this port) =====
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  log "UFW is active — allowing tcp/${EXPOSE_PORT}..."
  $SUDO ufw allow "${EXPOSE_PORT}/tcp" || true
else
  log "UFW inactive or not installed — skipping UFW changes (GCE VPC firewall controls external access)."
fi

# ===== Discover external IPs =====
log "Discovering GCE external IP..."
GCE_IP="$(curl -sfH 'Metadata-Flavor: Google' \
  'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip' || true)"
EXTERNAL_IP="$(first_nonempty "${ARGOCD_IP}" "${GCE_IP}")"

# ===== Fetch initial admin password (if still present) =====
# Official default admin user is 'admin'; initial password stored in argocd-initial-admin-secret.
INIT_PASS=""
if kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret >/dev/null 2>&1; then
  INIT_PASS="$(kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d || true)"
fi

# ===== Output =====
echo ""
echo "====================== SUCCESS ======================"
echo "Argo CD is installed and exposed on: https://${EXTERNAL_IP:-<external-ip>}:${EXPOSE_PORT}"
echo ""
echo "If you point DNS A record 'argocd.dmj.one' -> ${GCE_IP:-<external-ip>}, you'll reach:"
echo "  https://argocd.dmj.one:${EXPOSE_PORT}"
echo ""
echo "Login:"
echo "  Username: admin"
if [[ -n "${INIT_PASS}" ]]; then
  echo "  Password: ${INIT_PASS}"
else
  echo "  Password: <not retrieved>"
  echo "    (The 'argocd-initial-admin-secret' may have been deleted or rotated.)"
  echo "    To fetch later: kubectl -n ${ARGOCD_NS} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
fi
echo ""
echo "kubectl context:"
echo "  KUBECONFIG=${KUBECONFIG}"
echo ""
echo "Notes:"
echo "  • Ensure your GCE VPC firewall allows ingress tcp/${EXPOSE_PORT} to this VM."
echo "  • TLS is Argo CD's default (self-signed). Browser will warn unless you add a valid cert."
echo "====================================================="
