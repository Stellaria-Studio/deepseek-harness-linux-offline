# deepseek-harness-linux-offline engineering

## SEA 2 project knowledge

Use `sea_context` with this project's repository ID for a compact architecture
bootstrap, then expand only the concept/source/test needed for the task. Shared
runtime belongs to `Stellaria-Studio/Stellaria-SEA`; this repository owns
`.sea/` and `tools/sea/project.json`. The local CLI adapter is
`python3 tools/sea/stellaria-sea/scripts/sea.py context bootstrap`.
SEA is an optional knowledge runtime: no identity binding, approval workflow,
agent/model control or build prerequisite. Keep objectives and unfinished
requirements in local task capsules when useful. Source, actual tests and
product quality evidence remain authoritative; a knowledge query proves no
acceptance. See `.sea/README.md` for installation and legacy compatibility.

## SEA 2.1 task board on the engineering mainline

For substantial work, use `sea_task submit` with the original objective,
requirements, concepts, paths and interfaces. Continue an existing exact task
instead of creating a duplicate. Checkpoint remaining work with expected revisions.
Tasks and append-only events belong to `.sea/tasks/` and `.sea/task-events/` on
this repository's normal mainline, and join the authorized scoped code commit.
Do not create a separate task branch. SEA records Git committer attribution;
committed progress resolves the actual Git commit writer. This is attribution,
not account binding, approval, exclusive ownership or proof of product acceptance.
Uncommitted/unpushed work is not visible to other checkouts. Reconcile divergent
progress without discarding the goal or another user's completed requirements.
SEA leaves product source and the Git index alone; normal Git integration and
push authorization still apply. Shared runtime workflow: `docs/TASK_BOARD.md`
in `Stellaria-Studio/Stellaria-SEA`.
