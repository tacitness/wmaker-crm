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
- **One trunk, `master`** (it matches *upstream's* branch name — keep it; don't
  rename to `main`). Every change is a short-lived branch → PR → rebase-merge; no
  long-lived integration branch (ng/-ai consume the container image, not a git
  ref). Sibling repos are greenfield and use `main` — that mismatch is fine.

## Build

Autotools, so bare `make` builds Window Maker. The top-level `Makefile` is
`./configure`-generated and gitignored — **never commit a `Makefile` (or a
`GNUmakefile`, which GNU make reads first and would hijack the build)**. Infra
targets live in the separately-named `infra.mk`:

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
