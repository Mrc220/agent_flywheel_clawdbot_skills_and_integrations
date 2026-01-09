---
name: caam
description: "Coding Agent Account Manager - Sub-100ms account switching for AI coding CLIs with fixed-cost subscriptions. Vault profiles, isolated profiles for parallel sessions, smart rotation with health scoring, cooldown tracking, automatic failover. Go CLI."
---

# CAAM — Coding Agent Account Manager

A Go CLI for instant account switching between fixed-cost AI coding subscriptions (Claude Max, GPT Pro, Gemini Ultra). When you hit rate limits, swap accounts in ~50ms instead of 30-60 seconds of browser OAuth friction.

## Why This Exists

You're paying $200-275/month for fixed-cost AI coding subscriptions. These plans have rolling usage limits—not billing caps, but rate limits that reset over time. When you hit them mid-flow:

**The Problem:**
```
/login → browser opens → sign out of Google → sign into different Google →
authorize app → wait for redirect → back to terminal
```
That's 30-60 seconds of friction, 5+ times per day across multiple tools.

**The Solution:**
```bash
caam activate claude bob@gmail.com   # ~50ms, done
```

No browser. No OAuth dance. No interruption to your flow state.

## How It Works

Each AI CLI stores OAuth tokens in plain files. CAAM backs them up and restores them:

```
~/.claude.json ←→ ~/.local/share/caam/vault/claude/alice@gmail.com/
~/.codex/auth.json ←→ ~/.local/share/caam/vault/codex/work@company.com/
```

OAuth tokens are bearer tokens—possession equals access. Swapping files is equivalent to "being" that authenticated session.

### Profile Detection

`caam status` uses **content hashing**:
1. SHA-256 hash current auth files
2. Compare against all vault profiles
3. Match = that's what's active

No hidden state files that can desync. Works correctly after reboots.

## Quick Start

```bash
# Install
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/coding_agent_account_manager/main/install.sh?$(date +%s)" | bash

# Backup current account
caam backup claude alice@gmail.com

# Clear and login to another account
caam clear claude
claude  # /login with bob@gmail.com
caam backup claude bob@gmail.com

# Switch instantly forever
caam activate claude alice@gmail.com   # < 100ms
caam activate claude bob@gmail.com     # < 100ms

# Check status
caam status
```

## Two Operating Modes

### 1. Vault Profiles (Simple Switching)

Swap auth files in place. One account active at a time per tool. Instant switching.

```bash
caam backup claude work@company.com
caam activate claude personal@gmail.com
```

**Use when:** You want to switch between accounts sequentially (most common).

### 2. Isolated Profiles (Parallel Sessions)

Run multiple accounts **simultaneously** with full directory isolation.

```bash
caam profile add codex work@company.com
caam profile add codex personal@gmail.com
caam exec codex work@company.com -- "implement feature X"
caam exec codex personal@gmail.com -- "review code"
```

Each profile gets its own `$HOME` and `$CODEX_HOME` with symlinks to your real `.ssh`, `.gitconfig`, etc.

**Use when:** You need two accounts running at the same time in different terminals.

## Supported Tools

| Tool | Subscription | Auth Files |
|------|--------------|------------|
| **Claude Code** | Claude Max ($200/mo) | `~/.claude.json`, `~/.config/claude-code/auth.json`, `~/.claude/settings.json` |
| **Codex CLI** | GPT Pro ($200/mo) | `~/.codex/auth.json` (or `$CODEX_HOME/auth.json`) |
| **Gemini CLI** | Gemini Ultra (~$275/mo) | `~/.gemini/settings.json`, `~/.gemini/oauth_credentials.json`, `~/.gemini/.env` |

### Login Commands

| Tool | Login Command |
|------|---------------|
| Claude Code | `/login` in CLI |
| Codex CLI | `codex login` or `codex login --device-auth` |
| Gemini CLI | Start `gemini`, select "Login with Google" or `/auth` |

## Command Reference

### Auth File Swapping (Primary)

| Command | Description |
|---------|-------------|
| `caam backup <tool> <email>` | Save current auth files to vault |
| `caam activate <tool> <email>` | Restore auth files from vault (instant switch) |
| `caam status [tool]` | Show which profile is currently active |
| `caam ls [tool]` | List all saved profiles in vault |
| `caam delete <tool> <email>` | Remove a saved profile |
| `caam paths [tool]` | Show auth file locations for each tool |
| `caam clear <tool>` | Remove auth files (logout state) |
| `caam uninstall` | Restore originals and remove caam data/config |

