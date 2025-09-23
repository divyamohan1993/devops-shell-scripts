
# Git & GitHub

## Table of Contents

1. [First‑time setup (10 min)](#first-time-setup-10-min)
2. [Create/clone & the working tree triad](#createclone--the-working-tree-triad)
3. [Everyday changes: stage, undo, diff, history](#everyday-changes-stage-undo-diff-history)
4. [Branching & merging safely](#branching--merging-safely)
5. [Remotes, fetch/pull/push, pruning](#remotes-fetchpullpush-pruning)
6. [Rewriting history (responsibly)](#rewriting-history-responsibly)
7. [Search & inspect like a pro](#search--inspect-like-a-pro)
8. [Tags, releases & signing (supply‑chain hygiene)](#tags-releases--signing-supplychain-hygiene)
9. [Large repos & monorepos (LFS, sparse, partial, worktrees)](#large-repos--monorepos-lfs-sparse-partial-worktrees)
10. [Submodules & subtree](#submodules--subtree)
11. [Disaster recovery & repo maintenance](#disaster-recovery--repo-maintenance)
12. [Policies: .gitignore, .gitattributes, hooks & pre‑commit](#policies-gitignore-gitattributes-hooks--precommit)
13. [GitHub daily flow with `gh` CLI](#github-daily-flow-with-gh-cli)
14. [Enterprise guardrails (branch protection, CODEOWNERS, env protections)](#enterprise-guardrails-branch-protection-codeowners-env-protections)
15. [Opinionated aliases (speed boosters)](#opinionated-aliases-speed-boosters)



## First‑time setup (10 min)

> Set your identity and sensible global defaults (default branch name `main`, rebase pulls, prune remotes, credential manager). ([Git SCM][2])

**Set author identity (required once per machine).**

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@company.com"
```

**Make new repos start on `main`.**

```bash
git config --global init.defaultBranch main
```

**Prefer rebase on `git pull` (linear local history).**

```bash
git config --global pull.rebase true
```

**Auto-prune stale remote branches on fetch/pull.**

```bash
git config --global fetch.prune true
```

**Cache/secure credentials (recommended).**

```bash
# Cross‑platform Git Credential Manager
git config --global credential.helper manager-core
# or ephemeral cache (seconds)
git config --global credential.helper "cache --timeout=3600"
```

> GCM is a secure helper that stores tokens and supports 2FA; `cache` keeps creds in memory only for a timeout. ([GitHub Docs][3])



## Create/clone & the working tree triad

> The working tree has **Untracked → Staged (index) → Committed** states; `status`, `add`, `commit` are your daily loop. ([Git SCM][4])

**Initialize a new repo (current folder).**

```bash
git init
```

**Clone an existing repo.**

```bash
git clone https://github.com/OWNER/REPO.git
```

**Check where you stand.**

```bash
git status
```

**Stage file(s) / stage everything modified.**

```bash
git add path/to/file
git add -A
```

**Commit with message (signed off optional).**

```bash
git commit -m "feat: initial commit"
```

**Show commit history (pretty graph).**

```bash
git log --oneline --graph --decorate --all
```

> `git log` shows commit history; `--graph --decorate` improves context. ([Git SCM][5])



## Everyday changes: stage, undo, diff, history

**See what changed vs index / last commit.**

```bash
git diff           # working tree vs index
git diff --staged  # index vs HEAD
```

**Unstage a file (keep changes).**

```bash
git restore --staged path/to/file
```

> `git restore` and `git switch` are modern, focused alternatives to some `checkout` usages. ([GitHub Docs][6])

**Discard local changes to a file (dangerous).**

```bash
git restore --worktree --source=HEAD path/to/file
```

**Amend last commit message (no new commit).**

```bash
git commit --amend -m "refactor: clearer message"
```

**Create a lightweight tag for the current commit.**

```bash
git tag v0.1.0
```

**Show a single commit (diff + metadata).**

```bash
git show <commit>
```



## Branching & merging safely

> Branch to isolate work; merge integrates; rebase replays your commits atop a new base for linear history. ([Git SCM][7])

**Create and switch to a branch.**

```bash
git switch -c feature/login
```

**Switch back to `main`.**

```bash
git switch main
```

**Merge a completed feature into current branch.**

```bash
git merge --no-ff feature/login
```

**Rebase your feature on latest `main` (local cleanup).**

```bash
git fetch origin
git rebase origin/main
```

**Abort or continue an in‑progress rebase.**

```bash
git rebase --abort
git rebase --continue
```

**Temporarily stash uncommitted work; reapply later.**

```bash
git stash push -m "wip: shelve changes"
git stash list
git stash pop
```

> Stash shelves work-in-progress without committing; helpful before rebases or hotfix pulls. ([Git SCM][8])



## Remotes, fetch/pull/push, pruning

> Remotes point to servers (e.g., GitHub). `fetch` updates remote tracking; `pull` = fetch+merge/rebase; `push` publishes. ([Git SCM][9])

**Add a remote & verify.**

```bash
git remote add origin git@github.com:OWNER/REPO.git
git remote -v
```

**Fetch remote updates (with prune).**

```bash
git fetch --prune
```

> `--prune` cleans up deleted remote branches locally; `--prune-tags` for tags. ([Git SCM][10])

**Set upstream and push for the first time.**

```bash
git push -u origin feature/login
```

**Pull with rebase (matches our global default).**

```bash
git pull --rebase
```

**Update remote URL (HTTPS ↔ SSH).**

```bash
git remote set-url origin git@github.com:OWNER/REPO.git
```



## Rewriting history (responsibly)

> Use history rewrites only on **unshared** branches, and if you must force‑push, prefer `--force-with-lease` to avoid clobbering teammates. ([Git SCM][11])

**Correct the last commit without changing content.**

```bash
git commit --amend --no-edit
```

**Interactive rebase (squash/fixup multiple commits).**

```bash
git rebase -i HEAD~5
# then mark commits as 's' or use:
git commit --fixup <sha>
git rebase -i --autosquash HEAD~5
```

> Autosquash pairs `--fixup/--squash` commits with their targets automatically. ([Git SCM][12])

**Safest force push.**

```bash
git push --force-with-lease
```

> `--force-with-lease` refuses to overwrite remote work you don’t have locally. ([Git SCM][11])

**Undo a pushed commit (preserve history).**

```bash
git revert <sha>
```



## Search & inspect like a pro

**Search tracked content (fast).**

```bash
git grep -n "TODO"               # across tracked files
git grep -n --cached "API_KEY"   # in index
```

> `git grep` searches tracked files, index, or trees—faster than plain `grep` on large repos. ([Git SCM][13])

**Find commits that added/removed a string or regex.**

```bash
git log -S"function foo" --patch   # string added/removed
git log -G"^class .*Controller"    # regex
```

**Summarize authors for a release (changelog helper).**

```bash
git shortlog -sn v1.2.0..HEAD
```

> `git shortlog` groups by author—great for release notes. ([Git SCM][14])

**Describe current commit by nearest tag (useful in builds).**

```bash
git describe --tags --always --dirty
```

> `git describe` prints the closest reachable tag + distance. ([Git SCM][15])

**Blame while ignoring mass‑format commits.**

```bash
echo a1b2c3... > .git-blame-ignore-revs
git config blame.ignoreRevsFile .git-blame-ignore-revs
git blame -- . | less
```

> `--ignore-revs-file` removes noise from blame due to reformatting. ([Git SCM][8])



## Tags, releases & signing (supply‑chain hygiene)

> Sign commits/tags with GPG or SSH so GitHub shows **Verified**; use annotated tags for releases and publish them on GitHub. ([GitHub Docs][16])

**Create signed (annotated) tag & push.**

```bash
git tag -s v1.3.0 -m "v1.3.0"
git push origin v1.3.0
```

**Enable commit signing by default (GPG shown).**

```bash
git config --global commit.gpgsign true
git config --global user.signingkey <GPG_KEY_ID>
```

> GitHub verifies GPG/SSH/S/MIME signatures and marks them Verified. ([GitHub Docs][17])

**Verify a signed tag locally.**

```bash
git verify-tag v1.3.0
```

> `git verify-tag` checks the tag’s signature. ([Git SCM][18])



## Large repos & monorepos (LFS, sparse, partial, worktrees)

**Track large binaries with Git LFS.**

```bash
# one-time setup per machine (then re-open shell)
git lfs install
# track file patterns and commit the .gitattributes update
git lfs track "*.psd"
git add .gitattributes && git commit -m "chore(lfs): track psd"
```

> Git LFS stores large files outside normal Git history; install & track patterns, then push. ([GitHub Docs][19])

**Sparse checkout (only parts of a monorepo).**

```bash
git clone --filter=blob:none --sparse git@github.com:ORG/BIGREPO.git
cd BIGREPO
git sparse-checkout set services/api services/web
```

> `sparse-checkout` limits files in your working tree; `--filter=blob:none` defers blobs (partial clone). ([Git SCM][20])

**Partial clone of a heavy repo (CI & dev speedup).**

```bash
git clone --filter=blob:none https://github.com/ORG/REPO.git
```

> Blobless clones fetch file contents on demand; ideal for large histories. ([The GitHub Blog][21])

**Parallel work with multiple worktrees.**

```bash
git worktree add ../REPO-fix fix/urgent
git worktree list
git worktree remove ../REPO-fix
```

> `git worktree` lets you check out multiple branches into separate folders simultaneously. ([Git SCM][22])



## Submodules & subtree

**Add a submodule (pinned external repo).**

```bash
git submodule add https://github.com/ORG/LIB.git libs/LIB
git submodule update --init --recursive
```

> Submodules pin another repo at a specific commit via `.gitmodules`. ([Git SCM][23])

**Using `git subtree` (alternative to submodules).**

```bash
git subtree add --prefix=vendor/LIB https://github.com/ORG/LIB.git main --squash
git subtree pull --prefix=vendor/LIB https://github.com/ORG/LIB.git main --squash
```

> `git subtree` embeds external code as a subdirectory and can pull/split; it’s shipped in Git’s contrib/manpages on many platforms. ([Debian Manpages][24])



## Disaster recovery & repo maintenance

**Recover “lost” commits with reflog.**

```bash
git reflog
git reset --hard HEAD@{1}   # example: go back one HEAD move
```

> Reflog records where branch tips were; `HEAD@{1}` means “previous HEAD.” ([Git SCM][25])

**Clean untracked files (dry‑run first!).**

```bash
git clean -fdxn   # dry-run
git clean -fdx    # remove untracked + ignores
```

> `git clean` removes untracked files/dirs; `-x` also removes ignored files. ([Git SCM][26])

**Garbage-collect & maintain (performance).**

```bash
git gc --prune=now
git maintenance run --task=incremental-repack
```

> `git gc` prunes unreachable objects; `git maintenance` provides scheduled/targeted upkeep. ([Git SCM][27])

**Integrity check.**

```bash
git fsck --full
```

> `git fsck` validates object graph and reports corruption. ([Kernel.org][28])



## Policies: .gitignore, .gitattributes, hooks & pre‑commit

**Ignore build artifacts & secrets.**

```bash
# create project .gitignore
printf '%s\n' 'dist/' '.env' '*.log' '.DS_Store' >> .gitignore
git add .gitignore && git commit -m "chore: add .gitignore"
```

> `.gitignore` controls untracked files that Git should ignore. ([Git SCM][29])

**Normalize line endings across OSes (avoid CRLF issues).**

```bash
# .gitattributes in repo root:
printf '%s\n' '* text=auto' '*.sh text eol=lf' >> .gitattributes
git add .gitattributes && git commit -m "chore: normalize EOLs"
```

> Use `.gitattributes` for EOL normalization; `core.autocrlf` may also be configured per OS/team policy. ([Git SCM][30])

**Centralize hooks & run policy checks before commit.**

```bash
# point Git to a shared hooks dir
git config core.hooksPath .githooks
mkdir -p .githooks && printf '#!/usr/bin/env bash\nexec pre-commit run --all-files\n' > .githooks/pre-commit
chmod +x .githooks/pre-commit

# adopt the pre-commit framework
pipx install pre-commit || pip install pre-commit
pre-commit sample-config > .pre-commit-config.yaml
pre-commit install
```

> `core.hooksPath` sets a repo‑controlled hooks directory; `pre-commit` manages multi‑language hooks for formatting, linting, secret scans. ([Git SCM][31])



## GitHub daily flow with `gh` CLI

> Authenticate once, then open PRs, review, check CI, and release—all from your terminal. ([GitHub CLI][32])

**Login & wire `git` to `gh`.**

```bash
gh auth login          # interactive browser flow
gh auth status
gh auth setup-git
```

> `gh auth` stores tokens securely (uses system credential store when available). ([GitHub CLI][33])

**Create a repo (empty or from existing folder).**

```bash
gh repo create my-service --private --clone
# or from existing dir:
gh repo create --private --source=. --push
```

> `gh repo create` scaffolds a GitHub repo; `--clone` to get a local copy. ([GitHub CLI][34])

**Fork & keep upstream remote.**

```bash
gh repo fork OWNER/REPO --clone
```

> `gh repo fork` creates your fork and can clone it locally. ([GitHub CLI][35])

**Open a pull request from current branch.**

```bash
gh pr create --base main --fill --draft
gh pr view --web
```

> Create, view, and manage PRs from CLI. ([GitHub CLI][36])

**Check PR CI & status; review & merge.**

```bash
gh pr status
gh pr checks   # show CI state
gh pr review --approve --body "LGTM"
gh pr merge --squash --delete-branch
```

> `gh pr status/checks/review/merge` cover end‑to‑end PR flow; merge obeys branch rules/queues. ([GitHub CLI][37])

**Cut a GitHub Release from a tag.**

```bash
git tag -a v1.4.0 -m "v1.4.0"
git push origin v1.4.0
gh release create v1.4.0 --notes-from-tag
```

> `gh release create` turns tags into Releases and can pull notes from the tag. ([GitHub CLI][38])



## Enterprise guardrails (branch protection, CODEOWNERS, env protections)

> Use **protected branches** with required checks, reviews, signed commits, and linear history; **CODEOWNERS** auto‑requests reviewers; **Actions environments** gate deployments. ([GitHub Docs][39])

**Add a CODEOWNERS file (auto‑request reviewers).**

```bash
# .github/CODEOWNERS
# app code requires Core and Sec teams
/apps/**   @org/core-team @org/security-team
```

> CODEOWNERS must exist on the PR’s base branch to request owners automatically. ([GitHub Docs][40])

**(API) Enforce linear history & required reviews/checks.**

```bash
# Example: enable linear history via REST
gh api -X PUT repos/OWNER/REPO/branches/main/protection \
  -F required_linear_history=true \
  -F required_status_checks.strict=true \
  -F enforce_admins=true
```

> Branch protection supports linear history and required checks/reviews; the REST surface exposes all toggles. ([GitHub Docs][41])

**Actions environments with manual approvals / protection rules.**

```yaml
# .github/workflows/deploy.yml
name: Deploy
on: workflow_dispatch
jobs:
  deploy:
    environment: production   # can have reviewers/approvals
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./deploy.sh
```

> Environments add secrets and deployment protection (e.g., approvals, external gates). ([GitHub Docs][42])



## Opinionated aliases (speed boosters)

**Add handy log/graph & safety aliases.**

```bash
git config --global alias.st "status -sb"
git config --global alias.co "switch"
git config --global alias.cob "switch -c"
git config --global alias.undo "reset --soft HEAD~1"
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.ff "merge --ff-only"
git config --global alias.rb "rebase -i --autosquash"
```



# Appendix — Advanced Topics & “Senior” Playbook

### 1) Fix a bad reset or rebase (using reflog)

* **Find where HEAD was, then hard reset back.**

  ```bash
  git reflog
  git reset --hard HEAD@{2}
  ```

  > Reflog gives “time travel” to previous tips like `HEAD@{n}`. ([Git SCM][25])

### 2) Clean history after secret leaks / big files

* **Preferred tool: `git filter-repo` (fast, safer than filter-branch).**

  ```bash
  pipx install git-filter-repo || brew install git-filter-repo
  git filter-repo --path secrets.env --invert-paths --force
  git push --force --all && git push --force --tags
  ```

  > `git filter-repo` is the Git‑project‑recommended replacement for `filter-branch`. ([Git SCM][43])

* **Alternative (simple cases): BFG Repo‑Cleaner.**

  ```bash
  bfg --delete-files secrets.env  # run on a --mirror clone
  ```

  > BFG is a simpler, fast cleaner for large files and secrets. ([rtyley.github.io][44])

### 3) Disaster cleanups & housekeeping

* **Remove untracked build outputs now; prune unreachable objects; repack.**

  ```bash
  git clean -fdx
  git gc --prune=now
  git maintenance run --task=incremental-repack
  ```

  > `git gc`/`maintenance` tidy object storage for performance. ([Git SCM][27])

### 4) Power features for huge repos

* **Sparse checkout “cone mode” for specific folders only.**

  ```bash
  git sparse-checkout set backend/ services/payments
  ```

  > Sparse checkout reduces working files; pair with partial clone to speed clones. ([Git SCM][20])

* **Multiple concurrent branches with worktrees.**

  ```bash
  git worktree add ../hotfix hotfix/payment-null
  ```

  > No need to stash or commit WIP—use another worktree folder. ([Git SCM][22])

### 5) “Last‑mile” collaboration

* **Bisect to find the first bad commit (binary search).**

  ```bash
  git bisect start
  git bisect bad
  git bisect good v1.3.0
  # test... then:
  git bisect reset
  ```

  > `git bisect` pinpoints the introducing commit via binary search. ([Git SCM][45])

* **Cherry‑pick a specific fix onto a release branch.**

  ```bash
  git switch release/1.4
  git cherry-pick <sha>
  ```

  > `git cherry-pick` reapplies the change as a new commit. ([Git SCM][46])



## Quick GitHub “day in the life” (scriptable)

**1) Create branch, push, open PR, run checks, get it merged.**

```bash
git switch -c feat/audit-logs
# ...edit...
git add -A && git commit -m "feat(audit): initial schema"
git push -u origin HEAD
gh pr create --base main --fill
gh pr checks --watch
gh pr review --approve --body "✅"
gh pr merge --squash --delete-branch
```

> `gh pr checks --watch` tails CI; `merge` respects branch rules/merge queues. ([GitHub CLI][47])

**2) Release cut from tag (notes auto‑derived).**

```bash
git tag -a v2.0.0 -m "v2.0.0"
git push origin v2.0.0
gh release create v2.0.0 --notes-from-tag
```

> Turn tags into GitHub Releases with generated notes. ([GitHub CLI][38])

**3) Watch a workflow run finish.**

```bash
gh run list | head
gh run watch <run-id> --exit-status
```

> `gh run watch` follows Actions progress and exits non‑zero if it fails. ([GitHub CLI][48])

---

## Appendix: Reference & Further Reading

* Git docs (command manual & book): `git help <cmd>`; online docs for each command referenced above. ([Git SCM][49])
* Selected manpages: `git-rebase`, `git-pull`, `git-fetch`, `git-gc`, `git-maintenance`, `git-reflog`, `git-sparse-checkout`, `git-worktree`, `git-submodule`. ([Git SCM][7])
* GitHub CLI manual top & PR/Issues/Releases subcommands. ([GitHub CLI][32])
* Branch protection, CODEOWNERS, environment protections. ([GitHub Docs][50])
* LFS, partial clone, sparse checkout. ([GitHub Docs][19])

---

### How to use this README

1. **Start at the top** and actually run the commands in sequence in your own sandbox repo.
2. **Enable guardrails early** (git config + .gitignore + .gitattributes + signed commits).
3. **Adopt PR discipline** with `gh` (create → checks → review → merge).
4. **Level up** with sparse, partial clone, worktrees for larger codebases.
5. **Keep things healthy** (reflog recovery, clean/gc/maintenance, protection rules).


[1]: https://docs.github.com/en/get-started/using-git/about-git "About Git"
[2]: https://git-scm.com/book/ms/v2/Getting-Started-First-Time-Git-Setup "1.6 Getting Started - First-Time Git Setup"
[3]: https://docs.github.com/en/get-started/git-basics/caching-your-github-credentials-in-git "Caching your GitHub credentials in Git"
[4]: https://git-scm.com/docs/gittutorial/2.2.3 "Git - gittutorial Documentation"
[5]: https://git-scm.com/docs/git-log "Git - git-log Documentation"
[6]: https://docs.github.com/en/code-security/dependabot/dependabot-security-updates/about-dependabot-security-updates "About Dependabot security updates"
[7]: https://git-scm.com/docs/git-rebase "Git - git-rebase Documentation"
[8]: https://git-scm.com/docs/git-blame "Git - git-blame Documentation"
[9]: https://git-scm.com/docs/git-pull "Git - git-pull Documentation"
[10]: https://git-scm.com/docs/git-fetch "Git - git-fetch Documentation"
[11]: https://git-scm.com/docs/git-push "Git - git-push Documentation"
[12]: https://git-scm.com/docs/git-range-diff "Git - git-range-diff Documentation"
[13]: https://git-scm.com/docs/git-grep "Git - git-grep Documentation"
[14]: https://git-scm.com/docs/git-shortlog "Git - git-shortlog Documentation"
[15]: https://git-scm.com/docs/git-describe "Git - git-describe Documentation"
[16]: https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification "About commit signature verification - GitHub Docs"
[17]: https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits "Signing commits - GitHub Docs"
[18]: https://git-scm.com/docs/git-verify-tag "git-verify-tag Documentation - Git"
[19]: https://docs.github.com/en/repositories/working-with-files/managing-large-files/installing-git-large-file-storage "Installing Git Large File Storage"
[20]: https://git-scm.com/docs/git-sparse-checkout "git-sparse-checkout Documentation"
[21]: https://github.blog/open-source/git/get-up-to-speed-with-partial-clone-and-shallow-clone/ "Get up to speed with partial clone and shallow clone"
[22]: https://git-scm.com/docs/git-worktree "Git - git-worktree Documentation"
[23]: https://git-scm.com/docs/git-submodule "git-submodule Documentation - Git"
[24]: https://manpages.debian.org/testing/git-man/git-subtree.1.en.html "git-subtree(1) — git-man — Debian testing"
[25]: https://git-scm.com/docs/git-reflog "Git - git-reflog Documentation"
[26]: https://git-scm.com/docs/git-config "Git - git-config Documentation"
[27]: https://git-scm.com/docs/git-prune "Git - git-prune Documentation"
[28]: https://www.kernel.org/pub/software/scm/git/docs/git-fsck.html "git-fsck(1)"
[29]: https://git-scm.com/docs/gitignore "gitignore Documentation"
[30]: https://git-scm.com/docs/git-clean "Git - git-clean Documentation"
[31]: https://git-scm.com/docs/githooks "githooks Documentation - Git"
[32]: https://cli.github.com/manual/ "GitHub CLI manual"
[33]: https://cli.github.com/manual/gh_auth_login "gh auth login"
[34]: https://cli.github.com/manual/gh_repo_create "gh repo create"
[35]: https://cli.github.com/manual/gh_repo_fork "gh repo fork"
[36]: https://cli.github.com/manual/gh_pr_create "gh pr create"
[37]: https://cli.github.com/manual/gh_pr_status "gh pr status - GitHub CLI"
[38]: https://cli.github.com/manual/gh_release_create "gh release create"
[39]: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule "Managing a branch protection rule"
[40]: https://docs.github.com/articles/about-code-owners "About code owners"
[41]: https://docs.github.com/en/rest/branches/branch-protection "REST API endpoints for protected branches"
[42]: https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment "Managing environments for deployment"
[43]: https://git-scm.com/docs/git-filter-branch "Git - git-filter-branch Documentation"
[44]: https://rtyley.github.io/bfg-repo-cleaner/ "BFG Repo-Cleaner by rtyley - GitHub Pages"
[45]: https://git-scm.com/docs/git-bisect "Git - git-bisect Documentation"
[46]: https://git-scm.com/docs/git-cherry-pick "Git - git-cherry-pick Documentation"
[47]: https://cli.github.com/manual/gh_pr_checks "gh pr checks - GitHub CLI"
[48]: https://cli.github.com/manual/gh_run_watch "gh run watch"
[49]: https://git-scm.com/docs/git "git Documentation - Git"
[50]: https://docs.github.com/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches "About protected branches"
