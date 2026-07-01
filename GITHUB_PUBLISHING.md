# GitHub Publishing Guide

## 1. Confirm Asset Rights

Before publishing, confirm that `sounds/ok.mp3` and `sounds/error.mp3` can be
redistributed publicly. If the source or license is unclear, replace them with
audio files you created yourself or files released under a compatible license
such as CC0.

## 2. Repository Name

Current repository:

```text
nestahedrington-lab/ai-cli-notify-sounds
```

## 3. Initialize Git

```bash
git init
git add .
git commit -m "Initial open source release"
```

## 4. Create GitHub Repository

Using GitHub CLI:

```bash
gh repo create nestahedrington-lab/ai-cli-notify-sounds --public --source=. --remote=origin --push
```

Or create an empty public repository on GitHub, then run:

```bash
git branch -M main
git remote add origin git@github.com:nestahedrington-lab/ai-cli-notify-sounds.git
git push -u origin main
```

## 5. Update README Install URL

After the repository exists, make sure the install URL in `README.md` points to
the real GitHub repository path.
