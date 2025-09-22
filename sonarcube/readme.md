# Contents

1. [Foundations (Start Here)](#1-foundations-start-here)
2. [Install, Upgrade & Migrate](#2-install-upgrade--migrate)
3. [Projects, Tokens & Scanners](#3-projects-tokens--scanners)
4. [Quality Profiles & Rules](#4-quality-profiles--rules)
5. [Quality Gates & Governance](#5-quality-gates--governance)
6. [CI Integration & PR Decoration](#6-ci-integration--pr-decoration)
7. [Branch & Pull Request Strategy](#7-branch--pull-request-strategy)
8. [Languages, Coverage & Test Reports](#8-languages-coverage--test-reports)
9. [Security (SAST, Secrets, IaC)](#9-security-sast-secrets-iac)
10. [User Management, SSO & Permissions](#10-user-management-sso--permissions)
11. [Performance, Tuning & Scaling](#11-performance-tuning--scaling)
12. [Database, Backup & DR](#12-database-backup--dr)
13. [Housekeeping & Data Lifecycle](#13-housekeeping--data-lifecycle)
14. [Extensibility: Plugins, Webhooks & API](#14-extensibility-plugins-webhooks--api)
15. [Troubleshooting Playbook](#15-troubleshooting-playbook)
16. [SonarCloud vs SonarQube (when to use which)](#16-sonarcloud-vs-sonarqube-when-to-use-which)
17. [Compliance & Audit Readiness](#17-compliance--audit-readiness)
18. [Real-World Ops Runbook](#18-real-world-ops-runbook)

---

## 1) Foundations (Start Here)

**Topics (sub-categories):**

* What SonarQube does: static code analysis, code smells, bugs, vulnerabilities, hotspots.
* Core concepts: Project, Portfolio, Quality Profile, Quality Gate, Issue types, Status.
* Editions & features: Community vs Developer vs Enterprise (brief awareness).
* UI tour: Issues, Measures, Security, Activity, Administration.

**Learning objectives (80/20)**

* Explain how code goes from CI → scanner → server → issues & gate.
* Read an issue, rule, and remediation guidance; mark FP/Won’t Fix correctly.
* Know where to set the default Quality Profile and default Gate.

**Hands-on (80/20 sprint)**

1. Spin up a local SonarQube container; login; create a test project.
2. Analyze a small repo with the scanner; review issues & hotspots.
3. Set a simple Quality Gate (coverage ≥ 80% on New Code).

**Proof-of-skill**

* A one-page diagram of the analysis flow + screenshots of first passing gate.

---

## 2) Install, Upgrade & Migrate

**Topics:**

* Supported platforms; Docker vs Linux service; ports; JVM options.
* Upgrades & DB migration path; zero-downtime strategies.
* Moving from embedded ES to external volumes; file system layout.
* Licensing application & edition switches.

**Learning objectives (80/20)**

* Install SonarQube with persistent storage and reverse proxy.
* Perform a safe minor-version upgrade with DB backup/restore.
* Verify system health (logs, `/api/system/health`).

**Hands-on**

1. Compose file (PostgreSQL + SonarQube) with named volumes.
2. Upgrade to the next minor; run DB migration; verify plugins.
3. Put NGINX in front with TLS; test health and auth.

**Proof-of-skill**

* `install-upgrade.md` with exact steps, rollback plan, and health checks.

---

## 3) Projects, Tokens & Scanners

**Topics:**

* Project creation (manual/auto), analysis tokens, global vs project tokens.
* SonarScanner CLI, Scanner for Maven/Gradle, .NET, Node (sonar-scanner).
* Global vs project settings (`sonar.projectKey`, sources, exclusions).
* Local vs CI auth; storing tokens securely.

**Learning objectives**

* Configure scanners per ecosystem with minimal flags.
* Keep secrets out of logs; rotate tokens.
* Standardize `sonar-project.properties`.

**Hands-on**

1. Add Sonar to a Maven repo with `sonar-maven-plugin`.
2. Create project token & analyze via CI; view analysis logs.
3. Centralize a reusable scanner step (Makefile or CI template).

**Proof-of-skill**

* `sonar-project.properties` templates and a working CI job.

---

## 4) Quality Profiles & Rules

**Topics:**

* Built-in vs extended rules; activating/deactivating rules.
* Custom Quality Profiles per language; default profile strategy.
* Managing false positives & rule exceptions (justified).
* Importing external rules (e.g., ESLint, Checkstyle) mapping.

**Learning objectives (80/20)**

* Create a tuned Quality Profile for each major language.
* Document exceptions; avoid blanket disables.
* Keep profiles versioned and auditable.

**Hands-on**

1. Clone default Java profile; enable security subset; set as default.
2. Map ESLint results to Sonar issues (where applicable).
3. Show before/after issue counts and rationale.

**Proof-of-skill**

* `quality-profiles.md` explaining rule choices and evidence.

---

## 5) Quality Gates & Governance

**Topics:**

* Gate conditions: New Code vs Overall Code; leak period definitions.
* Typical conditions: coverage, duplication, blocker/critical issues.
* Per-project overrides vs global defaults; gate evolution policy.
* Portfolios & Applications (Enterprise): roll-up views.

**Learning objectives**

* Design a strict-but-fair gate for **New Code** to prevent regressions.
* Apply exceptions (legacy) while pushing up the baseline.
* Use Applications/Portfolios to track product/program health.

**Hands-on**

1. Create “Org Default Gate”: coverage ≥ 80% on New Code, no new critical vulns.
2. Add one temp exception for a legacy repo; schedule removal.
3. Build a Portfolio and show trending charts.

**Proof-of-skill**

* Screenshot of passing/failed gates + rationale doc.

---

## 6) CI Integration & PR Decoration

**Topics:**

* GitHub/GitLab/Azure DevOps/Bitbucket integration & PR decoration.
* Status checks, required checks for merge; SonarQube Webhooks.
* Multi-repo templates for CI (Actions, GitLab CI, Azure Pipelines, Jenkins).
* Caching, parallel jobs, monorepo patterns.

**Learning objectives**

* Make PRs show inline issues & pass/fail gates.
* Reuse a single CI template across repos.
* Fail fast on gate violations.

**Hands-on**

1. Enable PR decoration for one repo; see inline comments.
2. Create a shared CI template with Sonar step.
3. Add a required status check to the main branch.

**Proof-of-skill**

* CI YAML snippets + screenshot of PR with Sonar summary.

---

## 7) Branch & Pull Request Strategy

**Topics:**

* Long-lived vs short-lived branches; which ones to analyze.
* Mainline protection; hotfix branches; feature PRs only.
* “New Code” definition (since leak period, since last version, etc.).
* Clean-as-you-code workflow.

**Learning objectives**

* Analyze PRs + main only; avoid wasting compute on ephemeral branches.
* Define “New Code” consistently across teams.
* Keep mainline green with required checks.

**Hands-on**

1. Configure analysis for `main` and PRs only.
2. Set New Code = “previous version” or “X days” and test the difference.
3. Prove blocked merge on red gate.

**Proof-of-skill**

* `branching.md` with policy, screenshots, and examples.

---

## 8) Languages, Coverage & Test Reports

**Topics:**

* Language analyzers: Java, Kotlin, C#, JS/TS, Python, Go, C/C++ (build wrapper), etc.
* Coverage ingestion: JaCoCo, Cobertura, Istanbul/LCOV, pytest-cov, Coverlet.
* Test report ingestion: JUnit, NUnit, Mocha/Jest, etc.
* Multi-module/monorepo setups.

**Learning objectives**

* Wire coverage & test reports per language.
* Normalize report paths in containers/CI.
* Ensure “coverage on New Code” is accurate.

**Hands-on**

1. Add JaCoCo to a Java build; feed XML to Sonar.
2. Add LCOV to a Node project; confirm coverage charts.
3. Combine reports from multiple modules.

**Proof-of-skill**

* `coverage.md` with examples for Java, JS/TS, Python, .NET.

---

## 9) Security (SAST, Secrets, IaC)

**Topics:**

* Vulnerabilities, Security Hotspots, and review workflow.
* Secret detection (tokens/keys).
* IaC scanners (Terraform, Kubernetes manifests) if available.
* Tuning security rules to reduce noise.

**Learning objectives**

* Handle Hotspots review properly; separate false positives.
* Detect secrets in code & block merges.
* Include Terraform/K8s checks where supported.

**Hands-on**

1. Turn on security rules; triage Hotspots in UI.
2. Trigger a secret detection and show the block.
3. Analyze sample Terraform and fix findings.

**Proof-of-skill**

* `security.md` with screenshots of findings + remediations.

---

## 10) User Management, SSO & Permissions

**Topics:**

* Users, groups, permissions templates; project vs global roles.
* SSO/LDAP/OIDC integration; SCIM awareness if using an IdP.
* Tokens lifecycle; audit who can administer what.

**Learning objectives**

* Map teams via SSO groups → SonarQube groups.
* Use permission templates for new projects.
* Rotate admin/token access; audit changes.

**Hands-on**

1. Create groups: `dev-read`, `lead-write`, `admin`.
2. Apply a permission template to new projects.
3. Integrate OIDC/LDAP and validate group mapping.

**Proof-of-skill**

* `access-control.md` with mapping tables and screenshots.

---

## 11) Performance, Tuning & Scaling

**Topics:**

* JVM heap sizing, GC tuning; Elasticsearch heap and disk.
* Web/Compute/Elastic separation (editions permitting).
* Background tasks throughput; concurrent analyses; CI concurrency.
* Reverse proxy timeouts; artifact size; log rotation.

**Learning objectives**

* Size SonarQube for concurrent PRs and large repos.
* Monitor CPU/mem/IO; avoid ES disk pressure.
* Keep response times low under load.

**Hands-on**

1. Set JVM/ES heap; enable GC logs; baseline throughput.
2. Load test with concurrent analyses; tune background workers.
3. Set NGINX timeouts & compression; verify.

**Proof-of-skill**

* `tuning.md` with before/after metrics and settings.

---

## 12) Database, Backup & DR

**Topics:**

* PostgreSQL as the supported DB; sizing, connection pool.
* Backups (logical/physical), PITR, retention policy.
* Restore rehearsals; environment promotion (stage → prod).

**Learning objectives**

* Run safe daily backups with verification.
* Restore into a sandbox; validate app health.
* Plan PITR for accidental deletion.

**Hands-on**

1. Nightly `pg_dump` + weekly physical backup; checksum + restore test.
2. Restore to a fresh SonarQube; point app; run a smoke analysis.
3. Document RPO/RTO targets.

**Proof-of-skill**

* `backup-dr.md` with scripts and restore screenshots.

---

## 13) Housekeeping & Data Lifecycle

**Topics:**

* Background tasks queue; log rotation; pruning old branches/analyses.
* Purge policies for analyses older than N days.
* Clean up inactive projects and tokens.

**Learning objectives**

* Keep DB lean and tasks flowing.
* Automate stale project detection & archival.

**Hands-on**

1. Set housekeeping schedules; prune stale analyses.
2. Write a script using Web API to list inactive projects.
3. Rotate logs & compress archives.

**Proof-of-skill**

* `housekeeping.md` with cron jobs and API scripts.

---

## 14) Extensibility: Plugins, Webhooks & API

**Topics:**

* Official vs community plugins; compatibility & risk.
* Webhooks to CI/chat/incident systems.
* Web API for automation (projects, measures, issues).
* Custom dashboards (where supported).

**Learning objectives**

* Add webhooks to notify on failed gates.
* Automate common tasks via Web API.
* Vet plugins for compatibility & security.

**Hands-on**

1. Create a webhook to Slack/Teams on gate fail.
2. Script: export top 10 violations by repo each week.
3. Install one safe plugin; document impact.

**Proof-of-skill**

* `automation.md` with webhook payloads and API scripts.

---

## 15) Troubleshooting Playbook

**Topics:**

* Analysis fails: wrong token, server URL, TLS/CA, proxy.
* Scanner errors (Java version mismatch, Node path, build wrapper for C/C++).
* PR decoration missing: permissions, webhook, VCS app config.
* Slow analysis: too many files, exclusions, cache, heap.

**Learning objectives**

* Map error messages → subsystem quickly.
* Fix PR decoration reliably.
* Right-size heap and exclusions.

**Hands-on**

1. Reproduce a token/URL error; fix and re-run.
2. Break decoration; fix VCS app permissions.
3. Add exclusions for generated/vendor code; measure speedup.

**Proof-of-skill**

* `troubleshooting.md`: symptom → cause → fix → command/log.

---

## 16) SonarCloud vs SonarQube (when to use which)

**Topics:**

* Hosted vs self-managed; data residency; enterprise controls.
* Cost model and scale; onboarding speed; maintenance load.
* Hybrid patterns (Cloud for OSS, Qube for internal).

**Learning objectives**

* Choose platform based on compliance, control, and TCO.
* Plan migration paths both ways.

**Hands-on**

1. Mirror one repo to SonarCloud; compare findings vs Qube.
2. Document pros/cons for your org.

**Proof-of-skill**

* Decision note with criteria matrix.

---

## 17) Compliance & Audit Readiness

**Topics:**

* Evidence for SDLC gates (coverage on New Code, no critical vulns).
* Audit trails: who changed gates/profiles, when.
* Mapping to frameworks: ISO 27001, SOC 2, PCI, OWASP ASVS (light mapping).

**Learning objectives**

* Export reports/screenshots to satisfy audits.
* Lock governance settings (admin-only).

**Hands-on**

1. Create an “Evidence Pack” (PDF/HTML) for an audited release.
2. Export audit log snapshots (changes to gates/profiles).

**Proof-of-skill**

* `audit-kit/` folder with generated evidence.

---

## 18) Real-World Ops Runbook

**Topics:**

* Weekly: plugin/version checks, DB size, background tasks, failing gates.
* Monthly: upgrade check, cleanups, token rotations, gate/profile review.
* Quarterly: DR drill, perf re-baseline, license review, portfolio health.
* Release: freeze window, pass gate, export evidence.

**Learning objectives**

* Treat SonarQube as a product with cadence and evidence.
* Keep noise low and signal high for developers.

**Hands-on**

1. Implement cron/CI jobs for weekly & monthly checks.
2. Run a DR drill; record time & steps.

**Proof-of-skill**

* `ops-runbook.md` with schedules, scripts and last three reports.

---

## How to break each topic into sub-topics

1. **Why it matters** (tie to code quality, security, or merge safety).
2. **Core concepts** (≤5 bullets).
3. **Configs & commands** (copy-paste blocks, scanner flags, API calls).
4. **Hands-on lab** (10–20 min task).
5. **Checks & pitfalls** (what usually breaks, how to know).
6. **Deliverables** (what to publish as proof: logs, screenshots, YAML).

---

## Suggested learning path (zero → expert)

1. **Foundations → Install → Projects/Scanners**
2. **Profiles → Gates → CI/PR Decoration → Branch Strategy**
3. **Coverage/Reports → Security → Users/SSO**
4. **Performance → DB/DR → Housekeeping → Extensibility**
5. **Troubleshooting → Compliance → Ops Runbook**

## Steps to run compose.yml
docker compose up -d