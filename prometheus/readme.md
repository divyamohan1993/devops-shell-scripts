# Contents

1. [Foundations (Start Here)](#1-foundations-start-here)
2. [Metrics & Instrumentation (client libs & conventions)](#2-metrics--instrumentation-client-libs--conventions)
3. [PromQL Fundamentals](#3-promql-fundamentals)
4. [Exporters & Integrations (node/blackbox/process…)](#4-exporters--integrations-nodeblackboxprocess)
5. [Scrape & Service Discovery (SD, relabeling)](#5-scrape--service-discovery-sd-relabeling)
6. [Recording & Alerting Rules](#6-recording--alerting-rules)
7. [Alertmanager (routing, grouping, inhibition)](#7-alertmanager-routing-grouping-inhibition)
8. [Dashboards & Visualization (Grafana)](#8-dashboards--visualization-grafana)
9. [Reliability & HA (pairs, federation)](#9-reliability--ha-pairs-federation)
10. [Long-Term Storage & Multi-Cluster (remote\_write, Thanos/Mimir/Cortex)](#10-longterm-storage--multicluster-remote_write-thanosmimircortex)
11. [Performance & Cardinality Control](#11-performance--cardinality-control)
12. [Security Hardening (TLS, auth, proxying)](#12-security-hardening-tls-auth-proxying)
13. [Kubernetes Monitoring (kube-prometheus-stack)](#13-kubernetes-monitoring-kubeprometheusstack)
14. [SLOs & Error Budgets (multi-window multi-burn)](#14-slos--error-budgets-multiwindow-multiburn)
15. [Tracing & Exemplars](#15-tracing--exemplars)
16. [CI/CD & Config Management (promtool, tests)](#16-cicd--config-management-promtool-tests)
17. [Troubleshooting Playbook](#17-troubleshooting-playbook)
18. [Real-World Ops Runbook](#18-realworld-ops-runbook)

---

## 1) Foundations (Start Here)

**Topics (sub-categories):**

* What Prometheus is: TSDB + pull model; server, exporters, Alertmanager, Grafana.
* Metric types: counter, gauge, histogram, summary (when to use each).
* Install & verify: run Prometheus, open UI, add a static target.
* Anatomy: samples, series, labels; job/instance.

**Learning objectives (80/20)**

* Explain pull-based scraping and where metrics live.
* Identify metric types correctly for real apps.
* Start Prometheus, scrape one target, run a query.

**Hands-on (80/20 sprint)**

1. Run Prometheus locally; add a `static_configs` target; open `/graph`.
2. Query `up`, `rate()` and basic aggregations. 
3. Add a second target; use labels to filter and group.

**Proof-of-skill**

* One-pager: components diagram + “my first query” screenshots.

---

## 2) Metrics & Instrumentation (client libs & conventions)

**Topics:**

* Client libraries & instrumentation surface; metric/label naming & units. 
* Counters vs gauges vs histograms/summaries (aggregation trade-offs). 
* Avoiding high-cardinality labels (user IDs, UUIDs). 
* Native histograms (status: experimental; feature flag). 

**Learning objectives (80/20)**

* Instrument a web handler with totals, errors, latency histogram.
* Apply naming & label hygiene that won’t melt your TSDB. 
* Decide when to use histogram vs summary. 

**Hands-on**

1. Add `*_total`, `*_seconds_bucket` to a demo API.
2. Pick sensible buckets; explain why. 
3. Run a quick load; verify metrics change.

**Proof-of-skill**

* Repo diff + short ADR: chosen metric types, labels, buckets.

---

## 3) PromQL Fundamentals

**Topics:**

* Instant vs range queries; selectors; functions & operators. 
* Rates/irates, histogram aggregation (`histogram_quantile`).
* Grouping/vector matching; label joins.

**Learning objectives**

* Write queries that power dashboards/alerts without overloading Prometheus.
* Convert raw counters to useful rates/ratios.
* Explain matching (`on`, `group_left`) in one example.

**Hands-on**

1. Build RPS, error-rate, p90 latency queries.
2. Create a 4-panel Grafana board from these queries.
3. Optimize a slow query (reduce label set/time range).

**Proof-of-skill**

* `queries.md` with copy-paste PromQL for your service.

---

## 4) Exporters & Integrations (node/blackbox/process…)

**Topics:**

* node\_exporter (host metrics), blackbox\_exporter (synthetic checks), process exporters. 
* Multi-target exporter pattern (probe params via labels). 
* Choosing and scoping exporters to avoid noisy metrics.

**Learning objectives**

* Stand up node/blackbox exporters correctly. 
* Design blackbox checks per service/SLO.
* Keep exporter metrics low-cardinality.

**Hands-on**

1. Run node\_exporter; scrape & graph CPU/FS. 
2. Run blackbox\_exporter; probe HTTP+TCP; create `probe_success` alert. 
3. Configure a process exporter for a critical daemon.

**Proof-of-skill**

* `exporters/` folder with configs + screenshots of metrics.

---

## 5) Scrape & Service Discovery (SD, relabeling)

**Topics:**

* `scrape_configs`, targets, SD backends (Kubernetes, EC2, file, HTTP SD). 
* `relabel_configs` vs `metric_relabel_configs`—keep/drop/rename. 
* Scrape intervals/timeouts; per-job credentials.

**Learning objectives**

* Onboard new services via SD + relabeling without code changes.
* Drop noisy targets & labels safely.
* Explain the diff between target relabeling and metric relabeling.

**Hands-on**

1. Add Kubernetes SD and relabel only annotated pods.
2. Keep/drop labels to enforce naming hygiene.
3. Tune `scrape_interval`/`scrape_timeout` per job.

**Proof-of-skill**

* `prometheus.yml` diff + a short note: why each relabel rule. 

---

## 6) Recording & Alerting Rules

**Topics:**

* Rule groups, evaluation interval, recording vs alerting rule syntax. 
* Naming conventions for aggregated series.
* Rule performance & dependency graphs.

**Learning objectives**

* Convert repeated queries into recording rules.
* Write alerts with `for:` and sane thresholds.
* Organize rules by team & latency budget.

**Hands-on**

1. Add a `slo:error_ratio:5m` recording rule.
2. Alert on high 5xx & slow latency with `for: 5m`.
3. Split rules into groups by eval time.

**Proof-of-skill**

* `rules/` with comments + `promtool check rules` output. 

---

## 7) Alertmanager (routing, grouping, inhibition)

**Topics:**

* Routing tree, receivers, grouping, inhibition, silences. 
* Deduplication across HA pairs.
* Templating titles & runbooks.

**Learning objectives**

* Build a routing tree per team/environment.
* Group alerts to reduce noise; add inhibition for parent/child.
* Use silences with expiry & owner labels.

**Hands-on**

1. Configure receivers for PagerDuty/Email/Slack.
2. Add `group_by` and inhibition rules. 
3. Create a silence via UI & API.

**Proof-of-skill**

* `alertmanager.yml` + screenshot of routed, grouped alerts.

---

## 8) Dashboards & Visualization (Grafana)

**Topics:**

* Prometheus data source; panels, variables, annotations. 
* Building latency (p50/p90/p99) from histograms.
* Linking panels to runbooks and traces.

**Learning objectives**

* Create “golden signals” dashboards per service.
* Use variables (env, cluster, service) for reuse.
* Add annotations from deploy webhooks.

**Hands-on**

1. Import Prometheus data source; build a 6-panel service board. 
2. Add deployment annotations.
3. Link a latency panel to traces (exemplars).

**Proof-of-skill**

* JSON export of a dashboard + screenshot in README.

---

## 9) Reliability & HA (pairs, federation)

**Topics:**

* HA Prometheus pairs; duplicate scraping and dedup in Alertmanager. 
* Federation basics (global queries).
* Query sharding (awareness).

**Learning objectives**

* Run two Prometheus servers scraping the same targets safely.
* Use federation for summary/aggregate views.
* Keep alerts deduped, not doubled.

**Hands-on**

1. Bring up an HA pair + one Alertmanager.
2. Verify dedup; test a downed instance.
3. Add a simple federation for a roll-up query.

**Proof-of-skill**

* Diagram + configs for HA/federation.

---

## 10) Long-Term Storage & Multi-Cluster (remote\_write, Thanos/Mimir/Cortex)

**Topics:**

* Remote-write spec & tuning; WAL queues, resources. 
* Thanos (global view, historical, object storage). 
* Grafana Mimir & Cortex (multi-tenant, horizontally scalable). 

**Learning objectives**

* Decide when to add remote\_write vs Thanos sidecar.
* Size memory/CPU for remote\_write. 
* Explain pros/cons of Thanos vs Mimir/Cortex.

**Hands-on**

1. Enable `remote_write` to a TSDB backend; observe queue metrics. 
2. Stand up a tiny Thanos demo or use a managed Mimir sandbox. 
3. Run one long-range query across clusters.

**Proof-of-skill**

* `lts-design.md` with chosen architecture + query proof.

---

## 11) Performance & Cardinality Control

**Topics:**

* Label & series cardinality—why it explodes; naming practices. 
* Histograms: bucket choice for cost/precision. 
* Scrape/eval intervals; churn; limits.

**Learning objectives**

* Detect & fix high cardinality; cap churny labels. 
* Optimize histograms for SLO graphs. 
* Tune scrape/eval cadence to load.

**Hands-on**

1. Run a cardinality report; drop one bad label.
2. Re-bucket a histogram; compare p90 drift.
3. Reduce TS count by 20% without losing signal.

**Proof-of-skill**

* Before/after TS count + query timings.

---

## 12) Security Hardening (TLS, auth, proxying)

**Topics:**

* Prometheus security model; do not expose endpoints publicly; TLS/basic auth options. 
* Reverse proxies, network ACLs; limit admin APIs. 
* Secrets in configs; exporter risks (URL-param targets). 

**Learning objectives**

* Serve Prometheus/Alertmanager behind TLS & auth.
* Block mutating/admin endpoints from the internet. 
* Harden blackbox/snmp exporters.

**Hands-on**

1. Put NGINX in front of Prometheus with TLS + basic auth.
2. Restrict `/-/reload` and admin APIs. 
3. Test access from allowed vs blocked IPs.

**Proof-of-skill**

* `security.md` with proxy config + checks.

---

## 13) Kubernetes Monitoring (kube-prometheus-stack)

**Topics:**

* kube-prometheus-stack (Prometheus, Alertmanager, Grafana, rules). 
* kube-state-metrics vs metrics-server (object state vs resource usage). 
* Prometheus Operator CRDs (ServiceMonitor/PodMonitor, PrometheusRule). 

**Learning objectives**

* Install kube-prometheus-stack; add a ServiceMonitor for your app. 
* Build cluster dashboards (nodes, pods, controllers).
* Wire cluster alerts (node pressure, crashloops).

**Hands-on**

1. Install the Helm chart; log in to Grafana. 
2. Deploy kube-state-metrics and graph deployment readiness. 
3. Add a `PrometheusRule` for API error rate.

**Proof-of-skill**

* `k8s-monitoring.md` with chart values + a Grafana screenshot.

---

## 14) SLOs & Error Budgets (multi-window multi-burn)

**Topics:**

* SLOs, error budgets, burn rate; multi-window multi-burn alerts (SRE Workbook). 
* Page vs ticket thresholds; windows (e.g., 1h/5m & 6h/30m). 

**Learning objectives**

* Define SLIs (success ratio/latency) and SLOs.
* Implement multi-window multi-burn alerts in Prometheus. 
* Triage with budget remaining.

**Hands-on**

1. Create SLI recording rules (success ratio, latency).
2. Add two burn-rate alerts (short+long window). 
3. Trigger in a test; verify paging vs ticketing.

**Proof-of-skill**

* `slo/` rules + redacted alert page from a test incident.

---

## 15) Tracing & Exemplars

**Topics:**

* Exemplars link metrics to traces; storage, UI support. 
* Client exemplar APIs; exemplar memory config/feature flag. 
* OpenTelemetry integration (awareness).

**Learning objectives**

* Emit exemplars on latency counters/histograms. 
* View exemplars in Grafana and jump to a trace. 
* Estimate memory impact of exemplar buffers. 

**Hands-on**

1. Add `trace_id` exemplars in your API handler. 
2. Enable exemplar display in Grafana; verify dots + link. 
3. Tune exemplar buffer; observe RAM change. 

**Proof-of-skill**

* Short demo video + config snippets.

---

## 16) CI/CD & Config Management (promtool, tests)

**Topics:**

* `promtool check/test rules`; unit testing alerts. 
* Lint in CI; GitOps for rules/dashboards.
* Safe rollouts & canaries for rule changes.

**Learning objectives**

* Validate all rules in CI before deploy.
* Write rule unit tests for edge cases. 
* Promote rules via PRs with review gates.

**Hands-on**

1. Add `promtool` checks to CI. 
2. Write one passing & one failing alert unit test. 
3. Auto-bundle dashboards/rules in a release artifact.

**Proof-of-skill**

* CI logs + a failing test screenshot caught pre-merge.

---

## 17) Troubleshooting Playbook

**Topics:**

* “Target down” (DNS, network, auth); scrape timeouts.
* Stale series vs zero; query returns nothing; time skew.
* Alert not firing: `for:` window, label mismatch, recording not updated.
* High TS churn; WAL/remote\_write backpressure.

**Learning objectives**

* Map symptom → subsystem in minutes.
* Use `/status`, rule timings, target page, `tsdb status`.
* Fix mis-matched labels and set math errors.

**Hands-on**

1. Force a scrape failure; fix via relabel.
2. Break an alert (wrong labels) and repair.
3. Resolve a remote\_write queue overflow.

**Proof-of-skill**

* `troubleshooting.md`: issue → root cause → fix (with commands).

---

## 18) Real-World Ops Runbook

**Topics:**

* Weekly: check failed alerts, noisy routes, dashboard performance.
* Monthly: refresh bases, prune unused metrics, review cardinality.
* Quarterly: restore drill, upgrade Prometheus/Alertmanager, rule audits.
* Pre-release: rule canaries, dashboard links, paging dry-run.

**Learning objectives**

* Run Prometheus like a product with cadence and evidence.
* Keep alerts useful; keep TS under control.

**Hands-on**

1. Implement cron/CI jobs: rule tests, TS cardinality reports.
2. Run a DR restore from backups; time it.

**Proof-of-skill**

* `ops-runbook.md` + last three audit artifacts.