# Setup — get your Lyzr API key and set it as an environment variable

This skill authenticates with a Lyzr API key read from the `LYZR_API_KEY` environment
variable. This guide shows how to (1) get the key from Lyzr Studio and (2) set it as an
environment variable on macOS, Linux, and Windows.

---

## 1. Get your API key from Lyzr Studio

1. Go to **https://studio.lyzr.ai** and sign in (Google, GitHub, or email).
2. Open the **sidebar** and click your **organization / account name** (bottom-left).
3. Select **"Account & API Key"**.
4. Click **Copy** next to your API key. It looks like `sk-default-XXXXXXXXXXXXXXXXXXXXXXXX`.

> Treat this key like a password — it grants full access to your agents. Don't commit it to
> git, paste it into shared docs, or expose it in client-side/browser code.

Optionally, some features also use a **`LYZR_USER_ID`** (your account email works). Set it
the same way as `LYZR_API_KEY` below if needed.

---

## 2. Set it as an environment variable

Pick your OS and shell. Replace `sk-default-your-key-here` with the key you copied.

### macOS

macOS uses **zsh** by default (Catalina and later). Older setups use **bash**.

**zsh** (default) — add to `~/.zshrc`:
```bash
echo 'export LYZR_API_KEY="sk-default-your-key-here"' >> ~/.zshrc
source ~/.zshrc
```

**bash** — add to `~/.bash_profile`:
```bash
echo 'export LYZR_API_KEY="sk-default-your-key-here"' >> ~/.bash_profile
source ~/.bash_profile
```

Not sure which shell you use? Run `echo $SHELL` — `/bin/zsh` → zsh, `/bin/bash` → bash.

### Linux

**bash** (most distros) — add to `~/.bashrc`:
```bash
echo 'export LYZR_API_KEY="sk-default-your-key-here"' >> ~/.bashrc
source ~/.bashrc
```

**zsh** — add to `~/.zshrc`:
```bash
echo 'export LYZR_API_KEY="sk-default-your-key-here"' >> ~/.zshrc
source ~/.zshrc
```

To make it available to **all users / GUI apps** system-wide, add the same `export` line to
`/etc/environment` or a file in `/etc/profile.d/` (requires sudo), then log out and back in.

### Windows

**PowerShell — current session only** (gone when you close the window):
```powershell
$env:LYZR_API_KEY = "sk-default-your-key-here"
```

**PowerShell — persistent** (saved for your user, available in new sessions):
```powershell
[System.Environment]::SetEnvironmentVariable("LYZR_API_KEY", "sk-default-your-key-here", "User")
```
Close and reopen PowerShell for it to take effect.

**Command Prompt (cmd.exe) — current session only:**
```cmd
set LYZR_API_KEY=sk-default-your-key-here
```

**Command Prompt — persistent** (use `setx`; note: applies to *new* windows, not the current one):
```cmd
setx LYZR_API_KEY "sk-default-your-key-here"
```

**Windows Settings (GUI):**
1. Press `Win`, search **"Edit environment variables for your account"**.
2. Under **User variables**, click **New**.
3. Variable name: `LYZR_API_KEY` — Variable value: your key. Click **OK**.
4. Restart your terminal / editor so it picks up the new variable.

### Alternative: a `.env` file (any OS)

If you prefer not to touch your shell profile, create a `.env` file in your project (this
repo's `.gitignore` already excludes `.env`, so it won't be committed):
```bash
LYZR_API_KEY=sk-default-your-key-here
```
Then load it before running commands, e.g. `set -a; source .env; set +a` (bash/zsh), or use
a loader like `direnv` / `python-dotenv`.

---

## 3. Verify it worked

**macOS / Linux:**
```bash
echo $LYZR_API_KEY        # should print your key
```

**Windows PowerShell:**
```powershell
$env:LYZR_API_KEY
```

**Windows Command Prompt:**
```cmd
echo %LYZR_API_KEY%
```

End-to-end check against the live API (macOS/Linux) — lists your agents:
```bash
curl -s "https://agent-prod.studio.lyzr.ai/v3/agents/" -H "x-api-key: $LYZR_API_KEY" | head
# or, using this skill's helper:
python3 .claude/skills/lyzr-agents/scripts/lyzr.py list
```
If you see your agents (or `[]` for a new account), you're set. A `401`/`Method Not Allowed`
means the key isn't being read — re-open your terminal and re-check step 2.
