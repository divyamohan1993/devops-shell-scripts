# Docker: Daily Commands Cookbook

> A pragmatic, copy‑paste friendly guide to the Docker CLI used in real projects.
> Start at the top and work down; each section builds the next.
> Works on Linux/macOS (Bash/Zsh) and Windows (PowerShell notes where relevant).

**Citations**: Key references are linked at the end of major sections so you can verify details against the official docs.

---

## 0) Verify install & get oriented

**Check your install, version, and environment.**

```bash
docker --version
docker info
```

**Get help for any command (and available subcommands).**

```bash
docker --help
docker <command> --help
```

**Show CLI object formatting tricks (Go templates).**

```bash
docker ps --format '{{.ID}}  {{.Image}}  {{.Names}}'
docker inspect -f '{{json .Config.Env}}' <container_or_image>
```

*Refs: Docker CLI index & formatting guide.* ([Docker Documentation][1])

---

## 1) Hello, containers (first 5 minutes)

**Pull a small image and run a one-off command.**

```bash
docker pull alpine:3
docker run --rm alpine:3 echo "hello from container"
```

**Run an interactive shell (throwaway).**

```bash
docker run --rm -it alpine:3 sh
```

**List running containers / all containers.**

```bash
docker ps
docker ps -a
```

**List images; remove dangling/unused ones.**

```bash
docker images
docker image prune -f          # dangling layers only
docker image prune -a -f       # unused images too (careful)
```

*Refs: CLI basics.* ([Docker Documentation][1])

---

## 2) Lifecycle: start, stop, inspect, logs, exec

**Run a named container in detached mode, port mapped.**

```bash
docker run -d --name web -p 8080:80 nginx:latest
```

**Inspect details (env, mounts, health, ports).**

```bash
docker inspect web | jq .
docker inspect -f '{{.State.Health.Status}}' web
```

**Attach or exec a shell into a running container.**

```bash
docker exec -it web sh      # or bash if present
```

**View and follow logs (with timestamps & tail).**

```bash
docker logs -f --tail=100 web
```

**Stop / start / restart / remove (container).**

```bash
docker stop web
docker start web
docker restart web
docker rm web               # remove (stopped) container
```

*Refs: CLI reference for container/list/logs/inspect.* ([Docker Documentation][2])

---

## 3) Files: copy in/out, diff, commit (rare)

**Copy files between host and container.**

```bash
docker cp ./local.conf web:/etc/nginx/conf.d/default.conf
docker cp web:/usr/share/nginx/html ./site-backup
```

**Show what changed in the container filesystem.**

```bash
docker diff web
```

**(Rare) Commit container changes to a new image.**

```bash
docker commit web myorg/nginx-tuned:dev
```

*Refs: CLI index.* ([Docker Documentation][1])

---

## 4) Networking: ports, DNS, custom networks

**Publish container ports to host.**

```bash
docker run -d --name api -p 9000:9000 myorg/api:latest
```

**Create an app network; connect multiple services.**

```bash
docker network create appnet
docker run -d --name db --network appnet -e POSTGRES_PASSWORD=pass postgres:16
docker run -d --name app --network appnet -p 3000:3000 myorg/app:latest
```

**Inspect and manage networks.**

```bash
docker network ls
docker network inspect appnet
docker network connect appnet web
docker network disconnect appnet web
```

**DNS, extra hosts, static IP (advanced).**

```bash
docker run -d --name svc \
  --add-host "redis.local:10.10.0.10" \
  --dns 1.1.1.1 --dns-search corp.local \
  --network appnet \
  nginx:latest
```

*Refs: run/ports & networks.* ([Docker Documentation][1])

---

## 5) Persistent data: volumes & bind mounts

**Create/list/inspect/remove volumes.**

```bash
docker volume create appdata
docker volume ls
docker volume inspect appdata
docker volume rm appdata
```

**Mount a named volume (preferred for prod).**

```bash
docker run -d --name pg -v appdata:/var/lib/postgresql/data postgres:16
```

**Bind mount local files (great for dev).**

```bash
docker run -d --name web -p 8080:80 \
  -v "$(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:latest
```

*Refs: volumes & run.* ([Docker Documentation][1])

---

## 6) Observability & troubleshooting

**Top-like runtime metrics & system df.**

```bash
docker stats                 # live CPU/mem/net
docker system df             # space by images/containers/volumes
```

**Daemon & container events.**

