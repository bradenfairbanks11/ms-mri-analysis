#!/bin/bash
#SBATCH --job-name=msmri_samseg_lesion
#SBATCH --output=/nobackup/autodelete/usr/bradenf4/ms_dataset/logs/%x_%j.out
#SBATCH --error=/nobackup/autodelete/usr/bradenf4/ms_dataset/logs/%x_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=24G
#SBATCH --time=3:00:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=bradenfairbanks@gmail.com
# =============================================================================
# Modality 1b — MS WHITE-MATTER LESION SEGMENTATION with SAMSEG.
#
# ----------------------------------------------------------------------------
# STATUS: PARKED for ds007908 (decided 2026-06-30). This dataset ships T1w ONLY
# (no T2w/FLAIR). T1-only lesion detection is unreliable — it sees mainly the
# destructive, T1-hypointense "black hole" subset and MISSES most lesions that
# would be conspicuous on FLAIR — so we deliberately do NOT force a lesion
# analysis here. This script is kept as a correct, ready template for a dataset
# (or cluster) that has the proper contrasts. See notes/anatomical-lesions.md.
# ----------------------------------------------------------------------------
#
# WHAT SAMSEG IS (concept)
#   Sequence-Adaptive Multimodal SEGmentation (FreeSurfer; Puonti 2016). A
#   Bayesian *generative* model: a deformable probabilistic atlas supplies the
#   spatial prior for ~40 structures, and a Gaussian mixture models the image
#   intensities. It jointly estimates the atlas deformation, a smooth bias field,
#   and the intensity distributions by optimisation — so it is "sequence
#   adaptive": it LEARNS the intensities from your data instead of assuming a
#   contrast. That is why it can take any set of input contrasts.
#
# THE LESION EXTENSION (--lesion; Cerri 2021)
#   Lesions are modelled as *outliers* to the healthy-tissue generative model:
#   WM voxels whose intensity the normal model cannot explain. A Variational
#   AutoEncoder (VAE) adds a learned prior on lesion SHAPE so the detected
#   outliers form plausible, contiguous lesions rather than salt-and-pepper
#   noise. --lesion-mask-pattern tells it, per contrast, which intensity
#   DIRECTION a lesion takes (see below), and --threshold binarises the lesion
#   posterior probability.
#
# INPUT-CONTRAST IDEALITY:  FLAIR  >  T2w  >>  T1-only
#   FLAIR: lesions bright AND CSF suppressed -> best lesion-to-background
#   separation. T2w: lesions bright but CSF also bright -> periventricular
#   lesions blend with CSF. T1-only: lesions are weak hypointensities that
#   overlap GM intensity -> poor separability (hence the PARKED status).
#
# RUNTIME DEPENDENCY (discovered 2026-06-30 on smriprep.sif)
#   run_samseg --lesion imports `tensorflow.compat.v1` (the VAE) and
#   `scipy.ndimage.interpolation.affine_transform` (removed in scipy >= 1.9).
#   The bundled FreeSurfer 7.3.2 python has NO tensorflow, so --lesion FAILS in
#   smriprep.sif. Run this in a FreeSurfer environment that carries the legacy
#   TF1 / old-scipy stack (a full FreeSurfer install, or a dedicated container).
#   NOTE: plain SAMSEG *without* --lesion needs neither and runs anywhere.
#
# --threshold : lesion-probability cutoff. SAMSEG default 0.3; 0.1 is more
#               inclusive (often suggested when contrast is limited).
#
# Output ($DERIV/lesion/sub-XX/): samseg/ (seg.mgz, stats), lesion_mask.nii.gz
# (binary, on the T1w grid), lesion_qc.png, lesion_volume.txt
#
# Run (once proper contrasts + a TF-enabled FreeSurfer exist):
#   sbatch slurm/anat_lesion.sh 0040
# =============================================================================
set -euo pipefail
source "${MSMRI_CONFIG:-/home/bradenf4/ms-mri-analysis/setup/config.sh}"
module load "$APPTAINER_MODULE"

LABEL=${1:-0040}
LESION_THRESHOLD=${LESION_THRESHOLD:-0.3}
SIF=${LESION_SIF:-$CONTAINERS/smriprep.sif}   # override with a TF-enabled FS container
OUT=$DERIV/lesion/sub-${LABEL}
mkdir -p "$OUT"

