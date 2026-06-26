# CLAUDE.md — wmaker-crm

The **C window-manager core** for the wmaker-ng modernization — a pristine,
rebasable fork of GNU Window Maker tracked against `repo.or.cz/wmaker-crm`. Read
[AGENTS.md](AGENTS.md) for the full operating rules; the architecture map is in
`tacitness/wmaker-ng` ([PLAN.md](https://github.com/tacitness/wmaker-ng/blob/main/PLAN.md)
§2/§5/§8).

## Key rules

- **Keep master pristine.** master = upstream + a thin, mostly-new-files infra
  layer + (later) a small, upstream-bound C patch series. Infra (CI, docs,
  container, rebase tooling) is **new files only** — never touch the C tree or
  autotools files.
- **Source edits are patch-series-on-a-branch only.** A real C change is a small,
  documented, upstream-bound series of commits meant for `git send-email`:
  smallest seam possible, behind a config flag, disabled by default, deleted from
  our series once upstream accepts it.
- **Never push to upstream.** `upstream` is fetch-only (push URL disabled).
- **Match Window Maker C style exactly** — tabs, brace style, naming, comments.
  Run `./checkpatch.pl` on the diff.
- **Stay current by rebasing, not merging.** `make -f infra.mk rebase` (the
  rebase ritual; monthly in `upstream-sync.yml`). Never force-push master.

## Build

Autotools. Top-level `Makefile` is `./configure`-generated and gitignored, so
infra targets live in `infra.mk`:

```bash
./autogen.sh && ./configure && make   # build Window Maker (the sacred build)
make -f infra.mk help                  # rebase · image · run
```

CI (`.github/workflows/validate.yml`) proves the core compiles on Ubuntu + runs
a gitleaks scan; all third-party Actions are pinned by commit SHA with a version
comment.

## Container

`make -f infra.mk image` → headless Xvfb + wmaker. Base layer for the `ai-mcp`
sandbox (downstream: tacitness/wmaker-ng#16, #18).
