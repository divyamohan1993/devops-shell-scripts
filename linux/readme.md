# Bash

> A practical, example‑first guide to the Bash shell on Linux. Start at the top with one‑liners, then graduate to production‑grade, scriptable patterns used daily by senior engineers.

> **Conventions**
>
> * Commands that may require privileges show `sudo` (learn/validate `sudo` with `sudo -v`, and always edit `/etc/sudoers` via `visudo`).
> * When in doubt, **read the man page**: `man <cmd>` (or try `tldr <cmd>` for examples). Sections like `(1)`, `(5)`, `(8)` indicate command/user docs, file formats, admin tools respectively.
> * Bash features (redirection, expansions, arrays, traps, `set -o ...`) come from the **GNU Bash Reference Manual**. Use it to go deeper.

---

## Part A — 120 Daily One‑Liners (grouped by topic)

> Each item: a one‑liner you can paste and run. Follow them in order; they build up naturally.

### 0) Help & orientation

1. **What shell and version am I in?**
   `echo "$BASH" ; echo "$BASH_VERSION"`  — sanity check.

2. **Read docs for any command** (system pager).
   `man ls`  — open the manual; use `/` to search, `q` to quit.

3. **Example‑driven docs (TL;DR)**
   `tldr find`  — concise examples (install a tldr client first).

4. **Bash builtins help**
   `help set`  — builtins are documented by Bash itself.

5. **Know your Linux** (kernel, OS, hostname)
   `uname -a ; cat /etc/os-release ; hostnamectl status`  — quick system facts.

---

### 1) Files & directories (the absolute basics)

6. **Where am I?**
   `pwd`

7. **List files (long, human sizes, hidden)**
   `ls -lah`  — long view, dotfiles shown, human-readable sizes.

8. **Change directories**
   `cd /var/log`  — to a path; `cd -` toggles last directory.

9. **Create directories recursively**
   `mkdir -p projects/acme/api`

10. **Create or update timestamps**
    `touch notes.txt`

11. **Copy (archive mode, verbose)**
    `cp -av src/ dest/`  — preserves attrs where possible.

12. **Move/rename (interactive)**
    `mv -iv old.txt new.txt`

13. **Remove (prompt before each)**
    `rm -i file1 file2`

14. **Remove empty dir**
    `rmdir emptydir`

15. **Symlink (soft link)**
    `ln -s /opt/app/current /usr/local/bin/app`

16. **Find files by name**
    `find . -type f -name '*.log' -maxdepth 2`

17. **Find & delete files older than 7 days**
    `find /var/log -type f -mtime +7 -delete`  — be careful with paths.

18. **Find big files (>100MB)**
    `find . -type f -size +100M -printf '%s %p\n' | sort -nr | head`

19. **Safer piping of filenames** (NUL‑delimited)
    `find . -type f -print0 | xargs -0 -I{} echo processing: {}`  — correct for spaces/newlines.

20. **Locate files via database**
    `locate sshd_config`  — after `updatedb` (package varies).

21. **File metadata**
    `stat my.log`  — inode, perms, times.

22. **Show file type (magic)**
    `file app.bin`  — what is it? ELF? text?

23. **Disk usage (by filesystem)**
    `df -h`  — mounted filesystems free/used.

24. **Disk usage (by directory)**
    `du -sh * | sort -h`  — who’s using space?

25. **List block devices**
    `lsblk -f`  — filesystems, UUIDs.

26. **Show block device IDs**
    `blkid`  — UUIDs/labels; useful for fstab.

27. **Show mounts**
    `mount | column -t` and `findmnt`  — see what’s mounted.

28. **Make a directory tree snapshot**
    `tree -a -L 2`  — if `tree` installed.

---

### 2) Viewing & searching text

29. **Page through a file**
    `less /var/log/syslog`  — PgUp/PgDn, `/pattern`, `G`, `F`.

30. **Head/tail**
    `head -n 50 access.log ; tail -n 50 access.log`  — first/last lines.

