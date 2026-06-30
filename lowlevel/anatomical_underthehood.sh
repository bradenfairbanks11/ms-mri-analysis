#!/bin/bash
#SBATCH --job-name=msmri_anat_lowlevel
#SBATCH --output=/nobackup/autodelete/usr/bradenf4/ms_dataset/logs/%x_%j.out
#SBATCH --error=/nobackup/autodelete/usr/bradenf4/ms_dataset/logs/%x_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=1:30:00
# =============================================================================
# Phase 3, Modality 1 — "OPEN THE HOOD" for the anatomical pipeline.
#
# By hand, reproduce the 3 signature steps sMRIPrep does to make a brain from a
# raw T1w, using the SAME tools sMRIPrep uses (all bundled in smriprep.sif):
#
#   1. N4 bias-field correction   (ANTs N4BiasFieldCorrection)
#   2. skull-strip                (FreeSurfer mri_synthstrip)
#   3. tissue segmentation        (FSL FAST -> CSF/GM/WM)
#
# Then compare your hand-made brain mask to sMRIPrep's desc-brain_mask:
#   - Dice overlap coefficient
#   - an overlay PNG to eyeball where they agree/disagree
#
# Run AFTER slurm/anatomical.sh has finished (it needs sMRIPrep's mask to compare).
# Interactive is fine too:  salloc -c4 --mem=16G -t1:30:00  then  bash lowlevel/anatomical_underthehood.sh
# =============================================================================
set -euo pipefail
source "$(cd "$(dirname "$0")/../setup" && pwd)/config.sh"
module load "$APPTAINER_MODULE"

LABEL=${1:-0040}
SIF=$CONTAINERS/smriprep.sif
LOW=$DERIV/lowlevel/anatomical/sub-${LABEL}
mkdir -p "$LOW"

# Run any bundled tool from the container, with raw data + workspace bound in.
run () { apptainer exec -B "$RAW":/data:ro -B "$LOW":/out -B "$DERIV":/deriv "$SIF" "$@"; }

# --- locate the raw T1w (defaced MPRAGE) ---
T1_HOST=$(find "$RAW/sub-${LABEL}" -path '*anat*' -name "*T1w.nii.gz" | sort | head -1)
[[ -n "$T1_HOST" ]] || { echo "No T1w found for sub-${LABEL}"; exit 1; }
T1=/data/${T1_HOST#$RAW/}
echo "[`date`] raw T1w: $T1_HOST"

# --- STEP 1: N4 bias-field correction -------------------------------------
# MRI has a smooth low-frequency intensity bias from coil sensitivity. N4
# estimates and divides it out so tissue intensities are spatially uniform
# (critical for the segmentation in step 3 to work).
echo "[`date`] step 1/3  N4 bias correction"
run N4BiasFieldCorrection -d 3 -i "$T1" -o /out/T1w_n4.nii.gz -v 1

# --- STEP 2: skull-strip (SynthStrip) -------------------------------------
# Learned (CNN) brain extraction. -m writes the binary brain MASK, which is
# exactly the thing we'll compare to sMRIPrep's desc-brain_mask.
echo "[`date`] step 2/3  SynthStrip skull-strip"
run mri_synthstrip -i /out/T1w_n4.nii.gz -o /out/T1w_brain.nii.gz -m /out/my_brainmask.nii.gz

# --- STEP 3: tissue segmentation (FSL FAST) -------------------------------
# Splits the brain into 3 classes by intensity. For a T1, FAST orders the
# partial-volume maps as: pve_0=CSF, pve_1=GM, pve_2=WM.
echo "[`date`] step 3/3  FSL FAST tissue segmentation"
run fast -t 1 -n 3 -g -o /out/fast /out/T1w_brain.nii.gz

# --- COMPARE: my mask vs sMRIPrep's brain mask ----------------------------
SMRI_MASK_HOST=$(find "$DERIV/smriprep/sub-${LABEL}" -name "*desc-brain_mask.nii.gz" ! -path '*space-MNI*' 2>/dev/null | sort | head -1 || true)
if [[ -z "$SMRI_MASK_HOST" ]]; then
    echo "[warn] sMRIPrep brain mask not found yet — run slurm/anatomical.sh first."
    echo "       Hand-made outputs are in $LOW; skipping the comparison."
    exit 0
fi
echo "[`date`] comparing my_brainmask vs $(basename "$SMRI_MASK_HOST")"
SMRI_MASK=/deriv/${SMRI_MASK_HOST#$DERIV/}

run python - "$SMRI_MASK" <<'PY'
import sys, numpy as np, nibabel as nib
from nilearn.image import resample_to_img
from nilearn import plotting

mine_p, smri_p = "/out/my_brainmask.nii.gz", sys.argv[1]
mine, smri = nib.load(mine_p), nib.load(smri_p)
# put my mask on sMRIPrep's grid so voxels line up
mine_r = resample_to_img(mine, smri, interpolation="nearest")
a = mine_r.get_fdata() > 0.5
b = smri.get_fdata() > 0.5
dice = 2*(a & b).sum() / (a.sum() + b.sum())
print(f"\n==== Brain-mask agreement (sub) ====")
print(f"  my voxels:       {a.sum():,}")
print(f"  sMRIPrep voxels: {b.sum():,}")
print(f"  Dice overlap:    {dice:.4f}")
with open("/out/mask_compare.txt","w") as f:
    f.write(f"dice={dice:.4f}\nmy={int(a.sum())}\nsmriprep={int(b.sum())}\n")
# overlay: sMRIPrep mask (filled) with my mask outline on the bias-corrected T1
disp = plotting.plot_roi(smri_p, bg_img="/out/T1w_n4.nii.gz",
                         alpha=0.4, title=f"sMRIPrep mask + my outline (Dice {dice:.3f})",
                         display_mode="ortho")
disp.add_contours("/out/my_brainmask.nii.gz", levels=[0.5], colors="r")
disp.savefig("/out/mask_compare.png", dpi=130); disp.close()
print("  wrote /out/mask_compare.png and mask_compare.txt")
PY

echo "[`date`] DONE. Hand-made anat + comparison in: $LOW"
ls -1 "$LOW"
