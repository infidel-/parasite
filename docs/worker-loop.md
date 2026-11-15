# Worker loops

A **controller** session (the judgment, the review and the user's contact) drives a **worker** session (Sonnet,
effort high: reads the source, edits, builds) through a job too long or too mechanical for one context. Adapted from
reaper-control's `docs/worker-loop.md` (its first run: 2026-11-15), with one difference: **here the worker runs in
the repo itself**, so the repo CLAUDE.md, the global rules and the memory all load and the code style holds without
being retyped into every brief.

## Setup
- **The job lives in the repo:** a brief per job (`docs/jobs/<job>/WORKER.md`) and a log (`docs/jobs/<job>/LOG.md`).
  The brief holds the goal in the user's words, the spec (a preview path, the game's own strings), the phases with
  their checks, the files the worker may touch, the stop points and the controller's session name. The log holds
  every iteration: the change, the build result, what was checked.
- **The brief's status line names the current phase first:** a fresh worker reads it top-down and would redo a phase
  marked "now" that is long done.
- **Standing rules from another session go in the brief** (a game window's "ask first"), or a fresh worker asks again.
- **The user starts each worker in a pane of their own:** `tools/loop/start-worker.sh <brief> [name]` (name default
  `parasite-worker`). Never open, split or move panes for them.

## Running
- **Messages:** `SendMessage`, the first line a self-contained summary. A worker started with `--remote-control` has a
  Remote Control twin under the same name: send to the local `[ref]` the refusal lists.
- **Kick after every start or restart** (in reaper-control the startup prompt never arrived, four times out of four):
  "Start: read docs/worker-loop.md (Worker) and '<brief>' and follow them; your job is Phase X."
- **The controller reviews every phase before it is committed:** the diff against the brief and the CLAUDE.md code
  style, then the result in the live game. A wrong result goes back to the same worker with the cause and a concrete
  target, not to the user.
- **A review cron (~10 min) only while a worker works:** its log's new entries, the diff staying inside the brief's
  files, the same failure twice. Delete it as soon as the round is with the user ("when you wait for my verdict, you
  need to stop scheduler, otherwise these messages push out the useful ones").
- **One builder, one game driver.** The controller doesn't run `make` while a worker works. The worker drives the
  game over CDP only when its brief says so, and parks the window after; otherwise the controller is the only driver.
- **Paid generators** (image, 3D, sound): never a worker's call; the controller asks the user.

## Fresh workers
- **A worker's context only grows** (reaper-control's reached ~255k and ~561k by a fifth phase), and every call
  resends it. At a phase boundary (committed, the worker holding): `tools/loop/worker-ctx [name]`; past about 100k,
  `tools/loop/worker-restart [name]`, then the kick message. Never mid-phase: the half-done state isn't in the log.
- `worker-restart` writes `/tmp/parasite-worker-restart-<name>` and stops the session; `start-worker.sh` loops on that
  flag and starts it again on the same brief in the same pane. A plain `/exit` ends it. It refuses a worker not started
  by `start-worker.sh` (stopping it would close the pane).
- A slash command sent as a message (`/clear`) doesn't run in the receiving session: restart instead.

## Git
- **The controller commits**, after its review and the live check: explicit paths, the `changes.md` line, the brief
  and the log. The worker never commits, never stages and never touches git state (no stash, no checkout, no reset).

## Worker
Read by the worker at every start (the start prompt points here).
- You are the **worker**. The brief names the **controller** (find it with `ListAgents`, write with `SendMessage`, the
  first line a self-contained summary). It holds the judgment and talks to the user; you read, edit and build, report
  at the brief's milestones, then wait for its answer.
- Ask the controller when unsure, never the user. A decision the user makes reaches you through the controller.
- Same failure twice in a row: stop and tell the controller.
- Touch only the files the brief lists; a needed file outside them is a question to the controller first.
- Each phase ends with `cd src && make` passing (the build and the quick tests). Report the result as measured,
  failures quoted.
- Log every iteration in the brief's LOG.md: the change, the files, the build result.
- Never commit, stage, stash, checkout or reset: the controller commits after its review.
- Never call a paid generator; never extend the debug surface (a `window.__*` hook, a debug key, a trace) unasked.
- Scratch experiments go in your scratchpad, never in the repo.
