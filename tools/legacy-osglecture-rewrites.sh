#!/bin/sh
# Apply only low-risk textual rewrites used while migrating legacy AuP chapters.
# The output is deliberately a new file: the legacy source is never overwritten.

set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: $0 LEGACY_MAIN_TEX OUTPUT_TEX" >&2
  exit 2
fi

input=$1
output=$2

if [ ! -f "$input" ]; then
  echo "input does not exist: $input" >&2
  exit 1
fi

if [ -e "$output" ]; then
  echo "refusing to overwrite: $output" >&2
  exit 1
fi

mkdir -p "$(dirname "$output")"
cp "$input" "$output"

perl -0pi -e '
  s/\\section<presentation>/\\section/g;
  s/\\begin\{presitemize\}/\\begin{itemize}/g;
  s/\\end\{presitemize\}/\\end{itemize}/g;
  s/\\mode\*/\\mode<all>/g;
  s/\\begin\{twocolumns\}\[([^,\]]+),T\]/\\begin{twocolumns}[$1,t]/g;
' "$output"

echo "Wrote $output" >&2
echo "Manual migration candidates:" >&2
rg -n \
  -e '\\mode<(article|presentation)>' \
  -e '\\begin\{columns\}' \
  -e '\\againframe' \
  -e '\\begin\{(block|alertblock|exampleblock|literaturelist|catbar|artfigure)\}' \
  -e '\\begin\{minted\}' \
  "$output" >&2 || true

