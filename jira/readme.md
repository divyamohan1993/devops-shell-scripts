# Jira (JQL, REST & CLI)

> **Scope & assumptions**
>
> * Focus: **Jira Cloud**. Platform REST base is `https://YOURDOMAIN.atlassian.net/rest/api/3` and Jira Software (Agile) base is `.../rest/agile/1.0`. (Data Center/API v2 largely parallels, but Cloud v3 adds **ADF**—Atlassian Document Format—for rich text.) ([Atlassian Developer][1])
> * Auth: Use **email + API token** for Basic auth in scripts; or OAuth 2.0 (3LO) for apps. **Usernames are deprecated—use `accountId`.** ([Atlassian Developer][2])



## 0) First‑time setup (one‑time)

1. **Create an API token (for scripts/CI).**
   Create & copy a token from your Atlassian account; store it in a secret manager. ([Atlassian Support][3])

2. **Set standard env vars (shell profile).**

```bash
export JIRA_BASE="https://YOURDOMAIN.atlassian.net"
export JIRA_USER="you@company.com"
export JIRA_TOKEN="***"                       # store in a secret store in CI
export JIRA_HEADERS='-H Content-Type:application/json -H Accept:application/json'
# For file uploads add: -H "X-Atlassian-Token: no-check"
```

*Why:* keeps `curl` short; XSRF header is required for attachments. ([Atlassian Developer][4])

3. **Pick your auth method.**

* **Basic (scripts/one‑offs):** `curl -u "$JIRA_USER:$JIRA_TOKEN" …` (works with 2FA enabled). ([Atlassian Developer][2])
* **OAuth 2.0 (apps):** request **granular scopes** (e.g., `read:issue-details:jira`, `write:issue:jira`) per endpoint docs. ([Atlassian Developer][5])



## 1) JQL one‑liners (daily searching)

> Paste these into Jira’s **Advanced search** bar (or pass via REST). They’re ordered from starter → power user. Save frequent ones as filters. ([Atlassian Support][6])

**Starter**

```
assignee = currentUser() AND resolution = Unresolved ORDER BY priority DESC, updated DESC
project = ABC AND statusCategory != Done ORDER BY updated DESC
reporter = currentUser() AND created >= startOfDay(-7d)
text ~ "timeout" AND project IN (ABC,XYZ)
labels IN (hotfix) AND priority IN (Highest,High)
component = "Payments" AND fixVersion = 2025.9
```

**Team / Sprint / Flow**

```
project = ABC AND sprint IN openSprints()
project = ABC AND sprint IN futureSprints() ORDER BY Rank ASC
project = ABC AND "Epic Link" = ABC-123 ORDER BY updated DESC
issuekey IN linkedIssues(ABC-123)
"Story Points" is EMPTY AND issuetype in (Story,Bug)
status CHANGED FROM "In Progress" TO "Done" BY currentUser() AFTER startOfWeek()
```

**Service Mgmt / SLA / Triage**

```
project = ITSM AND "Request Type" = "Access" AND statusCategory != Done
project = ITSM AND created >= startOfDay() AND priority = Highest ORDER BY created ASC
project = ITSM AND assignee IS EMPTY AND created >= -1d
```

**Ops hygiene / stale work**

```
status NOT IN (Done,Closed,Cancelled) AND updated <= startOfDay(-14d) ORDER BY updated ASC
assignee WAS currentUser() AFTER startOfMonth(-1) AND statusCategory = "In Progress"
```

**Release & quality**

```
fixVersion = 2025.10 AND type IN (Bug,Incident) ORDER BY priority DESC
affectedVersion = 2025.9 AND labels = regression
```

**Ownership & groups**

```
assignee IN membersOf("jira-software-users")
watcher = currentUser()
```

> **Tip:** Use `ORDER BY Rank ASC` with boards, `statusCategory` for stage‑based queries, and relative functions like `startOfDay()`, `endOfWeek()`. See Atlassian’s JQL guide/cheat sheet for more. ([Atlassian Support][6])



## 2) Issues via REST — your day‑to‑day (copy/paste)

> Cloud REST v3 examples with `curl`. Replace `ABC-123` etc. Rich text fields (e.g., `description`, `comment.body`) in v3 use **ADF**. ([Atlassian Developer][1])

### 2.1 Read & search

* **Get one issue (select fields & expands).**

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
  "$JIRA_BASE/rest/api/3/issue/ABC-123?fields=summary,status,assignee,labels&expand=renderedFields"