31. **Follow logs in real time**
    `tail -f /var/log/messages`  — live feed.

32. **Count lines/words/bytes**
    `wc -l error.log`

33. **Search text recursively**
    `grep -RIn --color 'ERROR|WARN' .`  — regex, show line numbers.

34. **Extract only matches**
    `grep -Eo 'https?://[^ ]+' page.html`

35. **Filter columns (CSV)**
    `cut -d, -f1,3 sales.csv`

36. **Translate chars / delete**
    `tr -d '\r' < file | tr '[:lower:]' '[:upper:]'`

37. **Sort (human numeric, unique)**
    `sort -h sizes.txt | uniq -c`  — group duplicates.

38. **Join two files by key**
    `join -t, -1 1 -2 1 a.csv b.csv`  — tabular joins.

39. **Paste columns side‑by‑side**
    `paste -d, a.txt b.txt`

40. **Sed replace (in‑place, backup)**
    `sed -i.bak 's/foo/bar/g' config.ini`  — writes `*.bak`.

41. **Print lines matching a pattern**
    `sed -n '/timeout=/p' /etc/ssh/sshd_config`

42. **Quick field extraction with awk**
    `awk -F: '{print $1,$3}' /etc/passwd`  — user and UID.

43. **Sum a column with awk**
    `awk -F, '{s+=$3} END{print s}' sales.csv`

44. **Diff two files (unified)**
    `diff -u old.conf new.conf`

45. **Generate a patch**
    `diff -u file.old file.new > change.patch`

46. **Apply a patch**
    `patch -p1 < change.patch`

---

### 3) Permissions, users & groups

47. **Make a script executable**
    `chmod +x deploy.sh`  — grant execute bit.

48. **Set exact mode (octal)**
    `chmod 640 secrets.txt`  — `rw-r-----`.

49. **Change owner/group**
    `sudo chown alice:developers app/ -R`

50. **Default permission mask**
    `umask 022` — new files default perms.

51. **Identify current user/group**
    `id ; groups`

52. **Add a user**
    `sudo useradd -m -s /bin/bash alice`

53. **Add to a group**
    `sudo usermod -aG sudo alice`  — append to groups.

54. **Set / change password**
    `sudo passwd alice`

55. **Create a group**
    `sudo groupadd developers`

56. **Elevate with sudo (list rules)**
    `sudo -l`  — see what you can do. Edit with `sudo visudo`.

---

### 4) Processes & job control

57. **List processes**
    `ps aux | less`  — all users + full format.

58. **Top (interactive)**
    `top` — CPU/mem live. (Try `htop` if installed.)

59. **Find PIDs by name**
    `pgrep -fl nginx`  — with names.

60. **Send a signal by name**
    `pkill -TERM -f myapp`  — prefer graceful TERM over -9.

61. **Kill a specific PID**
    `kill -TERM 12345`  — fall back to `-KILL` as last resort.

62. **Find who’s using a file/port**
    `lsof /var/log/syslog ; sudo lsof -i :443`  — open files / sockets.

63. **What process has this file open?**
    `fuser -v /var/log/syslog`  — shows PIDs.

64. **Background jobs**
    `sleep 600 & ; jobs ; fg %1 ; bg %1 ; disown %1`  — job control. (Shell builtins.)

65. **Keep job running after logout**
    `nohup long_task.sh &`  — logs to `nohup.out`.

66. **Run a command and time it**
    `/usr/bin/time -v make`  — resource usage.

67. **Repeat a command**
    `watch -n 2 'systemctl is-active nginx'`

---

### 5) Systemd services & logs

68. **Status of a service**
    `systemctl status nginx`

69. **Start/stop/restart**
    `sudo systemctl start nginx ; sudo systemctl restart nginx`

70. **Enable at boot**
    `sudo systemctl enable --now nginx`

71. **Tail logs from journald**
    `journalctl -u nginx -f`  — live logs by unit.

