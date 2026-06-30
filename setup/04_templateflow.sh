#!/bin/bash
# Phase 2.5 — pre-download TemplateFlow templates to $TEMPLATEFLOW_HOME (login node).
# Compute nodes can't fetch at runtime — missing templates are the #1 cause of
# BIDS-App crashes on HPC. Jobs bind this dir in read-only.
set -euo pipefail
source "$(dirname "$0")/config.sh"

module load miniconda3
source activate "$CONDA_ENV"
python -c "import templateflow" 2>/dev/null || pip install --quiet templateflow

export TEMPLATEFLOW_HOME
echo "[`date`] downloading templates into $TEMPLATEFLOW_HOME"
python - <<'PY'
from templateflow.api import get
# Covers sMRIPrep / fMRIPrep / QSIPrep / ASLPrep defaults
for tpl in ['MNI152NLin2009cAsym','MNI152NLin6Asym','OASIS30ANTs','fsLR','fsaverage','MNIInfant']:
    print('fetching', tpl, flush=True)
    get(tpl)
print('DONE')
PY
echo "[`date`] templateflow populated:"
du -sh "$TEMPLATEFLOW_HOME"
ls "$TEMPLATEFLOW_HOME"