# No --cleanenv: SAMSEG relies on the container's baked-in FREESURFER_HOME.
run () { apptainer exec \
    -B "$RAW":/data:ro -B "$OUT":/out \
    -B "$FS_LICENSE":/opt/freesurfer/license.txt:ro \
    "$SIF" "$@"; }

# --- assemble input contrasts: T1w always; add FLAIR / T2w if the dataset has them.
# SAMSEG is multi-contrast; each extra contrast sharpens lesion separability.
# --lesion-mask-pattern gives the lesion intensity DIRECTION per input:
#   0 = HYPO-intense (T1w),  1 = HYPER-intense (T2w, FLAIR).
inputs=(); patterns=()
add () { local host="$1" pat="$2"; [[ -n "$host" ]] || return 0
         inputs+=("/data/${host#$RAW/}"); patterns+=("$pat")
         echo "  + $(basename "$host")  (lesion-mask-pattern $pat)"; }

T1_HOST=$(find "$RAW/sub-${LABEL}" -path '*anat*' -name '*T1w.nii.gz' | sort | head -1)
echo "[`date`] assembling SAMSEG inputs for sub-${LABEL}:"
add "$T1_HOST" 0
add "$(find "$RAW/sub-${LABEL}" -path '*anat*' -name '*FLAIR.nii.gz' | sort | head -1)" 1
add "$(find "$RAW/sub-${LABEL}" -path '*anat*' -name '*T2w.nii.gz'   | sort | head -1)" 1
[[ ${#inputs[@]} -ge 1 ]] || { echo "no anatomical input for sub-${LABEL}"; exit 1; }
if [[ ${#inputs[@]} -eq 1 ]]; then
    echo "  [WARN] T1-only run: lesion detection is UNRELIABLE (see header). FLAIR strongly recommended."
fi

# --- SAMSEG joint whole-brain + lesion segmentation ---
run run_samseg \
    --input "${inputs[@]}" \
    --output /out/samseg \
    --lesion \
    --lesion-mask-pattern "${patterns[@]}" \
    --threshold "$LESION_THRESHOLD" \
    --threads 8

# --- extract the binary lesion mask (SAMSEG labels lesions 99 in seg.mgz),
#     resampled onto the raw T1w grid so it matches T1w space/resolution ---
echo "[`date`] extract lesion mask (label 99) -> resample to raw T1w grid"
run python - "/data/${T1_HOST#$RAW/}" "$LESION_THRESHOLD" <<'PY'
import sys, numpy as np, nibabel as nib
from nilearn.image import resample_to_img
t1_p, thr = sys.argv[1], sys.argv[2]
seg = nib.load("/out/samseg/seg.mgz")
lesion = (np.asarray(seg.dataobj) == 99).astype('uint8')       # 99 = SAMSEG lesion label
t1 = nib.load(t1_p)
lm = resample_to_img(nib.Nifti1Image(lesion, seg.affine), t1, interpolation="nearest")
mask = (lm.get_fdata() > 0.5).astype('uint8')
nib.save(nib.Nifti1Image(mask, t1.affine, t1.header), "/out/lesion_mask.nii.gz")
ml = mask.sum() * np.prod(t1.header.get_zooms()) / 1000.0
print(f"lesion voxels={int(mask.sum())}  volume={ml:.2f} mL")
open("/out/lesion_volume.txt","w").write(f"lesion_ml={ml:.2f}\nvoxels={int(mask.sum())}\nthreshold={thr}\n")
PY

# --- QC overlay: lesion mask on the T1 ---
run python - "/data/${T1_HOST#$RAW/}" <<'PY'
import sys, matplotlib; matplotlib.use("Agg")
from nilearn import plotting
d = plotting.plot_roi("/out/lesion_mask.nii.gz", bg_img=sys.argv[1], alpha=0.7,
      cmap="autumn", display_mode="ortho", title="SAMSEG lesion mask (sub)")
d.savefig("/out/lesion_qc.png", dpi=140); d.close(); print("wrote lesion_qc.png")
PY
echo "[`date`] DONE -> $OUT/{samseg/, lesion_mask.nii.gz, lesion_qc.png, lesion_volume.txt}"
