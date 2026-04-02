#!/usr/bin/env bash
set -euo pipefail

NOTES="My_Notes"
CONTENT="content"

# --- Sync My_Notes repo ---
if [ -d "$NOTES/.git" ]; then
    git -C "$NOTES" pull
else
    git clone git@github.com:Benjamin-Italiaander/My_Notes.git "$NOTES"
fi

# --- Static assets ---
cp "$NOTES/avatar.png" "$CONTENT/"
cp -r "$NOTES/slices_of_life/img" "$CONTENT/"

# --- Mirror all .md files into content/ ---
# README.md files become _index.md (Hugo section index pages)
while IFS= read -r src; do
    rel="${src#"$NOTES/"}"
    dest="$CONTENT/${rel/README.md/_index.md}"
    mkdir -p "$(dirname "$dest")"
    # Hugo requires '---' to close front matter; Pandoc uses '...' — normalize it
    # Also zero-pad single-digit days/months in date fields (e.g. 2022-9-7 -> 2022-09-07)
    sed -e 's/^\.\.\.$/---/' \
        -e 's/^\(date:.*[0-9]\)-\([0-9]\)-/\1-0\2-/' \
        -e 's/^\(date:.*\)-\([0-9]\)$/\1-0\2/' \
        "$src" > "$dest"
    # If no front matter, prepend a title derived from the filename
    if ! head -1 "$dest" | grep -q "^---"; then
        title=$(basename "$dest" .md | tr '_-' '  ' | sed 's/\b./\u&/g')
        { echo -e "---\ntitle: \"$title\"\n---\n"; cat "$dest"; } > "$dest.tmp" && mv "$dest.tmp" "$dest"
    fi
done < <(find "$NOTES" -name "*.md" ! -path "*/.git/*")
