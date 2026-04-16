#!/usr/bin/env bash
# Render all ArkModelZoo.jl vignettes to HTML, PDF, and GFM Markdown.
# Each model is rendered as a standalone document; outputs go next to the QMD.
#
# Prerequisites: run `julia --project=.. prerender.jl` first to generate plot PNGs.
#
# Usage:
#   ./render_all.sh                  # render all models, all formats
#   ./render_all.sh --html           # HTML only for all models
#   ./render_all.sh --pdf            # PDF only for all models
#   ./render_all.sh --gfm            # GFM Markdown only for all models
#   ./render_all.sh coin flocking    # specific models, all 3 formats

set -euo pipefail
cd "$(dirname "$0")"

DO_HTML=true
DO_PDF=true
DO_GFM=true
MODELS=()

for arg in "$@"; do
    case "$arg" in
        --html) DO_HTML=true;  DO_PDF=false; DO_GFM=false ;;
        --pdf)  DO_HTML=false; DO_PDF=true;  DO_GFM=false ;;
        --gfm)  DO_HTML=false; DO_PDF=false; DO_GFM=true  ;;
        --all)  DO_HTML=true;  DO_PDF=true;  DO_GFM=true  ;;
        --*) echo "Unknown flag: $arg"; exit 1 ;;
        *) MODELS+=("$arg") ;;
    esac
done

if [ ${#MODELS[@]} -eq 0 ]; then
    for d in */; do
        d="${d%/}"
        [ -f "$d/$d.qmd" ] && MODELS+=("$d")
    done
fi

TOTAL=${#MODELS[@]}
echo "=== ArkModelZoo.jl vignette renderer ==="
echo "Models : $TOTAL"
echo "Started: $(date)"
echo ""

FORMATS=()
$DO_HTML && FORMATS+=(html)
$DO_PDF  && FORMATS+=(pdf)
$DO_GFM  && FORMATS+=(gfm)

for fmt in "${FORMATS[@]}"; do
    echo "── Rendering $fmt ──"
    i=0
    failed=()
    for m in "${MODELS[@]}"; do
        i=$((i + 1))
        printf "[%3d/%d] %-30s " "$i" "$TOTAL" "$m"
        if quarto render "$m/$m.qmd" --to "$fmt" 2>/dev/null; then
            echo "✓"
        else
            echo "FAIL"
            failed+=("$m")
        fi
    done
    echo ""
    if [ ${#failed[@]} -gt 0 ]; then
        echo "Failed ($fmt): ${failed[*]}"
    else
        echo "All $TOTAL models rendered to $fmt."
    fi
    echo ""
done

echo "Finished: $(date)"