```

*Docs:* Issues group (v3). ([Atlassian Developer][7])

* **JQL search (POST)** — fast and avoids URL length limits.

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
  -X POST "$JIRA_BASE/rest/api/3/search" \
  -d '{"jql":"project=ABC AND statusCategory!=Done ORDER BY updated DESC","maxResults":50,"fields":["key","summary","status","assignee"]}'
```

*Notes:* Search is paginated (`startAt`, `maxResults`), with operation‑specific caps—**use pagination** to get all results. ([Atlassian Developer][8])

### 2.2 Create, edit, comment, link

* **Create an issue (minimal).**

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
  -X POST "$JIRA_BASE/rest/api/3/issue" \
  -d '{"fields":{"project":{"key":"ABC"},"summary":"API-created ticket","issuetype":{"name":"Task"}}}'
```

*Docs:* Create issue (v3). For required fields per project, call **Create metadata**. ([Atlassian Developer][7])

* **Edit fields on an issue.**

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
  -X PUT "$JIRA_BASE/rest/api/3/issue/ABC-123" \
  -d '{"fields":{"labels":["ops","urgent"],"priority":{"name":"High"}}}'
```

*Docs:* Edit issue (v3). ([Atlassian Developer][7])

* **Add a comment (ADF rich text).**

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
  -X POST "$JIRA_BASE/rest/api/3/issue/ABC-123/comment" \
  -d '{"body":{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"Deploy completed ✅"}]}]}}'
```

*Docs:* Comment body uses **ADF** in v3. ([Atlassian Developer][1])

* **Upload an attachment** (multipart form; must include XSRF bypass header).

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" \
  -H "X-Atlassian-Token: no-check" -F "file=@release-notes.txt" \
  "$JIRA_BASE/rest/api/3/issue/ABC-123/attachments"
```

*Docs:* Attachments API requires `X-Atlassian-Token: no-check` and field `file=@…`. ([Atlassian Developer][4])

* **Link two issues** (e.g., “relates to”, “blocks”).

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
  -X POST "$JIRA_BASE/rest/api/3/issueLink" \
  -d '{"type":{"name":"Relates"},"inwardIssue":{"key":"ABC-123"},"outwardIssue":{"key":"ABC-456"}}'
```

*Docs:* Issue link types & linking. ([Atlassian Developer][9])

* **Add a watcher** (you or a user by `accountId`).

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" -H "Content-Type: application/json" \
  -X POST "$JIRA_BASE/rest/api/3/issue/ABC-123/watchers" \
  -d '"5b10ac8d82e05b22cc7d4ef5"'
```

*Docs:* Add watcher uses **accountId** string; omitting body adds the calling user. ([Atlassian Developer][10])

### 2.3 Assign & transition

* **Assign (to user by accountId).**

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
  -X PUT "$JIRA_BASE/rest/api/3/issue/ABC-123/assignee" \
  -d '{"accountId":"5b10ac8d82e05b22cc7d4ef5"}'
```

*Docs:* Issues group shows **Assign issue**; Cloud uses accountId (GDPR). ([Atlassian Developer][7])

* **Find valid transitions for an issue** (get IDs/names).

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" \
  "$JIRA_BASE/rest/api/3/issue/ABC-123/transitions?expand=transitions.fields"
```

* **Perform a transition** (e.g., to “In Progress” id=21; add fields shown by expand).

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
  -X POST "$JIRA_BASE/rest/api/3/issue/ABC-123/transitions" \
  -d '{"transition":{"id":"21"}}'
```

*Notes:* Use the **transition id** returned by GET; simultaneous transitions are not supported; if a transition has a screen, include required fields under `fields`/`update`. ([Atlassian Developer][7])

### 2.4 Bulk operations (safe patterns)

* **Bulk create** many issues in one call.

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
  -X POST "$JIRA_BASE/rest/api/3/issue/bulk" \
  -d '{"issueUpdates":[{"fields":{"project":{"key":"ABC"},"summary":"Item 1","issuetype":{"name":"Task"}}},{"fields":{"project":{"key":"ABC"},"summary":"Item 2","issuetype":{"name":"Task"}}}]}'
```

* **Bulk search + transition**: search → map transitions by id → POST transition per issue (no single call to bulk transition). ([Jira][11])



## 3) Agile (Jira Software) — boards, sprints, backlog

> These endpoints live under `.../rest/agile/1.0/…`. They require appropriate Jira Software scopes/permissions. ([Atlassian Developer][12])

