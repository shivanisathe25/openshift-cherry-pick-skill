# Cherry-Pick Skill for Claude Code

Automates manual cherry-pick workflow for OpenShift documentation PRs that fail on release branches. It fetches the PR details and commit SHA, and cherry-picks the commit.

## Features

- ✅ **Automated workflow** - Fetches PR, syncs branch, cherry-picks, and creates new PR
- ✅ **Smart conflict resolution** - Auto-resolves deleted file conflicts (common in doc repos)
- ✅ **Safety first** - Shows diff summary and asks for confirmation (optional)
- ✅ **Multi-commit support** - Can cherry-pick single or all commits from a PR
- ✅ **Clear error recovery** - Provides manual steps when conflicts need human intervention
- ✅ **Proper branch naming** - Creates versioned branches (`manual-cp-{PR}-to-{version}`)
- ✅ **Template PR creation** - Auto-fills PR body with required metadata 

## Requirements

- [Claude Code](https://claude.ai/download) installed
- [GitHub CLI (`gh`)](https://cli.github.com/) configured
- `jq` for JSON parsing: `sudo dnf install jq` or `brew install jq`

## Installation

1. **Download the skill:**
   ```bash
   curl -o cherry-pick.sh https://raw.githubusercontent.com/shivanisathe25/openshift-cherry-pick-skill/main/cherry-pick.sh
   ```

2. **Copy to your project:**
   ```bash
   mkdir -p .claude/skills
   mv cherry-pick.sh .claude/skills/
   chmod +x .claude/skills/cherry-pick.sh
   ```

3. **Use in Claude Code:**
   ```bash
   /cherry-pick <PR_number> <target_branch>
   ```
## Usage

```bash
/cherry-pick <PR_number> <target_branch> [--no-confirm] [--all-commits]
```

### Options

- `--no-confirm` - Skip confirmation prompt before pushing (useful for automation)
- `--all-commits` - Cherry-pick all commits from the PR (default: first commit only)

### Examples

**Basic usage:**
```bash
/cherry-pick 113232 build-docs-1.7
```

**Automated workflow (no confirmation):**
```bash
/cherry-pick 113232 build-docs-1.7 --no-confirm
```

**Cherry-pick all commits from a multi-commit PR:**
```bash
/cherry-pick 113232 build-docs-1.7 --all-commits
```

**Fully automated with all commits:**
```bash
/cherry-pick 113232 build-docs-1.7 --no-confirm --all-commits
```

