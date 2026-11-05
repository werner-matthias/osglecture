#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
smoke_root=$(mktemp -d "${TMPDIR:-/tmp}/osglecture-install-XXXXXX")
smoke_root=$(cd "$smoke_root" && pwd -P)
texmf_root="$smoke_root/texmf"
compile_root="$smoke_root/compile"

cleanup() {
  rm -rf "$smoke_root"
}
trap cleanup EXIT

mkdir -p "$compile_root"

cd "$repository_root"
l3build install --texmfhome "$texmf_root"

# macOS exposes /tmp through a /private/var symlink.  Compare kpsewhich results
# against the canonical path so an installed file cannot be mistaken for a
# system-wide copy.
texmf_root=$(cd "$texmf_root" && pwd -P)
export TEXMFHOME="$texmf_root"

require_installed_tex_file() {
  local name=$1
  local resolved
  resolved=$(kpsewhich "$name")
  if [[ -z "$resolved" ]]; then
    echo "Installed file is not visible to kpsewhich: $name" >&2
    return 1
  fi
  case "$resolved" in
    "$texmf_root"/*) ;;
    *)
      echo "kpsewhich found $name outside the smoke-test tree: $resolved" >&2
      return 1
      ;;
  esac
  printf '%-38s %s\n' "$name" "$resolved"
}

tex_files=(
  osgdoc.cls
  osgdoc.sty
  langselect.sty
  lttalk-themeengine.sty
  lttalk-theme-tuc-2019.sty
  osgmodes.sty
  osgmodes-lttalk.sty
  osgmodes-lttalk.lua
  osglecture-series-index.lua
  osglecture-series.sty
  osglecture.cls
  osglecture-project.sty
  osglecture-structure.sty
  osglecture-adapter-beamer.def
  osglecture-profile-scrbook.def
  tagpax.sty
  tagpax-tagpdf-bridge.sty
  tagpax.lua
  tagpax-backend.lua
)

for file in "${tex_files[@]}"; do
  require_installed_tex_file "$file"
done

osgdocmk_launcher="$texmf_root/scripts/osgdocmk/osgdocmk"
osgdocmk_version="$texmf_root/scripts/osgdocmk/lib/OLLM/Version.pm"
osgdocmk_parser="$texmf_root/scripts/osgdocmk/vendor/TOML-Tiny-0.22/lib/TOML/Tiny/Parser.pm"
osgdocmk_preset="$texmf_root/scripts/osgdocmk/definitions/bundle-presets/osg-lecture.toml"

for file in "$osgdocmk_launcher" "$osgdocmk_version" "$osgdocmk_parser" "$osgdocmk_preset"; do
  if [[ ! -f "$file" ]]; then
    echo "Installed osgdocmk file is missing: $file" >&2
    exit 1
  fi
done

perl "$osgdocmk_launcher" --version

mkdir -p "$smoke_root/texmf-cache"
export TEXMFCACHE="$smoke_root/texmf-cache"
export TEXMFVAR="$smoke_root/texmf-cache"

cat >"$compile_root/install-smoke.tex" <<'EOF'
\documentclass[standalone,doctype=script]{osglecture}
\begin{document}
\lecture{Installation smoke test}{install-smoke}
Installed osglecture bundle.
\end{document}
EOF

cd "$compile_root"
lualatex -interaction=nonstopmode -halt-on-error install-smoke.tex
test -s install-smoke.pdf

cd "$repository_root"
l3build uninstall --texmfhome "$texmf_root"

if find "$texmf_root/tex" -type f -print -quit 2>/dev/null | grep -q .; then
  echo "l3build uninstall left package files behind:" >&2
  find "$texmf_root/tex" -type f -print >&2
  exit 1
fi

if find "$texmf_root/scripts/osgdocmk" -type f -print -quit 2>/dev/null | grep -q .; then
  echo "l3build uninstall left osgdocmk files behind:" >&2
  find "$texmf_root/scripts/osgdocmk" -type f -print >&2
  exit 1
fi

echo "Installation smoke test passed."
