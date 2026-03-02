#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="${ROOT_DIR}/.tmp-docc"
OUT_DIR="${ROOT_DIR}/public"

REPOS=(
  "pagina_web"
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
  if git clone --depth 1 "https://github.com/KreatioLab/${repo}.git" "$WORK_DIR/$repo" >/dev/null 2>&1; then
    return 0
  fi
  git clone --depth 1 "https://github.com/ferquintana84/${repo}.git" "$WORK_DIR/$repo" >/dev/null
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

  pushd "$WORK_DIR/$repo" >/dev/null
  mkdir -p "$output_dir"
  swift package --allow-writing-to-directory "$output_dir" \
    generate-documentation \
    --target "$target" \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path "docs/$repo" \
    --output-path "$output_dir"
  popd >/dev/null
}

for repo in "${REPOS[@]}"; do
  echo "==> Cloning ${repo}"
  clone_repo "$repo"

done

# Generate DocC from Swift packages
build_swift_docc "TutorialsKreatioLab" "TutorialsKreatioLab"
build_swift_docc "KreatioDocs" "KreatioDocs"
build_swift_docc "pagina_web" "KreatioDocs"

# Include already-generated static DocC sites
for static_repo in "tutorialskreatiodocs" "tutorialesdocc"; do
  mkdir -p "$OUT_DIR/docs/$static_repo"
  rsync -a --delete --exclude '.git' --exclude 'CNAME' "$WORK_DIR/$static_repo/" "$OUT_DIR/docs/$static_repo/"
  rewrite_static_docc_base_path "$OUT_DIR/docs/$static_repo" "docs/$static_repo"
done

# Fallback pages for repos without Swift DocC package
emit_fallback_page "landing_kreatiolabai" "Fallback (no DocC package detected)"
emit_fallback_page "KreatioDocs-Fase-Exploracion" "Fallback (content repo, no DocC package detected)"

cat > "$OUT_DIR/index.html" <<'HTML'
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>KreatioLab Docs Hub</title>
  <style>
    :root { --bg:#0b1220; --panel:#121c30; --txt:#eaf0fb; --muted:#a3b1cb; --accent:#22d3ee; --border:#243553; }
    body { margin:0; font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif; background:radial-gradient(circle at top,#16223f,var(--bg)); color:var(--txt); }
    main { max-width:1000px; margin:0 auto; padding:2rem; }
    h1 { font-size:clamp(2rem,4vw,3rem); margin:.3rem 0 1rem; }
    p { color:var(--muted); }
    .grid { display:grid; gap:1rem; grid-template-columns:repeat(auto-fit,minmax(260px,1fr)); }
    a.card { display:block; padding:1rem; border:1px solid var(--border); border-radius:12px; text-decoration:none; color:inherit; background:var(--panel); }
    a.card:hover { border-color:var(--accent); }
    .meta { color:var(--muted); font-size:.95rem; margin-top:.4rem; }
  </style>
</head>
<body>
  <main>
    <h1>KreatioLab Documentation Hub</h1>
    <p>Publicación agregada desde 7 repositorios. Contenido DocC y repos de apoyo en una sola URL.</p>
    <div class="grid">
      <a class="card" href="/docs/TutorialsKreatioLab/"><strong>TutorialsKreatioLab</strong><div class="meta">DocC generado desde fuente Swift</div></a>
      <a class="card" href="/docs/KreatioDocs/"><strong>KreatioDocs</strong><div class="meta">DocC generado desde fuente Swift</div></a>
      <a class="card" href="/docs/pagina_web/"><strong>pagina_web</strong><div class="meta">DocC generado desde fuente Swift</div></a>
      <a class="card" href="/docs/tutorialskreatiodocs/"><strong>tutorialskreatiodocs</strong><div class="meta">DocC estático (publicado)</div></a>
      <a class="card" href="/docs/tutorialesdocc/"><strong>tutorialesdocc</strong><div class="meta">DocC estático (publicado)</div></a>
      <a class="card" href="/docs/KreatioDocs-Fase-Exploracion/"><strong>KreatioDocs-Fase-Exploracion</strong><div class="meta">Fallback (sin paquete DocC)</div></a>
      <a class="card" href="/docs/landing_kreatiolabai/"><strong>landing_kreatiolabai</strong><div class="meta">Fallback (sin paquete DocC)</div></a>
    </div>
  </main>
</body>
</html>
HTML

cp "$OUT_DIR/index.html" "$ROOT_DIR/index.html"
rm -rf "$ROOT_DIR/docs"
cp -R "$OUT_DIR/docs" "$ROOT_DIR/docs"
printf "\n# GitHub Pages static publish\n" > "$ROOT_DIR/.nojekyll"

echo "Done: updated index.html and docs/"
