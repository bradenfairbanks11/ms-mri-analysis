#!/bin/bash
#SBATCH --job-name=msmri_skullstrip3way
#SBATCH --output=/nobackup/autodelete/usr/bradenf4/ms_dataset/logs/%x_%j.out
#SBATCH --error=/nobackup/autodelete/usr/bradenf4/ms_dataset/logs/%x_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=1:00:00
# =============================================================================
# Modality 1 — bonus: THREE skull-strip philosophies on the same brain.
#
#   1. FSL BET            — intensity / surface evolution (local, fast, no prior)
#   2. FreeSurfer SynthStrip — CNN trained on many brains (learned prior)
#   3. ANTs antsBrainExtraction (from sMRIPrep) — template registration (shape prior)
#
# Reuses the N4-corrected T1w from anatomical_underthehood.sh if present, then
# computes pairwise Dice and a tri-colour overlay so you can SEE where each
# method wins/loses (esp. brainstem + frontal pole).
# Run AFTER slurm/anatomical.sh and the BET low-level step.
# =============================================================================
set -euo pipefail
source "${MSMRI_CONFIG:-/home/bradenf4/ms-mri-analysis/setup/config.sh}"
module load "$APPTAINER_MODULE"

LABEL=${1:-0040}
SIF=$CONTAINERS/smriprep.sif
SS=$CONTAINERS/synthstrip.sif
LOW=$DERIV/lowlevel/anatomical/sub-${LABEL}
mkdir -p "$LOW"
run () { apptainer exec --pwd /out -B "$RAW":/data:ro -B "$LOW":/out -B "$DERIV":/deriv "$SIF" "$@"; }

# --- ensure we have an N4-corrected T1w (reuse if the BET step already made it) ---
if [[ ! -s "$LOW/T1w_n4.nii.gz" ]]; then
  T1_HOST=$(find "$RAW/sub-${LABEL}" -path '*anat*' -name '*T1w.nii.gz' | sort | head -1)
  T1=/data/${T1_HOST#$RAW/}
  echo "[`date`] N4 bias correction"; run N4BiasFieldCorrection -d 3 -i "$T1" -o /out/T1w_n4.nii.gz
fi

# --- method 1: BET (make if missing) ---
[[ -s "$LOW/T1w_brain_mask.nii.gz" ]] || { echo "[`date`] BET"; run bet /out/T1w_n4.nii.gz /out/T1w_brain.nii.gz -m -f 0.5; }

# --- method 2: SynthStrip (dedicated container ships the model weights) ---
echo "[`date`] SynthStrip"
apptainer run --pwd /out -B "$LOW":/out "$SS" \
    -i /out/T1w_n4.nii.gz -o /out/synthstrip_brain.nii.gz -m /out/synthstrip_mask.nii.gz

# --- method 3: sMRIPrep's ANTs-template mask (already computed) ---
ANTS_MASK_HOST=$(find "$DERIV/smriprep/sub-${LABEL}" -name '*desc-brain_mask.nii.gz' ! -path '*space-MNI*' | sort | head -1)
[[ -n "$ANTS_MASK_HOST" ]] || { echo "Run slurm/anatomical.sh first (need ANTs mask)"; exit 1; }

# --- compare all three on sMRIPrep's grid ---
run python - "/deriv/${ANTS_MASK_HOST#$DERIV/}" <<'PY'
import sys, nibabel as nib
from nilearn.image import resample_to_img
from nilearn import plotting
ants_p = sys.argv[1]
ants = nib.load(ants_p); ref = ants
def load_on_ref(p): return resample_to_img(nib.load(p), ref, interpolation="nearest").get_fdata() > 0.5
bet  = load_on_ref("/out/T1w_brain_mask.nii.gz")
syn  = load_on_ref("/out/synthstrip_mask.nii.gz")
ant  = ants.get_fdata() > 0.5
def dice(a,b): return 2*(a&b).sum()/(a.sum()+b.sum())
lines = [
  f"voxels:  BET={bet.sum():,}  SynthStrip={syn.sum():,}  ANTs(sMRIPrep)={ant.sum():,}",
  f"Dice BET        vs ANTs : {dice(bet,ant):.4f}",
  f"Dice SynthStrip vs ANTs : {dice(syn,ant):.4f}",
  f"Dice BET        vs SynthStrip : {dice(bet,syn):.4f}",
]
print("\n".join(lines)); open("/out/skullstrip_3way.txt","w").write("\n".join(lines)+"\n")
# tri-colour overlay: ANTs filled (bg), BET=red, SynthStrip=green
d = plotting.plot_roi(ants_p, bg_img="/out/T1w_n4.nii.gz", alpha=0.35,
                      title="ANTs(fill)  BET=red  SynthStrip=green", display_mode="ortho")
d.add_contours("/out/T1w_brain_mask.nii.gz", levels=[0.5], colors="r")
d.add_contours("/out/synthstrip_mask.nii.gz", levels=[0.5], colors="lime")
d.savefig("/out/skullstrip_3way.png", dpi=140); d.close()
print("wrote skullstrip_3way.png + .txt")
PY
echo "[`date`] DONE -> $LOW/skullstrip_3way.{png,txt}"
