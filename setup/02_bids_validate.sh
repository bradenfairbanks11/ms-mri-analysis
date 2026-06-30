#!/bin/bash
# Phase 2.2 — validate the BIDS dataset (login node; pulls validator image once).
set -euo pipefail
source "$(dirname "$0")/config.sh"

module load "$APPTAINER_MODULE"
export APPTAINER_CACHEDIR=$COMPUTE_ROOT/.apptainer_cache
VAL=$CONTAINERS/bids-validator.sif
[[ -s "$VAL" ]] || apptainer build "$VAL" docker://bids/validator:latest

# Read-only bind of the raw dataset; validator only needs metadata + structure.
apptainer run -B "$RAW":/data:ro "$VAL" /data 2>&1 | tee "$LOGS/bids_validate.log"
echo "[`date`] validation log: $LOGS/bids_validate.log"
