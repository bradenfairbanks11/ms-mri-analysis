#!/bin/bash
# Phase 2.4 — pre-pull BIDS-App containers to $CONTAINERS (login node; needs internet).
# Compute nodes have NO internet, so all images MUST be built here ahead of time.
# Run inside tmux — each build pulls several GB and can take many minutes.
set -euo pipefail
source "$(dirname "$0")/config.sh"

module load "$APPTAINER_MODULE"
# Cache layers on fast scratch, not $HOME (avoid filling the 2 TB home)
export APPTAINER_CACHEDIR=$COMPUTE_ROOT/.apptainer_cache
mkdir -p "$APPTAINER_CACHEDIR" "$CONTAINERS"

build () {  # build <name> <docker-ref>
  local out="$CONTAINERS/$1.sif"
  if [[ -s "$out" ]]; then echo "[skip] $out exists"; return; fi
  echo "[`date`] building $out  <-  docker://$2"
  apptainer build "$out" "docker://$2"
  echo "[`date`] done $out"
}

build smriprep "nipreps/smriprep:${SMRIPREP_VER}"
build fmriprep "nipreps/fmriprep:${FMRIPREP_VER}"
build qsiprep  "pennlinc/qsiprep:${QSIPREP_VER}"
build aslprep  "pennlinc/aslprep:${ASLPREP_VER}"
# QSIRecon (separate app since QSIPrep 26.x) — uncomment when you reach dwi recon:
# build qsirecon "pennlinc/qsirecon:1.1.1"

echo "[`date`] ALL CONTAINERS READY:"
ls -lh "$CONTAINERS"/*.sif