72. **Filter logs by priority/time**
    `journalctl -p err -S "2025-09-01" -U "2025-09-22"`

73. **List all service unit files**
    `systemctl list-unit-files --type=service`

---

### 6) Networking & troubleshooting

74. **IP addresses & links**
    `ip -br a ; ip -br link` — brief view.

75. **Routing table**
    `ip route`  — active routes.

76. **Who’s listening**
    `ss -tulpen` — TCP/UDP listening sockets + processes.

77. **Ping a host**
    `ping -c 4 example.com`  — quick reachability.

78. **Trace route to a host**
    `traceroute example.com`  — path across network.

79. **DNS lookup (A/AAAA)**
    `dig +short example.com A AAAA`

80. **Quick HTTP header check**
    `curl -I https://example.com`  — HEAD request.

81. **Download a file (resume)**
    `wget -c https://host/file.iso`

82. **Test a TCP port**
    `nc -zv host 443` — see if port reachable.

83. **ARP ping on a LAN**
    `arping -c 3 192.168.1.10`  — layer‑2 probe.

84. **Firewall (Ubuntu UFW) basics**
    `sudo ufw allow 22/tcp ; sudo ufw enable ; sudo ufw status verbose`

85. **Firewall (RHEL firewalld)**
    `sudo firewall-cmd --add-service=ssh --permanent && sudo firewall-cmd --reload && sudo firewall-cmd --list-all`

---

### 7) Archiving & compression

86. **Create a tar.gz archive**
    `tar -czf logs.tgz /var/log/nginx`  — create + gzip.

87. **List contents of a tar**
    `tar -tf logs.tgz`

88. **Extract a tar.gz**
    `tar -xzf logs.tgz -C /tmp`

89. **Zip / unzip**
    `zip -r backup.zip data/ ; unzip backup.zip`

90. **Gzip / gunzip a file**
    `gzip -9 huge.log ; gunzip huge.log.gz`

91. **bzip2 / bunzip2**
    `bzip2 file ; bunzip2 file.bz2` — better compression than gzip (slower).

92. **xz / unxz**
    `xz -T0 bigfile ; unxz bigfile.xz` — strong compression.

---

### 8) Packages (multi‑distro quickies)

> Use the ones that match your distro family.

93. **Debian/Ubuntu**
    `sudo apt update && sudo apt install -y curl` — install.

94. **RHEL/Fedora**
    `sudo dnf install -y curl`  — newer RHEL/Fedora. (On older, `yum`.)

95. **Arch**
    `sudo pacman -Syu curl`  — sync & upgrade.

96. **SUSE**
    `sudo zypper install curl`

---

### 9) SSH & file copy

97. **SSH to a host**
    `ssh user@server` — first run adds host key (confirm fingerprint).

98. **SSH via bastion (ProxyJump)**
    `ssh -J jumphost user@target`  — chain through a jump host.

99. **Copy your public key to a server**
    `ssh-copy-id user@server` — enables key‑based login.

100. **Start an agent & add a key**
     `eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519`

101. **Copy files with scp**
     `scp -r ./dist user@server:/opt/app/`

102. **Fast, resumable copy with rsync**
     `rsync -aP ./data/ user@server:/data/` — archive, progress.

---

### 10) System info & scheduling

103. **Memory / uptime**
     `free -h ; uptime`

104. **Kernel, distro again (script use)**
     `source /etc/os-release ; echo "$NAME $VERSION_ID"`

105. **Time & timezone**
     `timedatectl status`  — system clock/timezone.

106. **Set hostname**
     `sudo hostnamectl set-hostname web01`

107. **List logins**
     `who ; last | head` — current & recent sessions.

108. **Schedule a job (cron)**
     `crontab -e`  — edit; `crontab -l` to list jobs.

109. **One‑time job (at)**
     `echo 'echo hello > /tmp/hi' | at now+1 minute` — run later.

---

### 11) Bash‑specific power tools

