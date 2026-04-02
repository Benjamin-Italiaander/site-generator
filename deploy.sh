#!/usr/bin/env bash
set -euo pipefail

DEPLOY_REPO="git@github.com:Benjamin-Italiaander/tlnd-org.git"
DEPLOY_BRANCH="main"

# --- Build site ---
echo "Building site..."
hugo --minify

# --- Deploy public/ to tlnd-org ---
echo "Deploying to $DEPLOY_REPO..."
cd public

if [ ! -d .git ]; then
    git init
    git remote add origin "$DEPLOY_REPO"
fi

git add --all
git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M')"
git push --force origin "HEAD:$DEPLOY_BRANCH"

echo "Done."