* **List boards (filter by project).**

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" \
  "$JIRA_BASE/rest/agile/1.0/board?projectKeyOrId=ABC"
```

*Docs:* Board APIs. ([Atlassian Developer][13])

* **List sprints on a board** (active/future/closed).

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" \
  "$JIRA_BASE/rest/agile/1.0/board/123/sprint?state=active"
```

*Docs:* Sprint group (state can be `active`, `future`, `closed`). ([Atlassian Developer][14])

* **Create a sprint** (future state).

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
  -X POST "$JIRA_BASE/rest/agile/1.0/sprint" \
  -d '{"name":"Sprint 42","originBoardId":123,"startDate":"2025-10-01T09:00:00.000Z","endDate":"2025-10-15T17:00:00.000Z","goal":"Release RC"}'
```

* **Start / complete a sprint** (update `state`).

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
  -X PUT "$JIRA_BASE/rest/agile/1.0/sprint/456" \
  -d '{"state":"active"}'     # later: {"state":"closed"}
```

*Docs:* Sprint lifecycle via `PUT` and `state`. ([Atlassian Developer][14])

* **Move issues into a sprint** (by sprint id).

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
  -X POST "$JIRA_BASE/rest/agile/1.0/sprint/456/issue" \
  -d '{"issues":["ABC-123","ABC-456"]}'
```

*Docs:* Use Software API to add issues to a sprint; you can’t set `sprint` at create unless on screen. ([Atlassian Community][15])

* **Move issues to backlog** (remove from sprint).

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
  -X POST "$JIRA_BASE/rest/agile/1.0/backlog/issue" \
  -d '{"issues":["ABC-123","ABC-456"]}'
```

*Docs:* Backlog API (max 50 per call). ([Atlassian Developer][16])



## 4) Users, groups & watchers (Cloud = `accountId`)

* **Find users (search by email/name → yields `accountId`).**

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" \
  "$JIRA_BASE/rest/api/3/user/search?query=someone@company.com"
```

*Notes:* Cloud privacy changes require **accountId** (username/userkey deprecated). ([Atlassian Developer][17])

* **Add/remove watcher** — see 2.2. ([Atlassian Developer][10])



## 5) Attachments — common pitfalls

* Use `multipart/form-data` with key `file` and header `X-Atlassian-Token: no-check`. 415/403 errors usually mean wrong headers/body. ([Atlassian Support][18])



## 6) Webhooks & integrations

* **Admin‑configured webhooks** (notify your app on issue changes without polling). Configure in **Jira Admin → System → Webhooks**; apps can also register dynamic webhooks via API. ([Atlassian Developer][19])



## 7) JiraCLI (terminal‑friendly workflows)

> Prefer a CLI instead of raw `curl`? Two popular choices:

### 7.1 JiraCLI (`jira`) by @ankitpokhrel (modern, interactive)

* **Install (Linux/macOS):**

```bash
# Go install
go install github.com/ankitpokhrel/jira-cli/cmd/jira@latest
# Or download a release binary; or use Snap/Brew per OS
```

* **Initialize:**

```bash
jira init   # prompts for site, user (email), API token
```

* **Everyday commands:**

```bash
jira issue list -p ABC --assignee @me
jira issue view ABC-123
jira issue create -p ABC -t Task -s "CLI-created task"
jira issue edit ABC-123 --assign 5b10ac8d82e05b22cc7d4ef5
jira issue comment ABC-123 -m "Investigating"
jira issue attach ABC-123 ./release-notes.txt
jira issue transition ABC-123 --to "In Progress"
jira sprint list --board 123
```

*Docs & features:* interactive lists, create/edit/transition/link/attach. ([GitHub][20])

### 7.2 go‑jira (`jira`) by Netflix/Community (scriptable, extensible)

```bash
# Example: list / view / create
jira ls -p ABC -t table
jira view ABC-123
jira create -p ABC -i Task -o summary="From CLI"
```

*Docs:* supports **custom commands** via `.jira.d/config.yml`. ([GitHub][21])

> Enterprise alternative: **Appfire “Atlassian CLI (acli)”** (licensed) provides rich cross‑product automation with a client + server app. ([appfire.atlassian.net][22])



## 8) Senior‑level patterns (copy/paste recipes)

1. **Idempotent search export (paginate reliably).**

```bash
JQL='project=ABC AND updated >= startOfDay(-7d)'
for START in 0 50 100 150; do
  curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS \
    -X POST "$JIRA_BASE/rest/api/3/search" \
    -d "{\"jql\":\"$JQL\",\"startAt\":$START,\"maxResults\":50,\"fields\":[\"key\",\"summary\",\"status\",\"assignee\"]}" \
    | jq -r '.issues[] | [.key,.fields.summary,.fields.status.name,(.fields.assignee.displayName // "Unassigned")] | @tsv'
