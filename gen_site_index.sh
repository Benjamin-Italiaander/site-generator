#!/usr/bin/env bash
set -euo pipefail

CONTENT="content"
OUTPUT="$CONTENT/site-index/_index.md"
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# Extract title from front matter, fall back to filename
get_title() {
    local file="$1"
    local title
    title=$(grep -m1 '^title:' "$file" 2>/dev/null \
        | sed 's/^title:[[:space:]]*//' \
        | tr -d '"' | tr -d "'")
    if [ -z "$title" ]; then
        local base
        base=$(basename "$file" .md)
        base="${base#_}"
        title=$(echo "$base" | tr '_-' '  ' | sed 's/\b\(.\)/\u\1/g')
    fi
    printf '%s' "$title"
}

# Convert content-relative file path to Hugo URL
to_url() {
    local rel="$1"
    rel="${rel%.md}"
    case "$rel" in
        _index)           echo "/" ;;
        */_index)         echo "/${rel%/_index}/" ;;
        */index)          echo "/${rel%/index}/" ;;
        *)                echo "/$rel/" ;;
    esac | sed 's/ /-/g'   # Hugo turns spaces in file names into hyphens
}

# Format a raw path component as a readable section heading
format_section() {
    echo "$1" | tr '_-' '  ' | sed 's/\b\(.\)/\u\1/g'
}

# Collect all pages into tmpfile: section|title|url
while IFS= read -r filepath; do
    rel="${filepath#"$CONTENT/"}"

    # Skip the output file and double-underscore files
    [[ "$filepath" == "$OUTPUT" ]] && continue
    [[ "$(basename "$filepath")" == "__"* ]] && continue

    title=$(get_title "$filepath")
    url=$(to_url "$rel")

    # Top-level section is the first path component
    section=$(echo "$rel" | cut -d'/' -f1)
    # Home page (_index.md at root)
    [ "$section" = "_index.md" ] && section="__home"

    printf '%s|%s|%s\n' "$section" "$title" "$url"
done < <(find "$CONTENT" -name "*.md" | sort) | sort >> "$TMPFILE"

# Write the index page
mkdir -p "$(dirname "$OUTPUT")"
{
    echo '---'
    echo 'title: "Site Index"'
    echo '---'
    echo ''
    echo '# Site Index'
    echo ''
    echo '*All pages on this site, grouped by section.*'
    echo ''

    current_section=""
    while IFS='|' read -r section title url; do
        if [ "$section" != "$current_section" ]; then
            [ -n "$current_section" ] && echo ""
            if [ "$section" = "__home" ]; then
                echo "## Home"; echo ""
            else
                echo "## $(format_section "$section")"; echo ""
            fi
            current_section="$section"
        fi
        echo "- [$title]($url)"
    done < "$TMPFILE"
} > "$OUTPUT"

echo "Generated: $OUTPUT"