**Aliases:** `caam switch` and `caam use` work like `caam activate`

### Smart Profile Management

| Command | Description |
|---------|-------------|
| `caam activate <tool> --auto` | Auto-select best profile using rotation algorithm |
| `caam next <tool>` | Preview which profile rotation would select |
| `caam run <tool> [-- args]` | Wrap CLI with automatic failover on rate limits |
| `caam cooldown set <provider/profile>` | Mark profile as rate-limited (default: 60min) |
| `caam cooldown list` | List active cooldowns with remaining time |
| `caam cooldown clear <provider/profile>` | Clear cooldown for a profile |
| `caam cooldown clear --all` | Clear all active cooldowns |
| `caam project set <tool> <profile>` | Associate current directory with a profile |
| `caam project get [tool]` | Show project associations for current directory |

### Profile Isolation (Advanced)

| Command | Description |
|---------|-------------|
| `caam profile add <tool> <email>` | Create isolated profile directory |
| `caam profile ls [tool]` | List isolated profiles |
| `caam profile delete <tool> <email>` | Delete isolated profile |
| `caam profile status <tool> <email>` | Show isolated profile status |
| `caam login <tool> <email>` | Run login flow for isolated profile |
| `caam exec <tool> <email> [-- args]` | Run CLI with isolated profile |

## Smart Profile Management

### Profile Health Scoring

Each profile displays a health indicator:

| Icon | Status | Meaning |
|------|--------|---------|
| 🟢 | Healthy | Token valid for >1 hour, no recent errors |
| 🟡 | Warning | Token expiring within 1 hour, or minor issues |
| 🔴 | Critical | Token expired, or repeated errors in last hour |
| ⚪ | Unknown | No health data available yet |

Health scoring combines:
- **Token expiry**: Time until OAuth token expires
- **Error history**: Recent authentication or rate limit errors
- **Penalty score**: Accumulated issues with **exponential decay** (20% reduction every 5 minutes)
- **Plan type**: Enterprise/Pro plans get slight scoring boosts

After ~30 minutes of no errors, penalty score returns to near zero.

### Smart Rotation Algorithms

When you run `caam activate claude --auto`:

| Algorithm | Description |
|-----------|-------------|
| **smart** (default) | Multi-factor: cooldown state, health, recency (avoids last 30min), plan type, random jitter |
| **round_robin** | Sequential rotation, skipping cooldown profiles |
| **random** | Random selection among non-cooldown profiles |

Configure in `~/.caam/config.yaml`:
```yaml
stealth:
  rotation:
    enabled: true
    algorithm: smart  # smart | round_robin | random
```

### Cooldown Tracking

When an account hits a rate limit, mark it so rotation skips it:

```bash
# Mark current Claude profile (default: 60 min cooldown)
caam cooldown set claude

# Specify profile and duration
caam cooldown set claude/work@company.com --minutes 120

# View active cooldowns
caam cooldown list

# Clear a cooldown early
caam cooldown clear claude/work@company.com
```

When `stealth.cooldown.enabled: true`, activating a profile in cooldown warns and prompts for confirmation.

### Automatic Failover with `caam run`

Wrap CLI execution with automatic rate limit handling:

```bash
caam run claude -- "explain this code"

# If Claude hits rate limit mid-session:
# 1. Current profile goes into cooldown
# 2. Next best profile selected via rotation
# 3. Command re-executed with new account
```

**Options:**
- `--max-retries N` — Maximum retry attempts (default: 1)
- `--cooldown DURATION` — Cooldown duration after rate limit (default: 60m)
- `--algorithm NAME` — Rotation algorithm: smart, round_robin, random
- `--quiet` — Suppress profile switch notifications

**Zero-friction aliases:**
```bash
alias claude='caam run claude --'
alias codex='caam run codex --'
alias gemini='caam run gemini --'
```

Now `claude "explain this"` handles rate limits transparently.

### Project-Profile Associations

Link profiles to project directories:

```bash
cd ~/projects/work-app
caam project set claude work@company.com

# Now whenever you're in this directory
caam activate claude  # Automatically uses work@company.com
```

Associations cascade: setting on `/home/user/projects` applies to all subdirectories unless a more specific association exists.

### Preview Rotation Selection

```bash
$ caam next claude
Recommended: bob@gmail.com
  + Healthy token (expires in 4h 32m)
  + Not used recently (2h ago)

Alternatives:
  alice@gmail.com - Used recently (15m ago)

In cooldown:
  carol@gmail.com - In cooldown (45m remaining)
```

## Vault Structure

```
~/.local/share/caam/
├── vault/                          # Saved auth profiles
│   ├── claude/
│   │   ├── alice@gmail.com/
│   │   │   ├── .claude.json
│   │   │   ├── auth.json
│   │   │   └── meta.json
│   │   └── bob@gmail.com/
│   ├── codex/
│   │   └── work@company.com/
│   │       └── auth.json
│   └── gemini/
│       └── personal@gmail.com/
│           └── settings.json
│
└── profiles/                       # Isolated profiles (advanced)
    └── codex/
        └── work@company.com/
            ├── profile.json
            ├── codex_home/
            │   └── auth.json
            └── home/
                ├── .ssh -> ~/.ssh
                └── .gitconfig -> ~/.gitconfig
```

## Workflow Examples

### Daily Workflow

```bash
# Morning: Check what's active
caam status
# claude: alice@gmail.com (active)
# codex:  work@company.com (active)

# Afternoon: Hit Claude usage limit
caam activate claude bob@gmail.com
claude  # Continue immediately with new account
```

### Smart Rotation Workflow

```bash
# Let rotation pick the best profile
caam activate claude --auto

# Hit a rate limit? Mark it
caam cooldown set claude

# Next activation picks another profile automatically
caam activate claude --auto
```

### Initial Multi-Account Setup

```bash
# 1. Login to first account
claude  # /login as alice@gmail.com
caam backup claude alice@gmail.com

# 2. Clear and login to second account
caam clear claude
claude  # /login as bob@gmail.com
caam backup claude bob@gmail.com

# 3. Switch instantly forever
caam activate claude alice@gmail.com
```

## Installation

```bash
# One-liner (recommended)
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/coding_agent_account_manager/main/install.sh?$(date +%s)" | bash

# From source
git clone https://github.com/Dicklesworthstone/coding_agent_account_manager
cd coding_agent_account_manager
go build -o caam ./cmd/caam
sudo mv caam /usr/local/bin/

# Go install
go install github.com/Dicklesworthstone/coding_agent_account_manager/cmd/caam@latest
```

## Tips

1. **Use actual email as profile name** — self-documenting, never forget which account
2. **Backup before clearing:** `caam backup claude current@email.com && caam clear claude`
3. **Use --backup-current flag:** `caam activate claude new@email.com --backup-current`
4. **Check status often:** `caam status` shows what's active across all tools
5. **Don't sync vault across machines** — auth tokens often contain machine-specific identifiers

## FAQ

**Q: Does this work with API keys?**
No. CAAM is for fixed-cost subscription plans (Claude Max, GPT Pro, Gemini Ultra) that use OAuth. API keys don't need switching—just use different keys.

**Q: Is this against terms of service?**
No. You're using your own legitimately-purchased subscriptions. CAAM manages local auth files—it doesn't share accounts, bypass rate limits, or modify API traffic.

**Q: Can I sync the vault across machines?**
Don't. Auth tokens often contain machine-specific identifiers. Backup and restore on each machine separately.

**Q: What's the difference between vault and isolated profiles?**
- **Vault profiles** (`backup`/`activate`): Swap auth in place, one account active at a time
- **Isolated profiles** (`profile add`/`exec`): Full directory isolation, run multiple accounts simultaneously

**Q: Will switching break running sessions?**
May cause auth errors in running CLI. Best practice: switch before starting a new session, not during.

## Integration with Flywheel

| Tool | Integration |
|------|-------------|
| **NTM** | Each tmux pane can use different account via isolated profiles |
| **Agent Mail** | Agents can coordinate account switching across sessions |
| **CASS** | Search sessions by account to track usage patterns |
| **DCG** | No interaction (CAAM manages auth, DCG guards commands) |
