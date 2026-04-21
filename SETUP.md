# PStream Android — Setup Instructions

## 1. Install MCP Tools

Run these once on your machine (Windows terminal or WSL):

```bash
# GitHub MCP (fetch P-Stream source, manage repo)
npm install -g @modelcontextprotocol/server-github

# Code Review Graph (dependency-aware context saving)
pip install code-review-graph

# Verify both installed
npx @modelcontextprotocol/server-github --version
code-review-graph --version
```

## 2. .env Keys — Where to Get Each

Your `.codex\.env` needs these values filled in:

---

### GITHUB_PAT_DIKSHA
Diksha's GitHub Personal Access Token. Used by the GitHub MCP server.

1. Go to: **github.com → Settings → Developer Settings → Personal access tokens → Fine-grained tokens**
2. Click "Generate new token"
3. Name: `PStream Codex`
4. Expiration: 1 year
5. Repository access: Only select repositories → select `pstream-android`
6. Permissions:
   - Contents: **Read and Write**
   - Pull requests: **Read and Write**
   - Issues: **Read and Write**
   - Actions: **Read**
7. Copy token → paste as `GITHUB_PAT_DIKSHA=ghp_xxx`

---

### GITHUB_PAT_PRACHEER
Pracheer's GitHub Personal Access Token. Used ONLY by git CLI (identity switching).
Same steps as above but logged in as Pracheer's GitHub account.
Paste as `GITHUB_PAT_PRACHEER=ghp_xxx`

---

### GOOGLE_API_KEY
For Stitch MCP (Flutter widget generation from descriptions).

1. Go to: **console.cloud.google.com**
2. Create a project or select existing
3. Go to: **APIs & Services → Library**
4. Search and enable: `Vertex AI API`
5. Go to: **APIs & Services → Credentials**
6. Click "Create Credentials" → "API Key"
7. Copy key → paste as `GOOGLE_API_KEY=AIza...`

---

### TMDB_READ_TOKEN
For TMDB metadata (movies/TV data). Free account.

1. Go to: **themoviedb.org → Sign Up** (free)
2. Go to: **Account Settings → API → Create → Developer**
3. Fill the form (put personal use)
4. Under your API page, copy the **"API Read Access Token"** (NOT the API Key v3)
5. It starts with `eyJ...` — paste as `TMDB_READ_TOKEN=eyJ...`

---

### ORACLE_VM_IP
Your Oracle Always Free VM's public IP address.
Find at: **cloud.oracle.com → Compute → Instances → your instance → Public IP**
Paste as `ORACLE_VM_IP=xxx.xxx.xxx.xxx`

---

### FIGMA_ACCESS_TOKEN (optional)
Only needed if you use Figma MCP for write operations.

1. Go to: **figma.com → Account Settings → Personal access tokens**
2. Generate token
3. Paste as `FIGMA_ACCESS_TOKEN=figd_...`

---

## 3. SSH Config for Git Identity Switching

Add this to your `~/.ssh/config` (create if it doesn't exist):

```
# Diksha — repo owner
Host github-diksha
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_diksha

# Pracheer — contributor
Host github-pracheer
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_pracheer
```

When Diksha's code is pushed:
```bash
git remote set-url origin git@github-diksha:dikshadamahe/pstream-android.git
git config user.name "dikshadamahe"
git config user.email "dikshadamahe25@gmail.com"
```

When Pracheer's code is pushed:
```bash
git remote set-url origin git@github-pracheer:dikshadamahe/pstream-android.git
git config user.name "pracheersrivastava"
git config user.email "pracheer2023 @gmail.com"
```

The `switch-dev.sh` script in the project root handles this automatically.

---

## 4. Initialize Code Review Graph

Run ONCE after Flutter project is scaffolded:

```bash
cd C:\Users\Pracheer\Documents\P-Stream
code-review-graph init
```

This builds the initial dependency graph. Re-run after major refactors.

---

## 5. Verify Everything Works

Open Codex CLI in the project folder and run:

```
/mcp
```

You should see all 5 servers listed as connected:
- dart-mcp-server ✓
- github ✓
- code-review-graph ✓
- StitchMCP ✓
- figma ✓