110. **Set strict/safe mode for interactive tasks**
     `set -Eeuo pipefail` — fail early, propagate pipeline failures.

111. **Preview commands as they run**
     `set -x ; yourcmd ; set +x` — debug tracing.

112. **Redirect output & errors**
     `mycmd >out.log 2>&1` — combine stdout/stderr.

113. **Pipes + tee to log and screen**
     `grep -R error . | tee errors.txt`

114. **Brace expansion**
     `mkdir -p /tmp/{dev,stage,prod}/logs` — expands to three paths.

115. **Process substitution (compare outputs)**
     `diff <(sort a.txt) <(sort b.txt)` — no temp files.

116. **Parameter expansion with defaults**
     `echo "${REGION:-us-east-1}"` — default if unset.

117. **Arrays (Bash)**
     `arr=(a b c) ; printf '%s\n' "${arr[@]}"` — iterate safely.

118. **Associative arrays**
     `declare -A kv=([env]=prod [tier]=3) ; echo "${kv[env]}"`

119. **History search**
     `history | grep ssh` — browse recent commands.

120. **Lint your scripts**
     `shellcheck deploy.sh` — catch bugs & bad patterns.

> **Notes & refs:** General user commands (`man`), sections, and paging via `less` are standard; Bash features are from the Bash manual (expansions, redirections, arrays, `set`, etc.). Searching and processing tools (grep/cut/sort/uniq/tr) are in GNU utilities.

---

## Part B — 30 Scripted, Real‑World Patterns (production‑grade)

> Drop these into `.sh` files. Each pattern is battle‑tested for daily enterprise use.

> **Safety defaults**: Start scripts with `#!/usr/bin/env bash` and **strict mode**:
> `set -Eeuo pipefail` to stop on errors, use unset variables as errors, and fail pipelines if any command fails. Then add a **trap** to clean up on exit/signals.

1. **Script skeleton with safe‑defaults + cleanup**

   ```bash
   #!/usr/bin/env bash
   set -Eeuo pipefail
   trap 'rc=$?; echo "[cleanup] rc=$rc"; rm -f /tmp/mytmp.$$; exit $rc' EXIT INT TERM
   tmp=/tmp/mytmp.$$
   echo "Work..." >"$tmp"
   # ...do work...
   ```

   *Why*: consistent error handling & cleanup on normal exit or Ctrl‑C.

2. **Logging helpers with levels**

   ```bash
   log(){ printf '%(%Y-%m-%dT%H:%M:%S%z)T [%s] %s\n' -1 "$1" "$2" >&2; }
   info(){ log INFO "$*"; } warn(){ log WARN "$*"; } err(){ log ERROR "$*"; }
   info "deploy starting"
   ```

3. **Read a `.env` file (key=value)**

   ```bash
   set -a
   [ -f .env ] && . ./.env
   set +a
   : "${REGION:?REGION required}"
   ```

4. **Retry with backoff**

   ```bash
   try() { local n=0; local max=5; local delay=2; 
     until "$@"; do ((n++)); if (( n>=max )); then return 1; fi; sleep $((delay**n)); done; }
   try curl -fsS https://example.com/health
   ```

5. **Timeout a flaky command**

   ```bash
   timeout 30s ./long_running_task.sh
   case $? in 124) err "timed out";; 0) info ok;; *) err "failed";; esac
   ```

   *Note*: `timeout` exits `124` on timeout by default.

6. **Process substitution to diff queries**

   ```bash
   diff <(ps aux | sort) <(ps aux | sort)
   ```

   *Why*: compare snapshots without temporary files.

7. **Parallel file operations safely (NUL‑delimited)**

   ```bash
   find ./media -type f -name '*.jpg' -print0 | xargs -0 -P4 -I{} sh -c 'echo "processing {}"'
   ```

   *Why*: handles spaces/newlines; `-P4` parallelism.

