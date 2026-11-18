#!/usr/bin/env bash
# fill_site.sh — publish ALL of My_Notes into this Hugo site.
#
#   ./fill_site.sh                 use ../My_Notes (your local working copy)
#   ./fill_site.sh /path/to/notes  use another notes folder
#   ./fill_site.sh --pull          git pull the notes first
#
# What it does:
#   * Markdown (.md / .MD)  -> content/<same path>.md
#       - README.md becomes _index.md (the section page for that folder)
#       - every folder without a README gets a generated _index.md
#       - front matter is added/repaired (title, '...' closer, dates, drafts)
#   * Every other file (images, pdf, mp4, html, ...) -> static_notes/<same path>
#       so it is served at /<same path>. The render hooks in
#       layouts/_markup/ rewrite relative image/link paths to those URLs.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

PULL=0
NOTES=""
for arg in "$@"; do
    case "$arg" in
        --pull) PULL=1 ;;
        -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
        *) NOTES="$arg" ;;
    esac
done
NOTES="${NOTES:-../My_Notes}"
CONTENT="content"
STATIC="static_notes"
REPO="git@github.com:Benjamin-Italiaander/My_Notes.git"

# --- Get the notes ------------------------------------------------------------
if [ ! -d "$NOTES" ]; then
    echo "Notes folder '$NOTES' not found, cloning $REPO ..."
    git clone "$REPO" "$NOTES"
elif [ "$PULL" -eq 1 ] && [ -d "$NOTES/.git" ]; then
    git -C "$NOTES" pull --ff-only
fi
NOTES="$(readlink -f "$NOTES")"
echo "Source: $NOTES"

# --- Build into a staging folder ---------------------------------------------
# Everything is generated in a temp folder first and synced over at the end,
# so a running `hugo server` only sees the files that actually changed.
FINAL_CONTENT="content"
FINAL_STATIC="static_notes"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
CONTENT="$STAGE/content"
STATIC="$STAGE/static_notes"
mkdir -p "$CONTENT" "$STATIC"

# Turn "my_dir-name" into "My Dir Name"
# (known abbreviations stay upper-case: Cli -> CLI, Ssh -> SSH, ...)
pretty() {
    printf '%s' "$1" | tr '_-' '  ' | sed 's/\b./\u&/g' \
        | sed -E 's/\b(Cli|Ssh|Ssl|Kvm|Gpg|Pgp|Otp|Pam|Piv|Css|Html|Rs232|Nl|En)\b/\U&/g'
}

# Skip: git data, hidden files, vim swap files
find_notes() {
    find "$NOTES" -name .git -prune -o -type f ! -name '.*' ! -name '*.swp' "$@" -print0
}

# --- Assets: everything that is not markdown ----------------------------------
n_assets=0
while IFS= read -r -d '' src; do
    rel="${src#"$NOTES/"}"
    mkdir -p "$STATIC/$(dirname "$rel")"
    cp "$src" "$STATIC/$rel"
    n_assets=$((n_assets + 1))
done < <(find_notes ! -iname '*.md')

