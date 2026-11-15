#!/bin/bash
# start a worker session in the parasite repo itself (so the repo CLAUDE.md, the memory and the global rules all load)
# on a job's brief, for a controller session to drive (docs/worker-loop.md).
# usage: tools/loop/start-worker.sh <brief> [name]   brief: absolute, or relative to the repo; name default parasite-worker
# loops: tools/loop/worker-restart <name> writes the flag and stops claude, and this starts it again fresh in the same
# pane on the same brief; a plain /exit ends it.
REPO=$(readlink -f "$(dirname "$(readlink -f "$0")")/../..")
BRIEF="$1"
[[ "$BRIEF" = /* ]] || BRIEF="$REPO/$BRIEF"
NAME="${2:-parasite-worker}"
[ -f "$BRIEF" ] || { echo "no brief: $BRIEF"; exit 1; }
cd "$REPO"
FLAG="/tmp/parasite-worker-restart-$NAME"
rm -f "$FLAG"
while :; do
  claude --model sonnet --effort high -n "$NAME" --remote-control "$NAME" \
    "Read docs/worker-loop.md (section Worker) and '$BRIEF', and follow them. You are the worker; the controller is named in the brief."
  [ -f "$FLAG" ] || break
  rm -f "$FLAG"
  echo "== $NAME: fresh session on $BRIEF =="
done