done
```

*Why:* Jira Cloud enforces per‑operation `maxResults`—paginate. ([The Atlassian Developer Community][23])

2. **Create → attach → transition (safe, stepwise).**

```bash
KEY=$(curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS -X POST "$JIRA_BASE/rest/api/3/issue" \
  -d '{"fields":{"project":{"key":"ABC"},"summary":"Deploy ticket","issuetype":{"name":"Task"}}}' | jq -r .key)

curl -s -u "$JIRA_USER:$JIRA_TOKEN" -H "X-Atlassian-Token: no-check" \
  -F "file=@deploy.log" "$JIRA_BASE/rest/api/3/issue/$KEY/attachments"

# find transition id for "In Progress"
ID=$(curl -s -u "$JIRA_USER:$JIRA_TOKEN" "$JIRA_BASE/rest/api/3/issue/$KEY/transitions" \
  | jq -r '.transitions[] | select(.name=="In Progress") | .id')
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS -X POST "$JIRA_BASE/rest/api/3/issue/$KEY/transitions" -d "{\"transition\":{\"id\":\"$ID\"}}"
```

*Why:* Transition IDs are workflow‑specific; get them dynamically. ([Atlassian Developer][7])

3. **Gate deployment on board readiness (no unresolved blockers).**

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS -X POST "$JIRA_BASE/rest/api/3/search" \
  -d '{"jql":"project=ABC AND labels=release-2025-09 AND statusCategory != Done AND priority in (Highest, High)","maxResults":1}' \
  | jq -e '.issues | length == 0' >/dev/null || { echo "Blockers present"; exit 1; }
```

4. **Sprint management (create → start → move issues).**

```bash
# create future sprint on board 123
SPRINT=$(curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS -X POST "$JIRA_BASE/rest/agile/1.0/sprint" \
  -d '{"name":"Sprint 43","originBoardId":123,"startDate":"2025-10-16T09:00:00.000Z","endDate":"2025-10-30T17:00:00.000Z","goal":"PI-10 Milestone"}' | jq -r .id)

# start it
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS -X PUT "$JIRA_BASE/rest/agile/1.0/sprint/$SPRINT" -d '{"state":"active"}'

# move issues into sprint (max 50)
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS -X POST "$JIRA_BASE/rest/agile/1.0/sprint/$SPRINT/issue" -d '{"issues":["ABC-123","ABC-456"]}'
```

*Docs:* Sprint lifecycle & backlog operations. ([Atlassian Developer][14])

5. **Add a watcher automatically (owner + oncall).**

```bash
for AID in "5b10ac8d82e05b22cc7d4ef5" "5b10ac8d82e05b22cc7d4ab1"; do
  curl -s -u "$JIRA_USER:$JIRA_TOKEN" -H "Content-Type: application/json" \
       -X POST "$JIRA_BASE/rest/api/3/issue/ABC-123/watchers" -d "\"$AID\"" >/dev/null
done
```

*Docs:* Watchers API (accountId). ([Atlassian Developer][10])

6. **Create an ADF rich comment with code block + mention.**

```bash
curl -s -u "$JIRA_USER:$JIRA_TOKEN" $JIRA_HEADERS -X POST "$JIRA_BASE/rest/api/3/issue/ABC-123/comment" -d @- <<'JSON'
{
  "body": {
    "type": "doc",
    "version": 1,
    "content": [
      {"type":"paragraph","content":[{"type":"text","text":"@mention build bot and attach logs:"}]},
      {"type":"codeBlock","attrs":{"language":"bash"},"content":[{"type":"text","text":"kubectl logs deploy/api -n prod | tail -n 50"}]}
    ]
  }
}
JSON
```

*Docs:* Comments in v3 use **ADF** schema. ([Atlassian Developer][24])

7. **Webhook‑driven automation** (no polling).
   Configure **Jira → Admin → Webhooks** to call your endpoint on `issue_updated`, `comment_created`, `sprint_started`, etc.; verify signatures as needed. ([Atlassian Developer][25])



## 9) Troubleshooting (quick checks)

