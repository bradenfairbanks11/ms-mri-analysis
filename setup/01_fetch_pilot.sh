#!/bin/bash
# Phase 2.1 — fetch the PILOT subject's annexed data (login node only; needs internet).
# Raw data lives on archive; this populates the git-annex content for sub-0040.
# Run inside tmux: it can take a while. Scale to all subjects later by looping.
set -euo pipefail
source "$(dirname "$0")/config.sh"

module load miniconda3
source activate "$CONDA_ENV"   # datalad + git-annex

PILOT=${1:-sub-0040}
cd "$RAW"
echo "[`date`] datalad get $PILOT into $RAW"
datalad get -J 4 "$PILOT"
echo "[`date`] done. Real fetched size (-L follows annex symlinks; plain du shows only pointers):"
du -shL "$RAW/$PILOT"
echo "annex content present locally:"
git annex find --in=here "$PILOT" | wc -l