8. **Find & act with `-exec … +` (batched)**

   ```bash
   find logs -type f -name '*.gz' -mtime +14 -exec rm -v {} +
   ```

   *Why*: efficient batching via `+`.

9. **Zero‑downtime config writes (atomic)**

   ```bash
   tmp=$(mktemp)
   cat >"$tmp" <<EOF
   key=value
   EOF
   install -m 0640 -o root -g app "$tmp" /etc/myapp/config.ini
   ```

10. **Capture and tee output (both file and console)**

    ```bash
    { ./run-tests.sh 2>&1 | tee /var/log/tests.log; } || err "tests failed"
    ```

11. **Structured log slicing with `awk`**

    ```bash
    awk '$9 ~ /^5../ {c[$7]++} END{for (k in c) printf "%7s %s\n", c[k], k}' access.log | sort -nr
    ```

    *Why*: top endpoints returning 5xx.

12. **Inline, safe `sed` edits with backup**

    ```bash
    sed -i.bak 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && systemctl reload sshd
    ```

13. **Robust while‑read loop (no mangling)**

    ```bash
    while IFS= read -r line; do
      printf '-> %s\n' "$line"
    done < input.txt
    ```

14. **Use `jq` to validate & extract JSON**

    ```bash
    curl -fsS https://api.example.com/items | jq -e '.items[] | {id,price}' >/tmp/items.json
    ```

    *Why*: `-e` makes jq fail on errors for pipelines.

15. **Compare two live command outputs**

    ```bash
    diff <(curl -fsS https://api/v1/users | jq '.|length') <(curl -fsS https://api/v2/users | jq '.|length')
    ```

16. **Roll logs older than N days**

    ```bash
    find /var/log/myapp -type f -mtime +7 -exec gzip -9 {} \; -exec rm -f {} \;
    ```

    *Tip*: or configure logrotate.

17. **Service health check with systemd**

    ```bash
    svc=nginx
    if ! systemctl is-active --quiet "$svc"; then
      err "$svc down"; journalctl -u "$svc" -n 50 >&2; exit 1
    fi
    ```

18. **Batch restart via SSH over a bastion**

    ```bash
    while read -r host; do
      ssh -J bastion ops@"$host" 'sudo systemctl restart myapp'
    done < hosts.txt
    ```

19. **Atomic deployment symlink switch**

    ```bash
    ln -sfn /opt/app/releases/$(date +%Y%m%d%H%M%S) /opt/app/current && systemctl reload myapp
    ```

20. **Rsync a directory tree (preserve attrs, show progress)**

    ```bash
    rsync -aP --delete ./build/ user@server:/srv/app/build/
    ```

    *Why*: `-a` implies perms/times/recurse; `-P` progress & partial.

21. **Check who’s locking a file and act**

    ```bash
    if lsof /var/lib/dpkg/lock-frontend >/dev/null; then sleep 10; fi
    ```

22. **Timeout a busy probe, then hard‑kill**

    ```bash
    timeout -k 5s 30s ./probe.sh || { err "probe hung"; killall -9 probe.sh || true; }
    ```

    *Note*: `timeout` sends TERM then KILL after `-k`.

23. **Create a here‑doc config with variables**

    ```bash
    cat > /etc/myapp/app.conf <<EOF
    region=${REGION:-us-east-1}
    threads=${THREADS:-4}
    EOF
    ```

24. **Case over distro to choose a package manager**

    ```bash
    . /etc/os-release
    case "$ID" in ubuntu|debian) pm="apt";; rhel|centos|fedora) pm="dnf";; arch) pm="pacman";; suse|sles|opensuse*) pm="zypper";; *) pm="";; esac
    echo "Using $pm"
    ```

25. **Compute checksums for integrity**

    ```bash
    sha256sum *.tar.gz > SHA256SUMS && sha256sum -c SHA256SUMS
    ```

26. **SELinux quick mode flip (non‑persistent)**

    ```bash
    getenforce
    sudo setenforce 0  # permissive temporarily
    sudo setenforce 1  # back to enforcing
    ```

    *Note*: `setenforce` doesn’t persist across reboots.

