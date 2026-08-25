# GrooveStats in VOLT26

GrooveStats is an optional integration. VOLT26 uses the ITGmania HTTPS API for service discovery, score lookup, leaderboards, and eligible score submission.

## Enable the integration

1. Open the ITGmania service menu.
2. Open `GrooveStats Options`.
3. Set `Enable GrooveStats` to `Yes`.
4. Restart the current game cycle or return to the title screen so VOLT26 can refresh service availability.

The title screen reports whether score lookup, leaderboards, and submission are available. The Sort Menu on Song Select exposes the leaderboard viewer.

## Configure a profile

VOLT26 reads GrooveStats credentials from `GrooveStats.ini` in the selected persistent profile directory. A missing file is created automatically when the profile is loaded.

```ini
[GrooveStats]
ApiKey=YOUR_64_CHARACTER_API_KEY
Username=YOUR_GROOVESTATS_USERNAME
IsPadPlayer=1
```

Set `IsPadPlayer=1` only for scores played on a dance pad. Keyboard profiles can use lookups and leaderboards with `IsPadPlayer=0`, but their scores are not submitted. Treat the API key as a secret: do not commit, publish, or include it in logs or screenshots.

Local profiles normally live below `Save/LocalProfiles/`; memory-card profiles use their own profile directory. Guest profiles do not provide durable credential storage.

## Current security boundary

VOLT26 does not expose the inherited QR login, automatic event-unlock downloads, or experimental online lobbies. Their upstream implementations use separate WebSocket/download trust boundaries that require dedicated validation before they can be enabled safely. Valid RPG and ITL result data returned by score submission can populate the dormant Evaluation event views, but it cannot trigger downloads or the hard-coded local ITL 2026 persistence path.

Service responses and remotely synchronized player-option data are size-bounded and parsed behind the `VOLT26.GrooveStats` interface. Invalid credentials, malformed JSON, unsupported games, non-ITG settings, autoplay, and score-altering modifiers prevent normal submission behavior.
