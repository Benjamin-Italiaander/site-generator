#!/usr/bin/env bash
# deploy.sh — build the site from My_Notes and publish it to the tlnd-org repo
#             (GitHub Pages, https://tlnd.org/).
#
#   ./deploy.sh             build and publish
#   ./deploy.sh --dry-run   build and make the commit, but don't push anything
#
# Every deploy REPLACES the whole repository: the built site becomes one fresh
# commit without history, force-pushed to the main branch, and all other
# branches and tags in the repo are deleted. Nothing from earlier deploys
# (old pages, old commit authors) stays behind.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

DEPLOY_REPO="git@github.com:Benjamin-Italiaander/tlnd-org.git"
DEPLOY_BRANCH="main"
# Commit identity for the deploy commit (GitHub's private no-reply address)
AUTHOR_NAME="Benjamin Italiaander"
AUTHOR_EMAIL="Benjamin-Italiaander@users.noreply.github.com"

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

# --- 1. Fill content/ from My_Notes ------------------------------------------
./fill_site.sh

# --- 2. Clean build into public/ ---------------------------------------------
echo "Building site..."
rm -rf -- ./public
hugo --minify --destination public
touch public/.nojekyll                  # serve files as-is, no Jekyll processing
# GitHub Pages for tlnd-org is published by this Actions workflow; without it
# the push lands in the repo but the live site never updates.
mkdir -p public/.github/workflows
cp deploy/pages-workflow.yml public/.github/workflows/static.yml
[ -f public/CNAME ] || { echo "public/CNAME is missing (static/CNAME)" >&2; exit 1; }
echo "Built $(find public -name index.html | wc -l) pages ($(du -sh public | cut -f1))."

# --- 3. One fresh commit ------------------------------------------------------
cd public
git init -q -b "$DEPLOY_BRANCH"
git add --all
git -c user.name="$AUTHOR_NAME" -c user.email="$AUTHOR_EMAIL" \
    commit -q -m "Deploy: $(date '+%Y-%m-%d %H:%M')"
git log --format='Commit %h by %an <%ae>: %s' -1

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run: nothing pushed. The commit is in $(pwd)."
    exit 0
fi

# --- 4. Replace the remote repository ----------------------------------------
echo "Pushing to $DEPLOY_REPO ($DEPLOY_BRANCH), replacing its history..."
git push --force "$DEPLOY_REPO" "$DEPLOY_BRANCH:refs/heads/$DEPLOY_BRANCH"

echo "Removing other branches and tags from the remote..."
git ls-remote --heads --tags "$DEPLOY_REPO" | awk '{print $2}' | grep -v '\^{}$' |
while read -r ref; do
    [ "$ref" = "refs/heads/$DEPLOY_BRANCH" ] && continue
    echo "  deleting $ref"
    git push -q "$DEPLOY_REPO" ":$ref"
done

echo "Done: https://tlnd.org/ (GitHub Pages usually updates within a minute or two)"
