# Git Workflow Guide

## Daily Workflow

### End of Day Commit

```bash
cd ~/projects/SRE-agent

# Check what changed
git status

# Stage all changes
git add .

# Commit with descriptive message
git commit -m "feat: Day N complete - [brief description]

- Key accomplishment 1
- Key accomplishment 2
- Key accomplishment 3

Technical highlights:
- Detail 1
- Detail 2

Time investment: X hours
Status: [current status]"

# Push to GitHub
git push origin main
```

## Feature Branch Workflow (Optional)

```bash
# Create feature branch
git checkout -b feature/gateway-setup

# Work on feature...

# Commit changes
git add .
git commit -m "feat: implement gateway configuration"

# Push feature branch
git push -u origin feature/gateway-setup

# Merge to main (after testing)
git checkout main
git merge feature/gateway-setup
git push origin main
```

## Checking History

```bash
# View commit history
git log --oneline

# View detailed history
git log --graph --oneline --all

# View changes in last commit
git show

# View changes in specific file
git log -p backend/servers/retrieve_api_key.py
```

## Undoing Changes

```bash
# Undo uncommitted changes to a file
git checkout -- filename

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1
```

## Best Practices

- **Commit frequently:** End of each major task
- **Write clear messages:** Follow conventional commits format
- **Never commit secrets:** Always check .gitignore
- **Push daily:** Protect progress against loss
- **Use branches:** For experimental features

## Conventional Commit Format

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code formatting
- `refactor:` Code restructuring
- `test:` Adding tests
- `chore:` Maintenance tasks

## Emergency Recovery

If you accidentally commit sensitive data:

```bash
# Remove file from last commit
git rm --cached .env
git commit --amend

# Force push (careful!)
git push origin main --force
```

**Note:** If sensitive data was pushed, rotate credentials immediately!