```bash
docker events                # stream of Docker events
```

**Format & filter outputs (script-friendly).**

```bash
docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}'
```

*Refs: stats & formatting docs.* ([Docker Documentation][3])

---

## 7) Resource limits & restart policy (prod hygiene)

**Limit memory/CPU; auto-restart on failure.**

```bash
docker run -d --name worker \
  --memory=512m --cpus=1.0 --pids-limit=200 \
  --restart=on-failure:3 \
  myorg/worker:stable
```

**Update limits on a running container.**

```bash
docker update --cpus=2 --memory=1g worker
```

*Refs: run/update.* ([Docker Documentation][1])

---

## 8) Security hardening (quick wins)

**Run as non-root user; read‑only filesystem; drop caps.**

```bash
docker run -d --name api \
  --user 10001:10001 \
  --read-only \
  --cap-drop=ALL --cap-add=NET_BIND_SERVICE \
  --security-opt no-new-privileges \
  myorg/api:latest
```

*Refs: run security opts & caps.* ([Docker Documentation][1])

---

## 9) Building images (the modern way)

**Initialize Docker assets for a project (guided).**

```bash
cd /path/to/project
docker init
```

*Creates `Dockerfile`, `compose.yaml`, `.dockerignore` with sensible defaults.* ([Docker Documentation][4])

**Build & tag; show build context & history.**

```bash
docker build -t myorg/web:dev .
docker history myorg/web:dev
```

**Multi-stage example (smaller images).**

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.22 AS build
WORKDIR /src
COPY . .
RUN go build -o app ./cmd/app

FROM gcr.io/distroless/base-debian12
COPY --from=build /src/app /app
USER 10001:10001
ENTRYPOINT ["/app"]
```

*Refs: Dockerfile reference.* ([Docker Documentation][5])

---

## 10) BuildKit & secrets, caches, provenance, SBOM

**BuildKit is the default modern builder; keep it on.** ([Docker Documentation][6])

**Use secrets without baking them into layers.**

```bash
# Pass secret at build time
docker build --secret id=npm,src=$HOME/.npmrc -t myorg/app:dev .

# Consume in Dockerfile (BuildKit mount)
# syntax=docker/dockerfile:1
RUN --mount=type=secret,id=npm npm install --quiet
```

*Refs: Build secrets.* ([Docker Documentation][7])

**Speed builds with cache mounts.**

```dockerfile
# syntax=docker/dockerfile:1
RUN --mount=type=cache,target=/root/.cache/go-build go build ./...
```

**Emit supply-chain attestations (provenance & SBOM).**

```bash
docker buildx build -t myorg/app:1.0 \
  --provenance=true --sbom=true --push .
```

*Refs: SBOM attestations & Scout SBOM.* ([Docker Documentation][8])

---

## 11) Buildx: multi‑arch, remote builders, prune

**Create & use a persistent builder (local or remote).**

```bash
docker buildx create --name xbuilder --use
docker buildx ls
```

**Build multi-platform images (push to registry).**

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myorg/app:1.0 --push .
```

**See and prune build caches (disk hygiene).**

```bash
docker buildx du
docker buildx prune -f --verbose
docker builder prune -f --keep-storage=10GB      # classic builder cache
```

*Refs: buildx create/build/du/prune & builder prune.* ([Docker Documentation][9])

---

## 12) Registries & auth (Docker Hub + clouds)

**Log in securely (avoid inline passwords).**

```bash
echo "$DOCKERHUB_PAT" | docker login --username "$DOCKERHUB_USER" --password-stdin
```

*Ref: `docker login` & credential stores.* ([Docker Documentation][10])

**Amazon ECR (private).**

```bash
aws ecr get-login-password \
| docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.<region>.amazonaws.com
```

*Ref: ECR auth.* ([AWS Documentation][11])

**Google Artifact/Container Registry.**

```bash
gcloud auth configure-docker
# then tag and push gcr.io/$PROJECT/myimg:tag or us-docker.pkg.dev/$PROJECT/$REPO/myimg:tag
```

*Ref: gcloud docker auth.* ([Google Cloud][12])

**Azure Container Registry (ACR).**

```bash
az acr login -n <registry_name>
# Or with token:
echo "$TOKEN_PWD" | docker login --username "$TOKEN_NAME" --password-stdin <registry>.azurecr.io
```

*Refs: ACR CLI & token login.* ([Microsoft Learn][13])