27. **Open firewall port (firewalld)**

    ```bash
    sudo firewall-cmd --add-port=8080/tcp --permanent
    sudo firewall-cmd --reload
    ```

28. **Loop over files robustly with globbing disabled**

    ```bash
    set -f  # disable glob
    IFS=$'\n' read -r -d '' -a files < <(find data -type f -name '*.csv' -print0)
    for f in "${files[@]}"; do echo "importing $f"; done
    set +f
    ```

29. **Install a cron job programmatically**

    ```bash
    ( crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup.sh" ) | crontab -
    ```

30. **Bash function to require a command**

    ```bash
    need(){ command -v "$1" >/dev/null || { echo "Missing: $1" >&2; exit 127; }; }
    need curl; need jq
    ```

> **Notes & refs:** Strict/robust scripting uses Bash `set` options and `trap` with signals. `timeout` is from GNU coreutils. Systemd (`systemctl`,`journalctl`) docs on freedesktop; SSH options from OpenSSH manpages; `rsync` behavior and `-aP` flags from the rsync manpage.

---

## Part C — Networking & Security Quick Recipes

* **Firewall (UFW)**: enable, allow SSH, and check:

  ```bash
  sudo ufw allow 22/tcp
  sudo ufw enable
  sudo ufw status verbose
  ```

* **Firewall (firewalld)**: allow service & verify:

  ```bash
  sudo firewall-cmd --add-service=https --permanent
  sudo firewall-cmd --reload
  sudo firewall-cmd --zone=public --list-all
  ```

* **SSH hardening basics** (server side):

  * Disable root login and password auth in `/etc/ssh/sshd_config`, then `sudo systemctl reload sshd`.

* **SELinux port labeling** (when a service binds a non‑default port):

  ```bash
  sudo semanage port -a -t http_port_t -p tcp 8080
  sudo systemctl restart httpd
  ```

  *If port already labeled, use `-m` to modify.*

---

## Part D — Handy Admin One‑Liners (grab bag)

* **Who’s using a mount point**: `fuser -vm /mnt/data`
* **Show kernel ring buffer (readable timestamps)**: `dmesg -T`
* **Check listening sockets with owners**: `sudo ss -tulpen`
* **Quick OS/distro string**: `source /etc/os-release && echo "$PRETTY_NAME"`
* **Get public IP**: `curl -s https://ifconfig.me` (or any trusted endpoint).

---

## Appendix — Where to Read More (authoritative docs)

* **Bash Reference Manual** — expansions, arrays, redirections, `set`, traps.
* **Coreutils / GNU manuals** — `sort`, `cut`, `uniq`, `tee`, `stat`, `timeout`, etc.
* **Find & xargs** — correct NUL‑safe usage (`-print0` / `-0`).
* **sed** — in‑place editing, addressing, backup suffixes.
* **awk (gawk)** — field processing and reporting.
* **OpenSSH manpages** — `ssh`, `scp`, `ssh-copy-id`, `ssh-agent`/`ssh-add`.
* **systemd** — `systemctl`, `journalctl`, `hostnamectl`.
* **iproute2 / sockets** — `ip`, `ss`.
* **curl / wget** — HTTP(S), headers, downloads.
* **rsync** — archive/permissions/progress.
* **Firewalls** — UFW & firewalld.
* **SELinux basics** — `getenforce`, `setenforce`, `semanage port`.
* **`tldr` pages** — concise examples for common commands.
* **ShellCheck** — lint your scripts.

---

### Production caveats (read me!)

* `rm`, `find -delete`, `sed -i`, `setenforce`, firewall changes, and systemd actions can have **system‑wide impact**. Dry‑run first, target specific paths, and review diffs.
* Some commands differ subtly across distros; consult the referenced manpages for your platform (Debian/Ubuntu vs RHEL/Fedora vs Arch vs SUSE).
