#!/bin/bash
# ---
# name: cherry-pick
# description: Automate cherry-pick from a PR to a target branch
# args: <PR_number> <target_branch> [--no-confirm] [--all-commits]
# example: /cherry-pick 113232 build-docs-1.7
# ---

set -e

# Parse arguments
PR_NUMBER=""
TARGET_BRANCH=""
NO_CONFIRM=false
ALL_COMMITS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-confirm)
            NO_CONFIRM=true
            shift
            ;;
        --all-commits)
            ALL_COMMITS=true
            shift
            ;;
        *)
            if [ -z "$PR_NUMBER" ]; then
                PR_NUMBER="$1"
            elif [ -z "$TARGET_BRANCH" ]; then
                TARGET_BRANCH="$1"
            else
                echo "❌ Unknown argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$PR_NUMBER" ] || [ -z "$TARGET_BRANCH" ]; then
    echo "❌ Usage: /cherry-pick <PR_number> <target_branch> [--no-confirm] [--all-commits]"
    echo "Example: /cherry-pick 113232 build-docs-1.7"
    echo ""
    echo "Options:"
    echo "  --no-confirm   Skip confirmation prompt before pushing"
    echo "  --all-commits  Cherry-pick all commits from PR (default: first commit only)"
    exit 1
fi

echo "🔍 Fetching PR #$PR_NUMBER details..."
PR_DATA=$(gh pr view "$PR_NUMBER" --json title,commits,baseRefName)
PR_TITLE=$(echo "$PR_DATA" | jq -r '.title')

if [ "$ALL_COMMITS" = true ]; then
    COMMIT_SHAS=$(echo "$PR_DATA" | jq -r '.commits[].oid')
    COMMIT_COUNT=$(echo "$COMMIT_SHAS" | wc -l)
    echo "📋 PR: #$PR_NUMBER - $PR_TITLE"
    echo "📌 Commits: $COMMIT_COUNT commit(s)"
    echo "$COMMIT_SHAS" | head -3
    [ "$COMMIT_COUNT" -gt 3 ] && echo "   ... and $(($COMMIT_COUNT - 3)) more"
else
    COMMIT_SHAS=$(echo "$PR_DATA" | jq -r '.commits[0].oid')
    echo "📋 PR: #$PR_NUMBER - $PR_TITLE"
    echo "📌 Commit: $COMMIT_SHAS"
fi

echo "🎯 Target: $TARGET_BRANCH"
echo ""

# Extract version from target branch (e.g., "1.7" from "build-docs-1.7")
VERSION=$(echo "$TARGET_BRANCH" | grep -oP '(?<=build-docs-|gitops-docs-).*' || echo "$TARGET_BRANCH")
NEW_BRANCH="manual-cp-${PR_NUMBER}-to-${VERSION}"

echo "Step 1: Syncing target branch with upstream..."
git checkout "$TARGET_BRANCH" 2>/dev/null || git checkout -b "$TARGET_BRANCH" "origin/$TARGET_BRANCH"
git fetch upstream "$TARGET_BRANCH" || echo "⚠️  No upstream remote, skipping upstream fetch"
git rebase "upstream/$TARGET_BRANCH" 2>/dev/null || echo "⚠️  No upstream, using origin"
git push origin "$TARGET_BRANCH" || echo "⚠️  Already up to date"

echo ""
echo "Step 2: Creating cherry-pick branch: $NEW_BRANCH"
git checkout -b "$NEW_BRANCH" "$TARGET_BRANCH"

echo ""
echo "Step 3: Cherry-picking commit(s)..."

# Function to handle cherry-pick conflicts
handle_conflicts() {
    echo "⚠️  Conflicts detected!"
    echo ""
    echo "Conflicts to resolve:"
    git status --short

    # Get list of deleted files (modify/delete conflicts)
    DELETED_FILES=$(git status --porcelain | grep "^DU " | cut -c4- || true)

    if [ -n "$DELETED_FILES" ]; then
        echo ""
        echo "📝 Auto-resolving: Removing files that don't exist in $TARGET_BRANCH:"
        echo "$DELETED_FILES" | while read -r file; do
            echo "   - $file"
            git rm "$file"
        done
    fi

    # Check if there are other unresolved conflicts
    UNRESOLVED=$(git status --porcelain | grep "^UU " || true)
    if [ -n "$UNRESOLVED" ]; then
        echo ""
        echo "❌ Manual intervention required for merge conflicts:"
        echo "$UNRESOLVED"
        echo ""
        echo "Next steps:"
        echo "1. Resolve conflicts in the files above"
        echo "2. git add <resolved-files>"
        echo "3. git cherry-pick --continue"
        echo "4. git push origin HEAD"
        echo "5. Create PR with: gh pr create --base $TARGET_BRANCH"

        # Clean up on failure
        echo ""
        echo "To abort and clean up: git cherry-pick --abort && git checkout $TARGET_BRANCH && git branch -D $NEW_BRANCH"
        exit 1
    fi

    echo "✅ Conflicts auto-resolved. Continuing cherry-pick..."
    GIT_EDITOR=true git cherry-pick --continue
}

# Cherry-pick commit(s)
CHERRY_PICK_FAILED=false
echo "$COMMIT_SHAS" | while read -r sha; do
    echo "Cherry-picking: $sha"
    if ! git cherry-pick "$sha"; then
        CHERRY_PICK_FAILED=true
        break
    fi
done

if [ "$CHERRY_PICK_FAILED" = true ]; then
    handle_conflicts
else
    echo "✅ Cherry-pick succeeded with no conflicts!"
fi

echo ""
echo "=========================================="
echo "📊 CHANGES SUMMARY"
echo "=========================================="
echo ""
git diff --stat "$TARGET_BRANCH"
echo ""
echo "=========================================="
echo ""

# Show list of modified files
echo "Modified files:"
git diff --name-status "$TARGET_BRANCH"
echo ""

# Ask for confirmation unless --no-confirm is set
if [ "$NO_CONFIRM" = false ]; then
    read -p "🤔 Review the changes above. Push and create PR? (y/n): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "❌ Aborted by user."
        echo ""
        echo "Your changes are committed locally on branch: $NEW_BRANCH"
        echo "To push and create PR manually later:"
        echo "  git push origin HEAD"
        echo "  gh pr create --base $TARGET_BRANCH"
        echo ""
        exit 0
    fi
else
    echo "⚡ Auto-confirming (--no-confirm flag set)"
fi

echo ""
echo "Step 4: Pushing branch to remote..."
git push origin HEAD

echo ""
echo "Step 5: Creating pull request..."

PR_BODY="Manual CP from #$PR_NUMBER to $VERSION

Version(s): $TARGET_BRANCH

Issue: (same as original PR)

QE review: Builds does not have a QE
- [ ] QE has approved this change."

NEW_PR_URL=$(gh pr create \
    --base "$TARGET_BRANCH" \
    --title "$PR_TITLE" \
    --body "$PR_BODY")

echo ""
echo "✅ Manual cherry-pick completed successfully!"
echo ""
echo "📍 Branch: $NEW_BRANCH"
echo "🔗 PR: $NEW_PR_URL"
echo ""
