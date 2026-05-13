# telegram-relay

A push-driven bridge between Claude (or any sandboxed agent that can `git push`
but cannot reach `api.telegram.org`) and a personal Telegram chat.

## How it works

```
Claude → git push outbox/X.txt → GitHub Actions → Telegram sendMessage
Telegram reply → Actions cron poll → commit inbox/X.json → Claude pulls
```

Two workflows:
- **send.yml** — triggers on push to `outbox/**`, sends each file via Telegram
  Bot API, moves it to `sent/`.
- **poll.yml** — runs every 10 min, calls `getUpdates`, saves new messages as
  JSON in `inbox/`, persists the offset in `state/offset.txt`.

Round-trip latency: ~30 seconds outbound, up to 10 min inbound (the cron
interval). Fine for daily check-ins, not for chat.

## Setup

1. Create a private GitHub repo named `telegram-relay`, push these files.
2. Settings → Secrets and variables → Actions, add:
   - `TELEGRAM_BOT_TOKEN`
   - `TELEGRAM_CHAT_ID`
3. Settings → Actions → General → Workflow permissions: **Read and write**.
4. Generate a fine-grained PAT scoped to this repo only, with
   `Contents: Read and write`. Copy it.
5. Set on whatever machine runs the client:
   ```
   export RELAY_REPO_URL="https://x-access-token:<PAT>@github.com/<you>/telegram-relay.git"
   ```

## Usage

```bash
# Send
echo "hello from the relay" | bash bin/checkin.sh send

# Get path to newest received message (full JSON)
bash bin/checkin.sh poll

# Get just the text of the newest received message
bash bin/checkin.sh latest
```

## Notes

- The `sent/` and `inbox/` directories grow unbounded. Prune occasionally.
- The bot token in secrets is encrypted at rest by GitHub. The PAT used by the
  client is only as scoped as you make it — keep it to this repo, contents
  read/write only.
