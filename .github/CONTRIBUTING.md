# Contributing

Thanks for helping! A quick path to a great PR:
1. **Discuss first** (open an Issue or start a Discussion).
2. **Fork & branch**: `feat/<topic>` or `fix/<topic>`.
3. **Keep scripts safe**: shellcheck clean (`bash -euxo pipefail` in examples).
4. **Run CI locally when possible** (or open a Draft PR to see checks).
5. **PR checklist**: tests or demos, docs updated, CI green.

## Dev setup
- Shell: Bash ≥4, plus `git`, `curl`, `jq`. Containers optional (Docker/Podman).
- Style: small commits; conventional messages (e.g., `feat: …`, `fix: …`).

## Security & secrets
Never commit real secrets. Use `.env.example` patterns. Report vulnerabilities privately (see SECURITY.md).