**Run a local private registry (for CI cache/mirror).**

```bash
docker run -d -p 5000:5000 --restart always --name registry registry:3
docker tag alpine:3 localhost:5000/alpine:3
docker push localhost:5000/alpine:3
```

*Ref: Official `registry` image quickstart.* ([Docker Hub][14])

---

## 13) Docker Compose v2 (multi‑service dev & ops)

> Compose v2 lives under `docker compose …` (not `docker-compose`). Use it for local multi-service workflows and repeatable dev/prod configs.

**Boot a stack; rebuild on changes; detach.**

```bash
docker compose up                 # foreground, great for dev
docker compose up --build -d      # rebuild & run in background
```

**Common dev flows: logs, ps, exec, run one-offs.**

```bash
docker compose ps
docker compose logs -f --tail=200
docker compose exec web sh
docker compose run --rm web npm test
```

**Scale services (simple horizontal scale).**

```bash
docker compose up -d --scale web=3
```

**Stop/clean.**

```bash
docker compose stop
docker compose down -v   # remove volumes too (danger: data loss)
```

**Profiles & watch (conditional services, live dev).**

```bash
docker compose --profile debug up      # enable a profile
docker compose watch                   # rebuild/restart on file change
```

**Lint/preview Compose file the CLI will run.**

```bash
docker compose config
```

*Refs: Compose CLI, profiles, scale, watch, file reference.* ([Docker Documentation][15])

---

## 14) Contexts & remote Docker hosts (SSH/TLS)

**Create a context to target a remote host over SSH and switch to it.**

```bash
docker context create my-remote --docker "host=ssh://user@host"
docker context use my-remote
docker ps
```

**List/inspect/export contexts; quick one-off targeting.**

```bash
docker context ls
docker context inspect my-remote
DOCKER_CONTEXT=my-remote docker images
docker context export my-remote > my-remote.dockercontext
```

*Refs: Contexts & examples.* ([Docker Documentation][16])

---

## 15) Swarm mode (built‑in orchestrator, still useful)

> While Kubernetes dominates, Swarm remains a lightweight option and Swarm stacks are used in many shops.

**Initialize a swarm & get join tokens.**

```bash
docker swarm init --advertise-addr <MANAGER-IP>
docker swarm join-token manager
docker swarm join-token worker
```

**Create services; list/scale/update/rollback.**

```bash
docker service create --name web -p 80:80 nginx:latest
docker service ls
docker service scale web=5
docker service update --image nginx:1.27-alpine web
docker service rollback web
```

**Deploy a stack from a Compose v3 file.**

```bash
docker stack deploy -c stack.yaml mystack
docker stack services mystack
docker stack ps mystack
docker stack rm mystack
```

> Note: `docker stack deploy` expects the legacy **Compose v3** format (not the latest spec). Keep a separate `stack.yaml` for Swarm. ([Docker Documentation][17])

*Refs: swarm init/service/stack commands.* ([Docker Documentation][18])

---

## 16) Logs & logging drivers (prod tuning)

**Use the json‑file driver with rotation (default on Linux).**

```bash
docker run -d --log-driver json-file \
  --log-opt max-size=10m --log-opt max-file=3 \
  myorg/api:stable
```

**Switch drivers per container (e.g., syslog/none).**

```bash
docker run -d --log-driver syslog myorg/api:stable
```

*Ref: logging drivers (see `docker run --help`).* ([Docker Documentation][1])

---

## 17) Disk cleanup & space reporting (safe CI ops)

**Everything at once (careful).**

```bash
docker system prune -f                 # keeps volumes
docker system prune -af --volumes      # nukes unused volumes too
```

**Targeted: containers/images/volumes/networks.**

```bash
docker container prune -f
docker image prune -af
docker volume prune -f
docker network prune -f
```

*Refs: prune/system prune docs.* ([Docker Documentation][19])

---

## 18) Image distribution & offline

**Save/load images as tar (for air‑gapped moves).**

```bash
docker save myorg/app:1.0 -o app_1.0.tar
docker load -i app_1.0.tar
```

**Export/import container rootfs (no history/layers).**

```bash
docker export web > webfs.tar
cat webfs.tar | docker import - myorg/web:rootfs
```

*Refs: CLI index.* ([Docker Documentation][1])

---

## 19) Healthchecks (diagnostic readiness)

