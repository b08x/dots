#!/usr/bin/env bash
# map_codebase.sh
# Orchestrates graphify + qmd to map a codebase and prepare documentation inputs.
# Usage: bash map_codebase.sh [TARGET_DIR] [--skip-qmd] [--skip-graphify]
#
# Outputs (all in ./graphify-out/):
#   graph.html        - Interactive node graph (browser)
#   GRAPH_REPORT.md   - Key concepts, surprising connections, suggested questions
#   graph.json        - Full graph for follow-up queries
#   callflow.html     - Mermaid architecture / call-flow diagram
#   wiki/             - Agent-crawlable markdown wiki (one file per concept)
#
# Requires:
#   pip install graphifyy
#   npm install -g @tobilu/qmd  (optional, for semantic search index)

set -euo pipefail

TARGET="${1:-.}"
SKIP_QMD=false
SKIP_GRAPHIFY=false

for arg in "$@"; do
  case $arg in
    --skip-qmd)       SKIP_QMD=true ;;
    --skip-graphify)  SKIP_GRAPHIFY=true ;;
  esac
done

echo "=== Codebase Mapper ==="
echo "Target: $TARGET"
echo ""

# ── 1. graphify: build knowledge graph ──────────────────────────────────────
if [ "$SKIP_GRAPHIFY" = false ]; then
  echo "[1/4] Checking graphify..."
  if ! command -v graphify &>/dev/null; then
    echo "  Installing graphify..."
    pip install -U "graphifyy[all]" --quiet
    graphify install 2>/dev/null || true
  fi

  echo "[2/4] Building knowledge graph (this may take a few minutes)..."
  # --wiki produces a per-concept markdown wiki alongside graph.html + graph.json
  graphify "$TARGET" --wiki --no-viz 2>&1 | grep -v "^$" || true

  echo "[3/4] Exporting call-flow / architecture diagram..."
  graphify export callflow-html 2>&1 | grep -v "^$" || true
else
  echo "[1-3/4] Skipping graphify (--skip-graphify)"
fi

# ── 2. qmd: build semantic search index ─────────────────────────────────────
if [ "$SKIP_QMD" = false ]; then
  echo "[4/4] Building qmd semantic search index..."
  if command -v qmd &>/dev/null; then
    qmd collection add "$TARGET" --name codebase 2>/dev/null || true
    qmd context add qmd://codebase "Codebase source files for documentation" 2>/dev/null || true
    qmd update 2>/dev/null || true
    qmd embed 2>/dev/null || true
    echo "  qmd index ready. Use 'qmd query \"<question>\"' for semantic search."
  else
    echo "  qmd not found (npm install -g @tobilu/qmd to enable). Skipping."
  fi
else
  echo "[4/4] Skipping qmd (--skip-qmd)"
fi

echo ""
echo "=== Done ==="
echo ""
echo "Outputs:"
ls -1 graphify-out/ 2>/dev/null || echo "  (check graphify-out/)"
echo ""
echo "Next step: Ask Claude to generate documentation using the GRAPH_REPORT.md,"
echo "  wiki/, and callflow HTML as inputs."
