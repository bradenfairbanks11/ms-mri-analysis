#!/bin/bash
#SBATCH --job-name=msmri_smriprep
#SBATCH --output=/nobackup/autodelete/usr/bradenf4/ms_dataset/logs/%x_%j.out
#SBATCH --error=/nobackup/autodelete/usr/bradenf4/ms_dataset/logs/%x_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=8:00:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=bradenfairbanks@gmail.com
# =============================================================================
# Phase 3, Modality 1 (Anatomical) — sMRIPrep, PILOT sub-0040
#
# Produces the anatomical reference everything else registers to:
#   - bias-corrected, skull-stripped T1w
#   - brain mask
#   - GM/WM/CSF tissue segmentation
#   - normalization (transforms) to MNI152NLin2009cAsym
# fMRIPrep / QSIPrep / ASLPrep later REUSE these outputs (--derivatives).
#
# Run (pilot):   sbatch slurm/anatomical.sh
# Scale to all:  sbatch --array=0-27%4 slurm/anatomical.sh   (see SUBJECTS block)
# =============================================================================
set -euo pipefail
source "$(cd "$(dirname "$0")/../setup" && pwd)/config.sh"

module load "$APPTAINER_MODULE"

# ---- pick subject: array index -> sub label, else default pilot ----
if [[ -n "${SLURM_ARRAY_TASK_ID:-}" ]]; then
    mapfile -t SUBJECTS < <(cd "$RAW" && ls -d sub-* | sed 's/sub-//')
    LABEL=${SUBJECTS[$SLURM_ARRAY_TASK_ID]}
else
    LABEL=${1:-0040}
fi
echo "[`date`] sMRIPrep on sub-${LABEL} (host $(hostname))"

OUT=$DERIV/smriprep
WD=$WORK/smriprep
mkdir -p "$OUT" "$WD"

# License + TemplateFlow are passed in by bind (compute node has no internet)
export APPTAINERENV_TEMPLATEFLOW_HOME=/opt/templateflow

apptainer run --cleanenv \
    -B "$RAW":/data:ro \
    -B "$OUT":/out \
    -B "$WD":/work \
    -B "$TEMPLATEFLOW_HOME":/opt/templateflow \
    -B "$FS_LICENSE":/opt/freesurfer/license.txt:ro \
    "$CONTAINERS/smriprep.sif" \
        /data /out participant \
        --participant-label "$LABEL" \
        -w /work \
        --output-spaces MNI152NLin2009cAsym T1w \
        --fs-license-file /opt/freesurfer/license.txt \
        --nprocs 8 --omp-nthreads 8 --mem-gb 30 \
        --fs-no-reconall            # PILOT: skip surfaces for speed (~30-60 min).
                                    # For the real run, DELETE this line to get
                                    # FreeSurfer surfaces (recon-all, several hrs).

echo "[`date`] DONE. Key outputs:"
ls -1 "$OUT/sub-${LABEL}/anat/" 2>/dev/null | grep -E 'desc-(preproc_T1w|brain_mask)|dseg|probseg' || true
echo "QC report: $OUT/sub-${LABEL}.html"