**Add a healthcheck in your Dockerfile to surface status.**

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --retries=5 \
  CMD curl -fsS http://localhost:8080/health || exit 1
```

**View health via `ps`/`inspect`.**

```bash
docker ps
docker inspect -f '{{.State.Health.Status}}' <container>
```

*Ref: Dockerfile `HEALTHCHECK`.* ([Docker Documentation][5])

---

## 20) Rootless & group membership (security model)

**Add user to docker group (convenience, not least-privilege).**

```bash
sudo groupadd docker || true
sudo usermod -aG docker "$USER"
newgrp docker
```

> Consider **Rootless mode** to avoid granting root‑equivalent privileges to the `docker` group. Follow the official setup and networking tips. ([Docker Documentation][20])

---

## 21) Daemon configuration (enterprise knobs)

**Configure `/etc/docker/daemon.json` (Linux) then restart `docker`.**

```json
{
  "registry-mirrors": ["https://mirror.example.com"],
  "insecure-registries": ["registry.local:5000"],
  "default-address-pools": [{"base":"10.100.0.0/16","size":24}],
  "metrics-addr": "127.0.0.1:9323",
  "experimental": true
}
```

```bash
sudo systemctl restart docker
```

*Expose Prometheus metrics and scrape them from Prometheus.* ([Docker Documentation][21])

---

## 22) Supply‑chain security: scan, SBOM, policy (Docker Scout)

**Quickly view CVEs and a summary.**

```bash
docker scout quickview myorg/app:1.0
docker scout cves myorg/app:1.0
```

**Generate an SBOM (local) or attach at build time.**

```bash
docker scout sbom myorg/app:1.0
# with buildx:
docker buildx build -t myorg/app:1.0 --sbom=true --push .
```

**(Optional) Enforce policies in CI (org-level).**

```bash
docker scout policy evaluate myorg/app:1.0
```

*Refs: Docker Scout CLI (cves/sbom/policy) & quickstart.* ([Docker Documentation][22])

---

## 23) Daily quick reference (by task)

**Containers**

```bash
docker ps -a
docker run -d --name <n> -p 8080:80 <img>
docker logs -f --tail=200 <n>
docker exec -it <n> sh
docker stop <n>; docker rm <n>
```

**Images**

```bash
docker images; docker pull <img>:<tag>
docker build -t <repo>/<name>:<tag> .
docker tag <img>:old <repo>/<name>:new
docker push <repo>/<name>:<tag>
```

**Compose**

```bash
docker compose up --build -d
docker compose logs -f
docker compose exec <svc> sh
docker compose down -v
```

**Buildx (multi-arch)**

```bash
docker buildx create --name xbuilder --use
docker buildx build --platform linux/amd64,linux/arm64 -t <repo>/<img>:<tag> --push .
```

**Cleanup**

```bash
docker system df
docker system prune -af --volumes
docker buildx du; docker buildx prune -f
```

**Contexts & Remote**

```bash
docker context create prod --docker "host=ssh://user@prod"
docker context use prod
```

**Security quick wins**

```bash
docker run -d --user 10001:10001 --read-only \
  --cap-drop=ALL --cap-add=NET_BIND_SERVICE \
  --security-opt no-new-privileges <img>
```

**Healthcheck (Dockerfile)**

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s CMD curl -fsS http://localhost/health || exit 1
```

---

## Appendix A — Example Compose file (production‑aware)

```yaml
# compose.yaml
services:
  web:
    image: myorg/web:1.0
    ports: ["80:8080"]
    environment:
      - APP_ENV=prod
    deploy:                      # honored by Swarm (stack)
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
    healthcheck:
      test: ["CMD-SHELL","curl -fsS http://localhost:8080/health || exit 1"]
      interval: 30s
      timeout: 3s
      retries: 5
    restart: unless-stopped
    volumes:
      - webdata:/var/lib/app
    networks: [appnet]

  db:
    image: postgres:16
    environment:
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:?set_me}
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks: [appnet]
    profiles: ["db"]

volumes:
  webdata: {}
  pgdata: {}

networks:
  appnet: {}
```

*Refs: Compose spec & profiles/watch/scale.* ([Docker Documentation][23])

---

## Appendix B — Local registry for CI (image cache)

```bash
docker run -d -p 5000:5000 --restart always --name registry registry:3
docker tag myorg/app:dev localhost:5000/myorg/app:dev
docker push localhost:5000/myorg/app:dev
```

