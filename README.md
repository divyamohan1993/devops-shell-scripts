<a name="top"></a>

<div align="center" style="display:flex;justify-content:center;align-items:center;gap:48px;">
  <a href="https://shooliniuniversity.com/" target="_blank">
    <img src="https://shooliniuniversity.com/assets/images/logo.png" alt="Shoolini University — Logo" height="72">
  </a>
  <a href="https://lntedutech.com/" target="_blank">
    <img src="https://lntedutech.com/wp-content/uploads/2024/01/edutech_logo.webp" alt="L&T EduTech — Logo" height="72">
  </a>
</div>

<h1 align="center">DevOps & Deployment: L&amp;T EduTech Training Repository</h1>

<p align="center">Prepared by <strong>Divya Mohan</strong> under the guidance of <strong>Prashant Singh Gautam</strong></p>
<p align="center">
  <a href="https://github.com/divyamohan1993/devops-shell-scripts/actions/workflows/lint.yml">
    <img alt="Lint status" src="https://github.com/divyamohan1993/devops-shell-scripts/actions/workflows/lint.yml/badge.svg">
  </a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-blue.svg"></a>
</p>

### Academic Information

- **Institution:** Shoolini University  
- **Program:** DevOps & Deployment by L&T EduTech (Hands-on Training)  
- **Repository:** <a href="https://github.com/divyamohan1993/devops-shell-scripts/">github.com/divyamohan1993/devops-shell-scripts</a>



## What this repo does for you

**Short version:** it helps you **learn and practice real DevOps** with small, reproducible labs you can run safely on a VM or in containers. You’ll pick up solid Bash habits, build and ship containers, wire up CI, add observability, and keep security in the loop—without wading through bloated boilerplate.

**You’ll get:**
- **Copy‑pasteable Bash** with safe defaults (`bash -euxo pipefail`), ready to tweak.
- **Container & K8s labs** that show *how* to deploy, not just *what* to click.
- **CI and DevSecOps checks** (linting, secret scanning) you can reuse at work.
- **Observability starters** (Prometheus/Grafana) to see what your services are doing.

If you want practical reps, fast feedback, and fewer gotchas then this is for you.


## Who it’s for

- Students and early‑career engineers who want hands‑on, **production‑aware** workflows.  
- Developers moving toward DevOps/SRE and looking for **sane, repeatable** scripts.  
- Busy pros who want **small labs** to demo an idea before committing infra time.


## What’s inside (high‑level map)

- `docker/` — container builds & compose examples  
- `k8s/` — manifests, kind/minikube helpers, Helm/Kustomize snippets  
- `jenkins/` — Jenkins auto‑config examples  
- `sonarcube/` — SonarQube auto‑config + compose  
- `prometheus/`, `grafana/` — metrics + dashboards starters  
- `springboot/` — app bits used in some labs  
- `zero-trust-mysql*` — experiments around safer DB access  
- `autoscalling-loadbalancing-demo/` — scaling & LB demo scripts  

> Everything is designed to run in an **isolated environment** (container or throwaway VM) first. Start small, break safely, then harden.

## Quick start (5–10 minutes)

