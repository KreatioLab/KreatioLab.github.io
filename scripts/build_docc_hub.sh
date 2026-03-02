#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="${ROOT_DIR}/.tmp-docc"
OUT_DIR="${ROOT_DIR}/public"

REPOS=(
  "TutorialsKreatioLab"
  "tutorialskreatiodocs"
  "KreatioDocs"
  "tutorialesdocc"
  "landing_kreatiolabai"
  "KreatioDocs-Fase-Exploracion"
)

rm -rf "$WORK_DIR" "$OUT_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR/docs"

clone_repo() {
  local repo="$1"
  local org_url="https://github.com/KreatioLab/${repo}.git"
  local user_url="https://github.com/ferquintana84/${repo}.git"
  if [[ -n "${REPO_ACCESS_TOKEN:-}" ]]; then
    org_url="https://x-access-token:${REPO_ACCESS_TOKEN}@github.com/KreatioLab/${repo}.git"
    user_url="https://x-access-token:${REPO_ACCESS_TOKEN}@github.com/ferquintana84/${repo}.git"
  fi

  if git clone --depth 1 "$org_url" "$WORK_DIR/$repo" >/dev/null 2>&1; then return 0; fi
  if git clone --depth 1 "$user_url" "$WORK_DIR/$repo" >/dev/null 2>&1; then return 0; fi
  return 1
}

rewrite_static_docc_base_path() {
  local target_dir="$1"
  local base_path="$2"

  find "$target_dir" -name '*.html' -type f -print0 | xargs -0 perl -0pi -e "
    s#var baseUrl = \"/\"#var baseUrl = \"/${base_path}/\"#g;
    s#href=\"/favicon\\.ico\"#href=\"/${base_path}/favicon.ico\"#g;
    s#href=\"/favicon\\.svg\"#href=\"/${base_path}/favicon.svg\"#g;
    s#src=\"/js/#src=\"/${base_path}/js/#g;
    s#href=\"/css/#href=\"/${base_path}/css/#g;
  "
}

emit_fallback_page() {
  local repo="$1"
  local status="$2"
  local readme_path="$WORK_DIR/$repo/README.md"
  local target_dir="$OUT_DIR/docs/$repo"

  mkdir -p "$target_dir"
  local readme_snippet="No README found."
  if [[ -f "$readme_path" ]]; then
    readme_snippet="$(sed -n '1,80p' "$readme_path" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
  fi

  cat > "$target_dir/index.html" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${repo}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif; margin: 2rem; line-height: 1.5; }
    .status { padding: .4rem .7rem; border-radius: 999px; background: #f2f4f7; display: inline-block; }
    pre { background: #0f172a; color: #e2e8f0; padding: 1rem; border-radius: .7rem; overflow: auto; }
    a { color: #0f62fe; }
  </style>
</head>
<body>
  <h1>${repo}</h1>
  <p class="status">${status}</p>
  <p>This repository does not currently expose a Swift DocC package. Showing README preview as fallback.</p>
  <p><a href="https://github.com/KreatioLab/${repo}">Open repository</a></p>
  <h2>README preview</h2>
  <pre>${readme_snippet}</pre>
</body>
</html>
HTML
}

build_swift_docc() {
  local repo="$1"
  local target="$2"
  local output_dir="$OUT_DIR/docs/$repo"

  if [[ ! -d "$WORK_DIR/$repo" ]]; then
    emit_fallback_page "$repo" "Fallback (repository not accessible in CI)"
    return 0
  fi

  pushd "$WORK_DIR/$repo" >/dev/null
  mkdir -p "$output_dir"
  if ! swift package --allow-writing-to-directory "$output_dir" \
    generate-documentation \
    --target "$target" \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path "docs/$repo" \
    --output-path "$output_dir"; then
    popd >/dev/null
    emit_fallback_page "$repo" "Fallback (DocC generation failed in CI)"
    return 0
  fi
  popd >/dev/null
}

for repo in "${REPOS[@]}"; do
  echo "==> Cloning ${repo}"
  if ! clone_repo "$repo"; then
    echo "WARN: could not clone ${repo}; creating fallback page"
    emit_fallback_page "$repo" "Fallback (repository not accessible in CI)"
  fi
done

# Generate DocC from Swift packages
build_swift_docc "TutorialsKreatioLab" "TutorialsKreatioLab"
build_swift_docc "KreatioDocs" "KreatioDocs"

# Include already-generated static DocC sites
for static_repo in "tutorialskreatiodocs" "tutorialesdocc"; do
  if [[ ! -d "$WORK_DIR/$static_repo" ]]; then
    emit_fallback_page "$static_repo" "Fallback (repository not accessible in CI)"
    continue
  fi
  mkdir -p "$OUT_DIR/docs/$static_repo"
  rsync -a --delete --exclude '.git' --exclude 'CNAME' "$WORK_DIR/$static_repo/" "$OUT_DIR/docs/$static_repo/"
  rewrite_static_docc_base_path "$OUT_DIR/docs/$static_repo" "docs/$static_repo"
done

# Fallback pages for repos without Swift DocC package
if [[ -d "$WORK_DIR/landing_kreatiolabai" ]]; then
  emit_fallback_page "landing_kreatiolabai" "Fallback (no DocC package detected)"
fi
if [[ -d "$WORK_DIR/KreatioDocs-Fase-Exploracion" ]]; then
  emit_fallback_page "KreatioDocs-Fase-Exploracion" "Fallback (content repo, no DocC package detected)"
fi

cat > "$OUT_DIR/index.html" <<'HTML'
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>KreatioLab</title>
  <meta http-equiv="refresh" content="0; url=/docs/KreatioDocs/documentation/kreatiodocs/">
  <script>
    window.location.replace('/docs/KreatioDocs/documentation/kreatiodocs/');
  </script>
</head>
<body>
  <p>Redirigiendo a la documentación principal de KreatioLab:
    <a href="/docs/KreatioDocs/documentation/kreatiodocs/">abrir ahora</a>.
  </p>
</body>
</html>
HTML

cp "$OUT_DIR/index.html" "$ROOT_DIR/index.html"
rm -rf "$ROOT_DIR/docs"
cp -R "$OUT_DIR/docs" "$ROOT_DIR/docs"
printf "\n# GitHub Pages static publish\n" > "$ROOT_DIR/.nojekyll"
rm -rf "$ROOT_DIR/.tmp-docc" "$ROOT_DIR/public"

echo "Done: updated index.html and docs/"