*Ref: Official registry image.* ([Docker Hub][14])

---

## Notes for this repository

This README is designed for the **L\&T EduTech training** context in `devops-shell-scripts` and mirrors the repository’s professional tone and hands‑on approach. You can place it at:

```
/docker/README.md
```

…and link it from your root `README.md` Table of Contents.

---

## References (per section)

* **CLI, run, ps, inspect, logs, images** — Docker CLI Reference. ([Docker Documentation][1])
* **Output formatting** — Format command and log output. ([Docker Documentation][24])
* **Compose v2** — Compose CLI, scaling, profiles, watch, file reference. ([Docker Documentation][25])
* **Dockerfile & healthcheck** — Dockerfile reference. ([Docker Documentation][5])
* **BuildKit & secrets** — BuildKit overview; build secrets. ([Docker Documentation][6])
* **SBOM & attestations** — SBOM attestations; Docker Scout SBOM. ([Docker Documentation][8])
* **Buildx** — buildx build/du/prune/create. ([Docker Documentation][26])
* **Registry auth** — `docker login`; ECR; `gcloud auth configure-docker`; ACR. ([Docker Documentation][10])
* **Local registry** — Official registry image page. ([Docker Hub][14])
* **Contexts** — Docker contexts (create/use/export). ([Docker Documentation][16])
* **Swarm/Stack/Service** — swarm init; service; stack deploy; compose v3 note. ([Docker Documentation][18])
* **Daemon metrics** — `dockerd --metrics-addr`; Prometheus. ([Docker Documentation][21])
* **Rootless & post-install** — Rootless mode; post-install warning. ([Docker Documentation][27])
* **Docker Scout** — CLI reference; quickstart; CVEs. ([Docker Documentation][22])

---

### Final tip

Treat Docker commands like any other code: **script them, version them, lint them**, and feed the results into your observability stack. That habit turns one-off commands into reliable, repeatable operations—exactly what you need in real enterprise work.

[1]: https://docs.docker.com/reference/cli/docker/ "Docker Docs"
[2]: https://docs.docker.com/reference/cli/docker/container/ls/ "docker container ls"
[3]: https://docs.docker.com/engine/containers/runmetrics/ "Runtime metrics"
[4]: https://docs.docker.com/reference/cli/docker/init/ "docker init"
[5]: https://docs.docker.com/reference/dockerfile/ "Dockerfile reference"
[6]: https://docs.docker.com/build/buildkit/ "BuildKit"
[7]: https://docs.docker.com/build/building/secrets/ "Build secrets"
[8]: https://docs.docker.com/build/metadata/attestations/sbom/ "SBOM attestations - Docker Docs"
[9]: https://docs.docker.com/reference/cli/docker/buildx/create/ "docker buildx create"
[10]: https://docs.docker.com/reference/cli/docker/login/ "docker login"
[11]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html "Private registry authentication in Amazon ECR"
[12]: https://cloud.google.com/sdk/gcloud/reference/auth/configure-docker "gcloud auth configure-docker"
[13]: https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-docker-cli "Push & Pull Container Image using Azure Container Registry"
[14]: https://hub.docker.com/_/registry "registry - Official Image"
[15]: https://docs.docker.com/reference/cli/docker/compose/ "docker compose"
[16]: https://docs.docker.com/engine/manage-resources/contexts/ "Docker contexts"
[17]: https://docs.docker.com/engine/swarm/stack-deploy/ "Deploy a stack to a swarm"
[18]: https://docs.docker.com/reference/cli/docker/swarm/init/ "docker swarm init"
[19]: https://docs.docker.com/reference/cli/docker/system/prune/ "docker system prune - Docker Docs"
[20]: https://docs.docker.com/engine/install/linux-postinstall/ "Linux post-installation steps for Docker Engine"
[21]: https://docs.docker.com/reference/cli/dockerd/ "dockerd | Docker Docs"
[22]: https://docs.docker.com/reference/cli/docker/scout/ "docker scout"
[23]: https://docs.docker.com/reference/compose-file/ "Compose file reference"
[24]: https://docs.docker.com/engine/cli/formatting/ "Format command and log output"
[25]: https://docs.docker.com/reference/cli/docker/compose/up/ "docker compose up"
[26]: https://docs.docker.com/reference/cli/docker/buildx/build/ "docker buildx build"
[27]: https://docs.docker.com/engine/security/rootless/ "Rootless mode"
