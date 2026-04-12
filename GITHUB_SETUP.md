# Connect this folder to GitHub

Git is already initialized here. After you create the empty repo on GitHub, run the commands in **Step 3** (replace placeholders).

## Step 1 — Create the repository on GitHub (website)

1. Log in at [github.com](https://github.com).
2. **+** → **New repository**.
3. **Repository name:** e.g. `bits` or `golf-bits` (remember it — it becomes part of your Pages URL).
4. Choose **Public** (simplest free **GitHub Pages** preview) or **Private** (check your org’s Pages rules).
5. **Do not** add a README, `.gitignore`, or license (this folder already has content).
6. Click **Create repository**.

Copy the **HTTPS** or **SSH** URL GitHub shows, e.g.:

- `https://github.com/YOUR_USERNAME/YOUR_REPO.git`
- `git@github.com:YOUR_USERNAME/YOUR_REPO.git`

## Step 2 — One-time identity (if Git has never been configured on this PC)

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

## Step 3 — Link remote and push (run inside `bits`)

Replace `YOUR_REPO_URL` with the URL from Step 1.

```bash
cd "path\to\bits"
git remote add origin YOUR_REPO_URL
git push -u origin main
```

If GitHub asks for credentials, use a **Personal Access Token** (HTTPS) or SSH keys — see [GitHub docs: authentication](https://docs.github.com/en/get-started/getting-started-with-git/about-remote-repositories).

## Step 4 — Enable GitHub Pages (optional preview)

1. Repo on GitHub → **Settings** → **Pages**.
2. **Build and deployment** → **Source** → **GitHub Actions**.
3. Push any change to **`main`** (or use **Actions** → **Flutter Web → GitHub Pages** → **Run workflow**).

Your preview URL is usually:

`https://YOUR_USERNAME.github.io/YOUR_REPO/`

(Workflow uses `--base-href "/YOUR_REPO/"` so assets match that path.)

## What you need to send / decide

Fill these in for yourself (no need to paste secrets into chat):

| Item | Example |
|------|--------|
| GitHub username or org | `acme-corp` |
| Repository name | `bits` |
| HTTPS or SSH remote URL | `https://github.com/acme-corp/bits.git` |

If you tell me **only** `YOUR_USERNAME` and `YOUR_REPO` (no tokens), I can double-check your `git remote` command line for typos.

## If `git push` says the remote rejected `main`

Some empty repos default to `master`. Either:

```bash
git push -u origin main:master
```

or rename the default branch on GitHub (**Settings** → **General** → **Default branch**) to `main`, then:

```bash
git push -u origin main
```

This repo’s first commit uses branch **`main`**.