```bash
# 1) Clone
git clone https://github.com/divyamohan1993/devops-shell-scripts.git
cd devops-shell-scripts

# 2) Try a lab (example: a docker/ or k8s/ script)
# Always run with strict bash flags while experimenting:
bash -euxo pipefail ./docker/<some-script>.sh   # or k8s/, jenkins/, etc.

# 3) (Optional) Run the linters locally
#   Install shellcheck, then:
shellcheck $(git ls-files '*.sh') || true

# container scan examples
trivy image alpine:3.20
grype alpine:3.20

# IaC checks
checkov -d ./iac
````

> Tip: Prefer containers or a disposable VM. Never run unreviewed scripts on production systems.


## Learning objectives

* Write **defensive Bash** (linted, logged, idempotent).
* Build & ship **containers**; deploy to **Kubernetes** (Helm/Kustomize friendly).
* Wire **CI** with quality/security gates (lint, secret scans).
* Manage **IaC** choices and environment promotion.
* Add **observability**: metrics, dashboards, and basic alerts.

## Why DevOps

<div style="text-align: justify !important">
This course emphasizes the outcomes DevOps enables: repeatable builds, safe releases, faster feedback, and secure-by-default systems. The following “Top 10” lists map these outcomes to the most common, enterprise-grade capabilities you’ll exercise in labs and in real-world teams.
</div>

## DevOps — Top 10 Daily Tools

1. **Git-based source control & PR flow**
   Tools: GitHub / GitLab / Bitbucket. (Git is near-universal across teams.)

2. **CI/CD pipelines**
   Tools: GitHub Actions, Jenkins, GitLab CI, Azure DevOps, CircleCI.

3. **Containers**
   Tools: Docker, Podman.

4. **Orchestration / platform**
   Tools: Kubernetes (+ Helm, Kustomize, Argo CD/Flux). (Cloud-native adoption is widespread; K8s is common in production.)

5. **Infrastructure as Code**
   Tools: Terraform/OpenTofu, CloudFormation, Pulumi.

6. **Config & release management**
   Tools: Ansible, Helm, Packer.

7. **Observability (metrics + dashboards + alerting)**
   Tools: Prometheus + Grafana; Datadog, New Relic, Splunk.

8. **Centralized logging**
   Tools: Elastic Stack (Elasticsearch/Logstash/Kibana), Loki, **AWS CloudWatch / Google Cloud Logging (formerly Stackdriver)**.

9. **Artifact & container registries**
   Tools: Artifactory, Nexus, Harbor; GitHub/GitLab Packages; ECR/GCR/ACR.

10. **Project tracking & ChatOps**
    Tools: Jira / GitHub Issues / Azure Boards; Slack / Microsoft Teams for alerts & runbooks.

## DevSecOps — Top 10 Daily Tools

1. **Software Composition Analysis (SCA) & dependency updates**
   Tools: Dependabot, Snyk, OWASP Dependency-Check, Renovate.

2. **Secrets hygiene & leak prevention**
   Tools: GitHub Secret Scanning, Gitleaks, TruffleHog.

3. **Static Application Security Testing (SAST) in CI**
   Tools: SonarQube/SonarCloud, Semgrep, Checkmarx, Veracode, GitLab SAST.

4. **Dynamic testing of running apps (DAST)**
   Tools: OWASP ZAP, Burp Suite, StackHawk.

5. **Container/image & artifact scanning**
   Tools: Trivy, Grype, Anchore, Clair; Syft for SBOMs.

6. **IaC & K8s policy checks (shift-left)**
   Tools: Checkov, tfsec/Terrascan; **Policy-as-Code with OPA/Conftest**, Kyverno.

7. **Secrets management**
   Tools: HashiCorp Vault (incl. HCP Vault), External Secrets Operator, cloud KMS.

8. **Supply chain integrity: SBOMs & signing**
   Tools: Syft/CycloneDX/SPDX for SBOMs; **Sigstore cosign** for signing/attestations.

9. **Runtime & cloud-native threat detection**
   Tools: **Falco**; plus CNAPP/CSPM platforms (Wiz/Prisma/Defender/etc.).

10. **Vulnerability management & SIEM/SOAR**
    Tools: Tenable Nessus, Qualys, Defender for Cloud; SIEMs: Splunk, Sentinel.


## Notes, Credits & Responsible Use

* **Contributor:** Divya Mohan — learning in public, iterating fast.
* **Academic context:** Shoolini University × L\&T EduTech DevOps training.
* **Trainer:** Prashant Singh Gautam.

### Responsible use

These scripts are for **learning and prototyping**. Review before running, prefer containers/VMs, and never run unvetted commands on production systems. Replace placeholders, keep secrets out of source control, and enable branch protections + required checks. **No warranty; use at your own risk.**

### Acknowledgments

Thanks to the instructor, peers, and the broader open-source community whose tools and docs make this work possible.

### Contact & Contributions

Have ideas or spot issues? Please open a **GitHub Issue** in this repo. Discussions and PRs welcome—start with a Discussion for ideas. See **CONTRIBUTING.md** for the fast path (branch naming, checks, PR checklist). Please report security findings privately (see **SECURITY.md**).


### License & attribution

MIT © Divya Mohan. Logos belong to their respective owners and are used only for identification.

<p align="right"><a href="#top">Back to top ↑</a></p>