* **Auth fails?** Confirm API token, email, and Basic header. For attachments, include **`X-Atlassian-Token: no-check`**. ([Atlassian Developer][2])
* **Empty search results but UI shows matches?** Check JQL, permissions, and pagination (`startAt`, `maxResults`); some new endpoints (e.g., `/search/jql`) have different response shapes. ([Atlassian Developer][8])
* **Assignee doesn’t change?** Use **`accountId`**; email/username won’t work on Cloud. ([Atlassian Developer][17])
* **Transition fails with field error?** That transition may have a screen—submit required fields in the POST body; transitions are **not** atomic across concurrent calls. ([Atlassian Developer][7])

---

## 10) Appendix — Useful endpoints & docs

* **Platform REST v3 intro + cross‑cutting rules** (auth, pagination, ADF). ([Atlassian Developer][1])
* **Issues / Search / Attachments / Watchers** (v3). ([Atlassian Developer][7])
* **Jira Software REST (boards, sprints, backlog)**. ([Atlassian Developer][12])
* **JQL guide & cheat sheet**. ([Atlassian Support][6])
* **GDPR changes (accountId migration)**. ([Atlassian Developer][17])
* **OAuth 2.0 scopes (3LO)**. ([Atlassian Developer][5])
* **CLI tools:** JiraCLI (FOSS), go‑jira, Appfire ACLI. ([GitHub][20])

---


[1]: https://developer.atlassian.com/cloud/jira/platform/rest/v3/intro/ "Jira Cloud Platform REST API v3 - developer Atlassian."
[2]: https://developer.atlassian.com/cloud/jira/software/basic-auth-for-rest-apis/ "Basic auth for REST APIs"
[3]: https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/ "Manage API tokens for your Atlassian account"
[4]: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-attachments/ "Jira Cloud REST API documentation for adding attachments"
[5]: https://developer.atlassian.com/cloud/jira/platform/scopes-for-oauth-2-3LO-and-forge-apps/ "Jira scopes for OAuth 2.0 (3LO) and Forge apps"
[6]: https://support.atlassian.com/jira-service-management-cloud/docs/use-advanced-search-with-jira-query-language-jql/ "Use advanced search with Jira Query Language (JQL)"
[7]: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/ "Jira Cloud REST API documentation for \"Get issue\""
[8]: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-search/ "The Jira Cloud platform REST API"
[9]: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-link-types/ "The Jira Cloud platform REST API"
[10]: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-watchers/ "Issue watchers - The Jira Cloud platform REST API"
[11]: https://jira.atlassian.com/browse/JRACLOUD-74226 "Cannot create and transition issues using the /rest/api/3/issue/bulk ..."
[12]: https://developer.atlassian.com/cloud/jira/software/rest/ "The Jira Software Cloud REST API"
[13]: https://developer.atlassian.com/cloud/jira/software/rest/api-group-board/ "The Jira Software Cloud REST API"
[14]: https://developer.atlassian.com/cloud/jira/software/rest/api-group-sprint/ "The Jira Software Cloud REST API - Sprint"
[15]: https://community.atlassian.com/forums/Jira-questions/Add-an-issue-to-a-sprint-using-the-rest-API/qaq-p/872813 "Add an issue to a sprint using the rest API - Jira"
[16]: https://developer.atlassian.com/cloud/jira/software/rest/api-group-backlog/ "The Jira Software Cloud REST API - Backlog"
[17]: https://developer.atlassian.com/cloud/jira/platform/deprecation-notice-user-privacy-api-migration-guide/ "REST API migration guide and deprecation notice"
[18]: https://support.atlassian.com/jira/kb/how-to-add-an-attachment-to-a-jira-cloud-issue-using-rest-api/ "How to add an attachment to Jira Cloud work items using ..."
[19]: https://developer.atlassian.com/server/jira/platform/webhooks/ "Webhooks"
[20]: https://github.com/ankitpokhrel/jira-cli "ankitpokhrel/jira-cli: 🔥 Feature-rich interactive ..."
[21]: https://github.com/go-jira/jira "simple jira command line client in Go"
[22]: https://appfire.atlassian.net/wiki/spaces/JCLI/pages/70782663/User%27s%2BGuide "Contents - Jira Command Line Interface (CLI) - Confluence"
[23]: https://community.developer.atlassian.com/t/issue-search-post-call-returns-only-maximum-of-100-results/59668 "Issue search post call returns only maximum of 100 results - Jira Cloud"
[24]: https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/ "Atlassian Document Format"
[25]: https://developer.atlassian.com/cloud/jira/software/webhooks/ "Webhooks - Jira Software Cloud"