# --- Markdown -----------------------------------------------------------------
# awk program that normalises a note into Hugo-ready markdown:
#   - existing YAML front matter: '...' closer -> '---', add missing title,
#     zero-pad dates (2022-9-7 -> 2022-09-07), year-only dates -> YYYY-01-01,
#     draft: true -> false (everything gets published)
#   - no front matter: create one, title = first '# heading' or the filename
read -r -d '' AWK_FM <<'AWK' || true
function fixdate(line,   v, q, a, n) {
    v = line; sub(/^date:[ \t]*/, "", v)
    q = ""; if (v ~ /^["']/) { q = substr(v, 1, 1); v = substr(v, 2, length(v) - 2) }
    if (v ~ /^[0-9][0-9][0-9][0-9]$/) v = v "-01-01"
    if (v ~ /^[0-9]+-[0-9]+-[0-9]+$/) {
        n = split(v, a, "-")
        v = sprintf("%04d-%02d-%02d", a[1], a[2], a[3])
    }
    return "date: " q v q
}
{ sub(/\r$/, ""); L[++n] = $0 }
# key of a top-level YAML line ("title: x" -> "title"), "" for continuation lines
function key(line) { return (line ~ /^[A-Za-z_][A-Za-z0-9_-]*:/) ? substr(line, 1, index(line, ":") - 1) : "" }
# read a front matter block starting at line i (a "---"); store it as block b
function readblock(i, b,   k, cur) {
    cnt[b] = 0
    for (i++; i <= n && L[i] != "---" && L[i] != "..."; i++) {
        k = key(L[i]); if (k != "") cur = k
        cnt[b]++; FL[b, cnt[b]] = L[i]; FK[b, cnt[b]] = cur
        if (k != "") has[b, k] = 1
    }
    return i + 1            # first line after the closing ---
}
END {
    if (n >= 1 && L[1] == "---") {
        start = readblock(1, 1); nblk = 1
        # A second front matter block right after the first (blank lines
        # allowed) is merged in; its keys win over the first block's.
        j = start; while (j <= n && L[j] ~ /^[ \t]*$/) j++
        if (j <= n && L[j] == "---") {
            m = j + 1; while (m <= n && L[m] ~ /^[ \t]*$/) m++
            if (m <= n && key(L[m]) != "") { start = readblock(j, 2); nblk = 2 }
        }
        print "---"
        for (b = 1; b <= nblk; b++)
            for (i = 1; i <= cnt[b]; i++) {
                k = FK[b, i]
                if (b == 1 && nblk == 2 && has[2, k]) continue
                line = FL[b, i]
                if (line ~ /^title:/) hastitle = 1
                if (line ~ /^linkTitle:/) haslink = 1
                if (line ~ /^date:/) line = fixdate(line)
                if (line ~ /^draft:[ \t]*true/) line = "draft: false"
                print line
            }
        if (!hastitle) printf "title: \"%s\"\n", deftitle
        if (linktitle != "" && !haslink) printf "linkTitle: \"%s\"\n", linktitle
        print "---"
        for (i = start; i <= n; i++) print L[i]
    } else {
        # No front matter: create one; title = first "# heading" or filename
        t = deftitle
        for (i = 1; i <= n; i++) if (L[i] ~ /^# /) { t = substr(L[i], 3); break }
        gsub(/"/, "\\\"", t)
        printf "---\ntitle: \"%s\"\n", t
        if (linktitle != "") printf "linkTitle: \"%s\"\n", linktitle
        printf "---\n\n"
        for (i = 1; i <= n; i++) print L[i]
    }
}
AWK

n_pages=0
while IFS= read -r -d '' src; do
    rel="${src#"$NOTES/"}"
    dir="$(dirname "$rel")"
    base="$(basename "$rel")"
    stem="${base%.*}"

    if [ "$base" = "README.md" ] || [ "$base" = "readme.md" ]; then
        dest="$CONTENT/$dir/_index.md"
        if [ "$dir" = "." ]; then deftitle="Home"; else deftitle="$(pretty "$(basename "$dir")")"; fi
    else
        dest="$CONTENT/$dir/$stem.md"          # also turns .MD into .md
        deftitle="$(pretty "$stem")"
    fi
    dest="${dest/\/.\//\/}"
    mkdir -p "$(dirname "$dest")"
    linktitle=""
    [ "$(basename "$dest")" = "_index.md" ] && [ "$dir" != "." ] && linktitle="$deftitle"
    awk -v deftitle="$deftitle" -v linktitle="$linktitle" "$AWK_FM" "$src" > "$dest"
    n_pages=$((n_pages + 1))
done < <(find_notes -iname '*.md')

# --- Section pages for folders without a README -------------------------------
# (Hugo only treats a folder as a browsable section when it has _index.md)
while IFS= read -r -d '' d; do
    [ -e "$d/_index.md" ] && continue
    # only folders that (somewhere below) contain markdown
    [ -n "$(find "$d" -name '*.md' -print -quit)" ] || continue
    printf -- '---\ntitle: "%s"\ngenerated: true\n---\n' "$(pretty "$(basename "$d")")" > "$d/_index.md"
done < <(find "$CONTENT" -type d -print0)
[ -e "$CONTENT/_index.md" ] || printf -- '---\ntitle: "Home"\n---\n' > "$CONTENT/_index.md"

# --- Folders with exactly one note: show that note on the folder page -------
# Linux/benchmark/benchmark_writespeed.md  ->  shown at /Linux/benchmark/
#   * no README:   the note becomes the folder page
#   * with README: the README text comes first, the note follows below it
# The note's old URL keeps working (Hugo alias = redirect to the folder).
fm_body() { awk 'NR == 1 { next } !d && $0 == "---" { d = 1; next } d' "$1"; }
fm_with() {  # FILE ALIAS LINKTITLE: front matter of FILE + alias/collapsed/linkTitle
    awk -v alias="$2" -v lt="$3" '
        NR == 1 { print; next }
        !done && $0 == "---" {
            if (!haslt) printf "linkTitle: \"%s\"\n", lt
            if (old != "") { sub(/\][ \t]*$/, "", old); printf "aliases: %s, \"%s\"]\n", old, alias }
            else printf "aliases: [\"%s\"]\n", alias
            printf "collapsed: true\n"
            sp = alias; sub(/\/$/, "", sp); printf "sourcePath: \"%s\"\n", sp
            print; done = 1; next
        }
        !done && /^linkTitle:/ { haslt = 1 }
        !done && /^aliases:/ { old = $0; sub(/^aliases:[ \t]*/, "", old); next }
        !done && /^generated:/ { next }
        !done { print }
    ' "$1"
}
n_collapsed=0
while IFS= read -r -d '' d; do
    [ "$d" = "$CONTENT" ] && continue
    [ -z "$(find "$d" -mindepth 2 -name '*.md' -print -quit)" ] || continue   # has subfolders
    mapfile -d '' notes < <(find "$d" -maxdepth 1 -type f -name '*.md' ! -name '_index.md' -print0)
    if grep -q '^generated: true$' "$d/_index.md"; then
        # no README: AI translations don't count, so a note + its translation
        # still counts as a single note (the translation stays a page of its own)
        originals=()
        for n in "${notes[@]}"; do
            grep -q '^translated_by_ai: true' "$n" || originals+=("$n")
        done
        notes=("${originals[@]}")
    elif [ "${#notes[@]}" -eq 1 ] && grep -q '^translated_by_ai: true' "${notes[0]}"; then
        continue   # README + only its translation: keep the translation as its own page
    fi
    [ "${#notes[@]}" -eq 1 ] || continue
    note="${notes[0]}"; idx="$d/_index.md"
    rel="${note#"$CONTENT/"}"; alias="/${rel%.md}/"; alias="${alias// /-}"
    lt="$(pretty "$(basename "$d")")"
    if grep -q '^generated: true$' "$idx"; then
        { fm_with "$note" "$alias" "$lt"; fm_body "$note"; } > "$idx.new"
    else
        { fm_with "$idx" "$alias" "$lt"; fm_body "$idx"; printf '\n\n---\n\n'; fm_body "$note"; } > "$idx.new"
    fi
    mv "$idx.new" "$idx"; rm "$note"
    n_collapsed=$((n_collapsed + 1))
done < <(find "$CONTENT" -depth -type d -print0)
echo "Merged $n_collapsed single-note folders into their folder page"

# --- Folders that only contain one subfolder absorb it ------------------------
# Linux/backup/tape/*.md  ->  Linux/backup/*.md   (chains are flattened fully)
# Every moved page keeps working: its old URL redirects (alias), relative
# images/links resolve from its original folder (sourceDir), and other notes
# linking to it are still found (sourcePath). A parent folder with its own
# README text is left alone.
fm_get() {
    awk -v k="$2" 'NR == 1 { next } $0 == "---" { exit }
        index($0, k ":") == 1 { v = substr($0, length(k) + 2); sub(/^[ \t]+/, "", v); print v; exit }' "$1"
}
fm_set() {  # FILE KEY YAML-VALUE  (replace or add a front matter key)
    awk -v k="$2" -v v="$3" '
        NR == 1 { print; next }
        !done && $0 == "---" { if (!set) print k ": " v; print; done = 1; next }
        !done && index($0, k ":") == 1 { print k ": " v; set = 1; next }
        { print }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}
page_url() {  # content-relative .md path -> site URL
    local r="${1%.md}"
    case "$r" in _index) r="" ;; */_index) r="${r%/_index}" ;; esac
    r="/$r/"; r="${r//\/\//\/}"; printf '%s' "${r// /-}"
}
n_lifted=0
while IFS= read -r -d '' p; do
    [ -d "$p" ] && [ "$p" != "$CONTENT" ] || continue
    [ -z "$(find "$p" -maxdepth 1 -type f -name '*.md' ! -name '_index.md' -print -quit)" ] || continue
    mapfile -d '' subs < <(find "$p" -mindepth 1 -maxdepth 1 -type d -print0)
    [ "${#subs[@]}" -eq 1 ] && [ -f "${subs[0]}/_index.md" ] || continue
    [ -z "$(fm_body "$p/_index.md" | tr -d '[:space:]')" ] || continue
    c="${subs[0]}"
    while IFS= read -r -d '' f; do
        rel="${f#"$CONTENT/"}"
        [ -n "$(fm_get "$f" sourceDir)" ] || fm_set "$f" sourceDir "\"/$(dirname "$rel")/\""
        if [ -z "$(fm_get "$f" sourcePath)" ]; then
            case "$rel" in */_index.md) sp="/$(dirname "$rel")" ;; *) sp="/${rel%.md}" ;; esac
            fm_set "$f" sourcePath "\"$sp\""
        fi
        cur="$(fm_get "$f" aliases)"
        if [ -z "$cur" ]; then fm_set "$f" aliases "[\"$(page_url "$rel")\"]"
        else fm_set "$f" aliases "${cur%]}, \"$(page_url "$rel")\"]"; fi
    done < <(find "$c" -name '*.md' -print0)
    fm_set "$c/_index.md" linkTitle "\"$(pretty "$(basename "$p")")\""
    mv "$c/_index.md" "$p/_index.md"
    find "$c" -mindepth 1 -maxdepth 1 -exec mv -t "$p" {} +
    rmdir "$c"
    n_lifted=$((n_lifted + 1))
done < <(find "$CONTENT" -depth -type d -print0)
echo "Lifted $n_lifted single-subfolder folders into their parent"

# --- Site index page (gen_site_index.sh writes into ./content) ----------------
if [ -x ./gen_site_index.sh ]; then
    ( cd "$STAGE" && "$OLDPWD/gen_site_index.sh" >/dev/null )
fi

# --- Sync staging -> real folders (only changed files are touched) ------------
mkdir -p "$FINAL_CONTENT" "$FINAL_STATIC"
rsync -a --delete --checksum "$CONTENT/" "$FINAL_CONTENT/"
rsync -a --delete --checksum "$STATIC/" "$FINAL_STATIC/"

echo "Published $n_pages notes to $FINAL_CONTENT/ and $n_assets files to $FINAL_STATIC/"
