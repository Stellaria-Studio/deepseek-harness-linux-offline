# deepseek-harness-linux-offline · SEA 2

Project: `Stellaria-Studio/deepseek-harness-linux-offline` · Tier C · knowledge-runtime

Community-maintained offline installer and compatibility runtime for DeepSeek Harness on ARM64 GNU/Linux, including Kylin, UOS and openEuler.

This directory owns source-pinned architecture concepts and aliases, invariant
pointers and validation entry points. Shared executable code, schemas, tests and
methodology live only in the private `Stellaria-Studio/Stellaria-SEA` repository.
Clone that repository beside this checkout, or set `STELLARIA_SEA_CORE` to its
root. No account binding, confirmation, signing setup or Hub is required. A
public contributor without private-core access can read these JSON files and
run the project checks normally; SEA is never a build prerequisite.

```sh
python3 tools/sea/stellaria-sea/scripts/sea.py context bootstrap
python3 tools/sea/stellaria-sea/scripts/sea.py context search --query ARCHITECTURE_TOPIC
python3 tools/sea/stellaria-sea/scripts/sea.py context test --mode validate
python3 tools/sea/stellaria-sea/scripts/sea.py validate
```

Use MCP `sea_context(project="Stellaria-Studio/deepseek-harness-linux-offline", action="bootstrap")` after
registering the local checkout in the core workspace map. Context mode budgets
are hard character bounds, not measured tokenizer savings. Code/doc excerpts
carry path, line and source identity; a dirty worktree and an unreachable remote
remain explicit. Concepts are repository declarations, never automatic approval.

Legacy `tools/sea/project.json`, rounds, archives and Git event history retain
their original bytes. `sea_knowledge` and `sea_round_close` remain available in
the shared runtime. SEA 2 tasks default to external local SQLite/WAL state and
CAS revisions. Local conflict hints are not team-wide locks; hashed receipts
are not independent visual/product acceptance. No transcript is collected.

The lightweight CI validates the local contract and pinned source pointers
without private-core credentials. It does not execute product commands, deploy
services or change branch protections. Uninstalling SEA leaves product builds
and historical knowledge available.
