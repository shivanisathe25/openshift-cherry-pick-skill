# Proposal: Add Cherry-Pick Skill to Team Repo

## Problem Statement
OpenShift doc team frequently needs to backport PRs to release branches (e.g., `build-docs-1.7`, `build-docs-1.8`). The manual process involves:
1. Fetching PR details and commit SHAs
2. Creating a new branch from the target release branch
3. Cherry-picking commits
4. Resolving conflicts (often deleted files)
5. Creating a new PR with proper metadata

This is repetitive and error-prone, especially when handling multiple backports.

## Solution
A Claude Code skill that automates the entire cherry-pick workflow with a single command:
```bash
/cherry-pick <PR_number> <target_branch>
```

## Implementation Details

**What it does:**
- Fetches PR metadata via `gh` CLI
- Syncs target branch with upstream
- Creates a properly-named branch (`manual-cp-{PR}-to-{version}`)
- Cherry-picks the commit(s)
- Auto-resolves deleted file conflicts (common in doc repos)
- Shows diff summary before pushing
- Creates PR with proper template

**Dependencies:**
- GitHub CLI (`gh`) - already used by team
- `jq` - standard JSON parser
- Git - standard

**Safety features:**
- Shows diff before pushing
- Asks for confirmation (can be bypassed with `--no-confirm` flag)
- Provides manual recovery instructions on conflicts

## Known Limitations & Future Improvements

1. **Multi-commit PRs** - Currently only cherry-picks the first commit. Could be enhanced to handle all commits.
2. **Interactive prompt** - The confirmation step breaks full automation. Suggest adding `--no-confirm` flag or removing it.
3. **Hard-coded templates** - PR body template is OpenShift-specific. Should be configurable.

## Questions for Team

1. **Naming convention** - Should this be namespaced? (e.g., `openshift:cherry-pick` or `git:cherry-pick`)
2. **Scope** - Is this too domain-specific, or do other teams have similar backport workflows?
3. **Interactive vs. automated** - Should skills have confirmation prompts, or trust the user?
4. **Configuration** - Should PR templates, branch patterns, etc. be configurable?

## Testing
Tested on openshift-docs repo with PRs #113232, #111506, #111578 across multiple release branches.

## Value Proposition
- **Time savings**: 5-10 minutes per backport → 30 seconds
- **Error reduction**: Automated conflict resolution for common cases
- **Consistency**: Standardized branch naming and PR templates
- **Discoverability**: Skill is self-documenting via `/help`
