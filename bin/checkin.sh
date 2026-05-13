#!/bin/bash
# telegram-relay client — runs from the daily Claude check-in (or your laptop).
#
# Usage:
#   echo "message body" | bash bin/checkin.sh send
#   bash bin/checkin.sh poll      # prints path to newest inbox json
#   bash bin/checkin.sh latest    # prints text of newest inbox message
#
# Required env:
#   RELAY_REPO_URL — git URL with PAT, e.g.
#     https://x-access-token:<PAT>@github.com/<user>/telegram-relay.git
#
# Optional env:
#   RELAY_WORKDIR — where to clone (default: /tmp/telegram-relay-work)

set -e

CMD="$1"
WORKDIR="${RELAY_WORKDIR:-/tmp/telegram-relay-work}"

if [ -z "$RELAY_REPO_URL" ]; then
  echo "ERROR: RELAY_REPO_URL not set" >&2
  exit 1
fi

ensure_clone() {
  if [ ! -d "$WORKDIR/.git" ]; then
    git clone --quiet --depth 1 "$RELAY_REPO_URL" "$WORKDIR"
  else
    git -C "$WORKDIR" fetch --quiet origin
    git -C "$WORKDIR" reset --hard --quiet origin/HEAD
  fi
}

case "$CMD" in
  send)
    ensure_clone
    TS=$(date -u +%Y%m%d-%H%M%S)
    PID=$$
    FN="$WORKDIR/outbox/${TS}-${PID}.txt"
    mkdir -p "$WORKDIR/outbox"
    cat > "$FN"
    if [ ! -s "$FN" ]; then
      echo "ERROR: empty message body on stdin" >&2
      rm -f "$FN"
      exit 1
    fi
    git -C "$WORKDIR" add outbox/
    git -C "$WORKDIR" \
      -c user.email=claude@local \
      -c user.name=claude-relay \
      commit -q -m "send: ${TS}"
    git -C "$WORKDIR" push --quiet
    echo "queued: outbox/${TS}-${PID}.txt"
    ;;

  poll)
    ensure_clone
    LATEST=$(ls -t "$WORKDIR/inbox"/*.json 2>/dev/null | head -n 1 || true)
    if [ -z "$LATEST" ]; then
      echo "ERROR: no messages in inbox" >&2
      exit 2
    fi
    echo "$LATEST"
    ;;

  latest)
    ensure_clone
    LATEST=$(ls -t "$WORKDIR/inbox"/*.json 2>/dev/null | head -n 1 || true)
    if [ -z "$LATEST" ]; then
      echo "ERROR: no messages in inbox" >&2
      exit 2
    fi
    python3 -c "import json,sys; print(json.load(open('$LATEST')).get('text',''))"
    ;;

  *)
    echo "Usage: $0 {send|poll|latest}" >&2
    exit 1
    ;;
esac
