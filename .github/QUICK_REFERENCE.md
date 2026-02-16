# Git Quick Reference Card

## Daily Commands

### Check Status
```bash
git status                    # See what changed
git status --short            # Compact view
git diff                      # See unstaged changes
git diff --cached             # See staged changes
```

### Stage & Commit
```bash
git add .                     # Stage all changes
git add <file>                # Stage specific file
git commit -m "message"       # Commit with message
git commit --amend            # Modify last commit
```

### Push & Pull
```bash
git push origin main          # Push to GitHub
git pull origin main          # Pull from GitHub
git fetch origin              # Fetch without merging
```

### View History
```bash
git log --oneline             # Compact history
git log --graph --all         # Visual branch history
git show                      # Show last commit
git show <commit-hash>        # Show specific commit
```

## Branch Operations

```bash
git branch                    # List branches
git branch <name>             # Create branch
git checkout <name>           # Switch branch
git checkout -b <name>        # Create and switch
git merge <branch>            # Merge branch
git branch -d <name>          # Delete branch
```

## Undo Operations

```bash
git checkout -- <file>        # Discard changes in file
git reset HEAD <file>         # Unstage file
git reset --soft HEAD~1       # Undo commit, keep changes
git reset --hard HEAD~1       # Undo commit, discard changes
git revert <commit>           # Create new commit that undoes
```

## Remote Operations

```bash
git remote -v                 # List remotes
git remote add origin <url>   # Add remote
git remote remove origin      # Remove remote
git remote set-url origin <url> # Change remote URL
```

## Useful Aliases

Add to `~/.gitconfig`:

```ini
[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    unstage = reset HEAD --
    last = log -1 HEAD
    visual = log --graph --oneline --all
```

## Conventional Commit Format

```
<type>: <subject>

<body>

<footer>
```

### Types
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `style:` Formatting
- `refactor:` Code restructuring
- `test:` Adding tests
- `chore:` Maintenance

### Example
```
feat: add user authentication

- Implemented JWT token generation
- Added login/logout endpoints
- Created user session management

Closes #123
```

## Emergency Recovery

### Accidentally committed sensitive data
```bash
# Before push
git rm --cached <file>
git commit --amend
git push origin main

# After push - ROTATE CREDENTIALS FIRST!
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch <file>" \
  --prune-empty --tag-name-filter cat -- --all
git push origin --force --all
```

### Lost commits
```bash
git reflog                    # Find lost commits
git checkout <commit-hash>    # Recover commit
git cherry-pick <commit>      # Apply specific commit
```

## GitHub Specific

### Personal Access Token
1. Go to: https://github.com/settings/tokens
2. Generate new token (classic)
3. Select scopes: `repo`, `workflow`
4. Use as password when pushing

### Clone Repository
```bash
git clone https://github.com/Piya0412/SRE-agent.git
cd SRE-agent
```

### Fork Workflow
```bash
git remote add upstream <original-repo-url>
git fetch upstream
git merge upstream/main
```

## Best Practices

✅ Commit frequently (end of each task)  
✅ Write clear commit messages  
✅ Never commit secrets or credentials  
✅ Pull before push to avoid conflicts  
✅ Use branches for features  
✅ Review changes before committing  
✅ Keep commits atomic (one logical change)  
✅ Push daily to backup progress  

## Project Specific

### This Repository
- **Main branch:** `main`
- **Remote:** `origin` → https://github.com/Piya0412/SRE-agent.git
- **Commit style:** Conventional commits
- **Protected files:** .env, logs/, .aws/, credentials

### Ignored Files
See `.gitignore` for complete list:
- Python: `__pycache__/`, `*.pyc`, `.venv/`
- Logs: `logs/`, `*.log`
- Secrets: `.env`, `.api_key_local`, `.s3_bucket_name`
- AWS: `.aws/`, `credentials`
- Temp: `*.tmp`, `.cache/`

---

**Quick Help:** `git --help` or `git <command> --help`  
**Repository:** https://github.com/Piya0412/SRE-agent  
**Documentation:** See `GIT_WORKFLOW.md` for detailed workflows
