# Contents

1. [Foundations (Start Here)](#1-foundations-start-here)
2. [Data Sources (connect what you already run)](#2-data-sources-connect-what-you-already-run)
3. [Dashboards & Panels (visuals that ship)](#3-dashboards--panels-visuals-that-ship)
4. [Variables & Templating (dynamic dashboards)](#4-variables--templating-dynamic-dashboards)
5. [Query, Transform & Calculate](#5-query-transform--calculate)
6. [Explore, Logs & Traces (correlate fast)](#6-explore-logs--traces-correlate-fast)
7. [Alerting (rules, contact points, policies)](#7-alerting-rules-contact-points-policies)
8. [Provisioning as Code (YAML, Git, APIs)](#8-provisioning-as-code-yaml-git-apis)
9. [Security, RBAC & SSO](#9-security-rbac--sso)
10. [Performance, HA & Caching](#10-performance-ha--caching)
11. [Plugins & Extensions (signed & safe)](#11-plugins--extensions-signed--safe)
12. [Collection Pipelines (Grafana Alloy)](#12-collection-pipelines-grafana-alloy)
13. [Cloud & Kubernetes Integrations](#13-cloud--kubernetes-integrations)
14. [SLOs & Correlation (metrics ↔ logs ↔ traces)](#14-slos--correlation-metrics--logs--traces)
15. [CI/CD & Version Control (dashboards as code)](#15-cicd--version-control-dashboards-as-code)
16. [Troubleshooting Playbook](#16-troubleshooting-playbook)
17. [Enterprise Features & Governance](#17-enterprise-features--governance)
18. [Real-World Ops Runbook](#18-realworld-ops-runbook)

---

## 1) Foundations (Start Here)

**Topics (sub-categories):**

* What Grafana is (query, visualize, **alert**, **explore** metrics/logs/traces).
* Core objects: organizations, folders, dashboards, panels.
* The “flow”: Data source → Query/Explore → Panel → Dashboard → Alerts.

**Learning objectives (80/20)**

* Explain Grafana’s role vs. your TSDB/log store/trace store.
* Navigate Connections → Data sources; Dashboards; Explore; Alerting.
* Read a panel’s query and options without guessing.

**Hands-on (80/20 sprint)**

1. Spin up Grafana; add one data source (any you already have).
2. Open **Explore**, run a quick query, then save a panel to a new dashboard.
3. Share the dashboard link with a time range.

**Proof-of-skill**

* One-page diagram of “source → Explore → panel → alert” with screenshots.
* Short note describing where your metrics/logs/traces live.

> Grafana can query, visualize, **alert on**, and explore metrics/logs/traces; Explore is the starting point for ad-hoc analysis. 

---

## 2) Data Sources (connect what you already run)

**Topics:**

* Built-ins you’ll use a lot: **Prometheus**, **Loki**, **Tempo**, **CloudWatch**, **Azure Monitor**, **Google Cloud Monitoring**, **Elasticsearch**.
* Per-source query editors & auth; default vs non-default data source; provisioning.

**Learning objectives**

* Add at least three: metrics (Prometheus), logs (Loki), tracing (Tempo) or your cloud.
* Set auth correctly (keys/managed identity/headers) and **Save & Test** cleanly.
* Know where docs live for each source’s query language.

**Hands-on**

1. Add Prometheus + Loki + Tempo (or cloud providers you use).
2. Run one query per source in **Explore**; save each as a panel.
3. If in Azure/GCP/AWS, set the official data sources and auth.

**Proof-of-skill**

* `datasources/README.md` describing URLs/auth mode and test queries.

> Data source management & built-ins (Prometheus/Loki/Tempo/Cloud vendors). 

---

## 3) Dashboards & Panels (visuals that ship)

**Topics:**

* Panel anatomy: query + visualization; common viz: Time series, Stat, Bar gauge, Table.
* Library panels for reuse; annotations & links.

**Learning objectives**

* Build a dashboard with 6–8 panels and readable thresholds.
* Create one **library panel** used on multiple dashboards.
* Add dashboard links & annotations for deploy events.

**Hands-on**

1. Create a dashboard: latency, throughput, errors, saturation, and one table.
2. Convert your best panel to a **library panel** and reuse it.
3. Add an annotation data source or manual deploy markers.

**Proof-of-skill**

* Exported dashboard JSON + screenshot of Library panel usage.

> Panels are the building block; **library panels** propagate changes; annotations mark events; dashboard links can include variables/time. 

---

## 4) Variables & Templating (dynamic dashboards)

**Topics:**

* Variable types (query, custom, interval); formatting (`:singlequote`, `:sqlstring`); URL vars.

**Learning objectives**

* Build dashboards that switch env/cluster/service via variables.
* Use formatting to safely inject variable values into queries.
* Pass variables/time via links.

**Hands-on**

1. Add `${env}`, `${cluster}`, `${service}` variables.
2. Use a variable in a PromQL/LogQL query.
3. Share a dashboard link with URL variables applied.

**Proof-of-skill**

* Short video toggling variables and showing query changes.

> Variables power dynamic dashboards; formatting & URL variables control interpolation and sharing context. 

---

## 5) Query, Transform & Calculate

**Topics:**

* Query editors per source; **Transformations** (join, rename, math, reduce).

**Learning objectives**

* Combine two queries, then **transform** for a single, readable panel.
* Know when to calculate in Grafana vs in the backend.

**Hands-on**

1. Build two queries (e.g., requests & errors); compute error % in a transformation.
2. Join log counts with a metric series for context.

**Proof-of-skill**

* `transformations.md` with before/after screenshots and rationale.

> Transformations let you manipulate query results before visualization (join/rename/math). 

---

## 6) Explore, Logs & Traces (correlate fast)

**Topics:**

* **Explore** for ad-hoc queries; Logs integration (Loki/Elastic/CloudWatch); trace drilldowns (Tempo/Jaeger/Zipkin).
* Trace→logs and trace→metrics navigation.

**Learning objectives**

* Pivot between metrics, logs, and traces during an incident.
* Use split view in Explore to compare metrics/logs.

**Hands-on**

1. From a trace, jump to relevant logs; from logs, open the trace.
2. In Explore, split view: metrics left, logs right; sync time range.

**Proof-of-skill**

* Incident note showing the pivot path you used to find root cause.

> Explore is for ad-hoc analysis; you can jump **trace→logs** and **trace→metrics** with supported sources. 

---

## 7) Alerting (rules, contact points, policies)

**Topics:**

* Grafana Alerting concepts: **alert rules**, **contact points**, **notification policies**, **silences**; provisioning alerting as files/API/Terraform.

**Learning objectives**

* Create a rule on a Prometheus/Loki query with labels & annotations.
* Route alerts via a notification **policy tree** (env/team) to contact points.
* Provision contact points and rules from files for repeatability.

**Hands-on**

1. Create a contact point (email/webhook) & a basic rule; send a test notification.
2. Build a simple policy tree (prod vs non-prod); add a silence.
3. Provision an alert rule + contact point via YAML.

**Proof-of-skill**

* Screenshots of a firing & resolved alert + the YAML in git.

> Grafana Alerting centralizes rules & notifications; you can **provision** rules/contact points/policies via files or APIs. 

---

## 8) Provisioning as Code (YAML, Git, APIs)

**Topics:**

* Provision **datasources** & **dashboards** with YAML; “providers” for file-loaded dashboards; Git Sync (experimental) for bidirectional sync; HTTP API.

**Learning objectives**

* Keep Grafana config deterministic & versioned.
* Boot a new workspace from code only (no clicking).

**Hands-on**

1. Put YAML under `provisioning/datasources` and `provisioning/dashboards`; restart Grafana.
2. Try Git-based sync (where safe) or use the HTTP API to create/update dashboards.

**Proof-of-skill**

* Repo with provisioning files + a one-liner to stand up the same Grafana anywhere.

> Provision data sources & dashboards via YAML; Git Sync helps mirror dashboards; HTTP APIs cover dashboards & more. 

---

## 9) Security, RBAC & SSO

**Topics:**

* Users, teams, roles & permissions; data source permissions; SSO (OAuth, LDAP, SAML†); secrets in **secureJsonData**. (†SAML/advanced RBAC require Enterprise/Cloud.)

**Learning objectives**

* Restrict who can **query** sensitive data sources.
* Enable SSO and team mapping; keep API tokens and data source secrets safe.

**Hands-on**

1. Apply data source permissions to limit who can query production data.
2. Configure LDAP/OAuth (or SAML if you have Enterprise/Cloud).
3. Store creds/TLS in `secureJsonData`.

**Proof-of-skill**

* `security-setup.md` covering roles, SSO flow, and a masked data source config.

> RBAC & data source permissions; SAML/Team Sync are Enterprise/Cloud; secrets go in **secureJsonData** and are encrypted at rest. 

---

## 10) Performance, HA & Caching

**Topics:**

* **HA** requires shared DB (MySQL/Postgres); alerting HA requires Redis settings.
* Query/resource **caching** (Enterprise), remote cache (Redis/Memcached).
* Image rendering service and its resource profile.

**Learning objectives**

* Run active-active Grafana behind a load balancer with shared DB.
* Use caching (if Enterprise) to reduce backend load.
* Size image rendering correctly.

**Hands-on**

1. Migrate from SQLite → Postgres/MySQL; enable HA.
2. (Enterprise) Enable query caching and a remote cache; measure savings.
3. Configure image renderer (plugin or remote) & test a PDF/report.

**Proof-of-skill**

* `ha-notes.md` with architecture diagram and failover drill artifacts.

> HA needs a **shared database**; alerting HA uses Redis; **Enterprise** adds query/resource caching; image rendering has a dedicated plugin/service. 

---

## 11) Plugins & Extensions (signed & safe)

**Topics:**

* Panel/data source/app plugins; plugin **signing** & verification; plugin management.

**Learning objectives**

* Install only **signed** plugins; manage updates safely.
* Understand when you actually need a custom plugin.

**Hands-on**

1. Install a signed plugin; verify signatures.
2. Remove/disable a plugin and show impact on dashboards.

**Proof-of-skill**

* `plugins.md` listing installed plugins + signature status.

> Grafana requires plugins to be **signed**; manage/verify via plugin management docs. 

---

## 12) Collection Pipelines (Grafana Alloy)

**Topics:**

* **Grafana Alloy** — OpenTelemetry Collector distribution (successor to Grafana Agent) that handles metrics/logs/traces/profiles with Prometheus-native pipelines.
* Agent EOL timeline; migration.

**Learning objectives**

* Know when to deploy Alloy vs legacy agents.
* Sketch a pipeline: scrape → process → remote\_write to Mimir/Loki/Tempo.

**Hands-on**

1. Install Alloy; send metrics/logs/traces to your backends; verify in Grafana.
2. Document plan to migrate any remaining Grafana Agent usage.

**Proof-of-skill**

* `alloy-pipeline.hcl` (or YAML) + verification screenshots.

> Grafana **Agent** is deprecated; **Alloy** is the vendor-neutral OTel Collector distribution with Prometheus pipelines; Agent EOL **Nov 1, 2025**. 

---

## 13) Cloud & Kubernetes Integrations

**Topics:**

* Cloud data sources (CloudWatch, Azure Monitor, Google Cloud Monitoring).
* Kubernetes stacks often pair Grafana with Prometheus/Loki/Tempo.

**Learning objectives**

* Add your cloud telemetry directly and secure auth correctly.
* Reuse official dashboards for common services.

**Hands-on**

1. Connect CloudWatch/Azure/GCP Monitoring; import a ready dashboard.
2. Wire a k8s cluster’s metrics/logs/traces into Grafana (if you run them).

**Proof-of-skill**

* Folder of cloud dashboards + datasource docs for auth.

> Built-in support for CloudWatch/Azure/GCP Monitoring with per-source guidance. 

---

## 14) SLOs & Correlation (metrics ↔ logs ↔ traces)

**Topics:**

* **Exemplars** to jump from metrics to traces; trace drilldowns; trace→logs.

**Learning objectives**

* Add exemplars to your metrics (Prometheus) and link to Tempo.
* Use traces to pinpoint high-latency paths, then pivot to logs.

**Hands-on**

1. Enable exemplars; show “dots on the graph” → open the trace.
2. From a trace, jump to logs and back.

**Proof-of-skill**

* `correlation.md` with an end-to-end example and screenshots.

> Exemplars link metrics to traces; Grafana supports viewing exemplars and linking to Tempo; traces pages explain linking metrics/logs/traces.

---

## 15) CI/CD & Version Control (dashboards as code)

**Topics:**

* Dashboard JSON (schema v2), Observability as Code, HTTP API, import/export.

**Learning objectives**

* Keep dashboards in git; **provision or POST** via API in pipelines.
* Use PRs to review dashboard diffs like code.

**Hands-on**

1. Export JSON; commit to repo; redeploy via provisioning or API.
2. Add a CI job that POSTs updated dashboards after review.

**Proof-of-skill**

* Pipeline logs + a PR diff of a dashboard change.

> Dashboard JSON & schema v2; Observability as Code; Dashboard HTTP API for create/update/import. 

---

## 16) Troubleshooting Playbook

**Topics:**

* Data source “no data / cannot connect”; slow dashboards; import errors; where logs live.

**Learning objectives**

* Map symptoms → subsystem: data source/auth, query, transform, viz, perms.
* Use server logs and dashboard JSON model to diagnose.

**Hands-on**

1. Break a data source (bad URL/token); fix it and capture the steps.
2. Trigger a slow dashboard; simplify queries/transforms to recover.
3. Import a dashboard with missing data sources; fix bindings.

**Proof-of-skill**

* `troubleshooting.md`: symptom → cause → fix with commands & log snippets.

> Start with Grafana logs and dashboard JSON; use built-in troubleshooting guides for dashboards and queries. 

---

## 17) Enterprise Features & Governance

**Topics:**

* **RBAC (fine-grained)**, **data source permissions**, **query/resource caching**, **reporting**, **audit**.

**Learning objectives**

* Decide when OSS is enough vs when Enterprise/Cloud features pay off (RBAC, caching, reporting).
* Produce audit-friendly evidence of changes and access.

**Hands-on**

1. (Enterprise) Enable caching & measure backend load drop.
2. Create a scheduled PDF **report** and deliver to stakeholders.
3. Enable audit logging & capture a change trail.

**Proof-of-skill**

* `governance.md` with settings, evidence, and before/after metrics.

> Enterprise adds fine-grained RBAC, data source permissions, **query caching**, reporting; audit logs can be enabled for governance. 

---

## 18) Real-World Ops Runbook

**Topics:**

* Weekly: alert noise review, broken panels, slow queries.
* Monthly: base dashboard refresh, plugin updates, token rotations.
* Quarterly: HA failover drill, backup/restore test, audit export.
* Pre-release: verify alert rules, contact points, links, and annotation streams.

**Learning objectives**

* Run Grafana like a product with time-boxed maintenance & evidence.
* Keep dashboards fast and trustworthy.

**Hands-on**

1. Automate “lint” for dashboards (export → validate JSON) and API checks.
2. Run an HA failover exercise; record impact on alerts & users.

**Proof-of-skill**

* `ops-runbook.md` with calendar, scripts, last 3 reports (noise, perf, audits).