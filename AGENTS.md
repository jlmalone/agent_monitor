# AGENTS.md

Read `/Users/joseph.malone/AGENTS.md` first. This file is the repository authority.

Agent Monitor presents local agent state and provides a CLI integration. Keep `state.json` as the
single source of truth. `quickreport` updates must be atomic, bounded to the retained progress
history, and fast enough for normal agent reporting.

- Do not commit local agent state, personal paths, credentials, or generated distributables.
- Run `cli/test/integration-test.sh` after CLI or state-format changes. Verify the app UI manually
  only when it is already running and the change warrants it.
- Keep protocol detail in [AI.md](AI.md); it is optional reference, not startup authority.

`CLAUDE.md` is a compatibility loader.
