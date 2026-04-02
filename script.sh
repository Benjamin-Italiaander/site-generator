#!/usr/bin/env bash

find content/yubikey -maxdepth 1 -type f -name '*.md' -print0 |
while IFS= read -r -d '' file; do
  base="$(basename "$file" .md)"

  # Skip if slug already exists
  if grep -qE '^(slug|url):' "$file"; then
    continue
  fi

  if head -n 1 "$file" | grep -qx '---'; then
    awk -v slug="$base" '
      NR==1 { print; print "slug: \"" slug "\""; next }
      { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    {
      echo "---"
      echo "slug: \"$base\""
      echo "---"
      cat "$file"
    } > "$file.tmp" && mv "$file.tmp" "$file"
  fi
done
