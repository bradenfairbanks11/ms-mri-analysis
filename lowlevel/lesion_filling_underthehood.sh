#!/bin/bash
#SBATCH --job-name=msmri_lesionfill
#SBATCH --output=/nobackup/autodelete/usr/bradenf4/ms_dataset/logs/%x_%j.out
#SBATCH --error=/nobackup/autodelete/usr/bradenf4/ms_dataset/logs/%x_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=1:30:00
# =============================================================================
# Modality 1b, step 2 — "OPEN THE HOOD": WM LESION FILLING, by hand.
#
# STATUS: PARKED with slurm/anat_lesion.sh — it needs a trustworthy lesion mask,
# which ds007908 (T1w-only) can't provide. Kept as a ready template: point it at
# any real lesion_mask.nii.gz (from SAMSEG on a T2w/FLAIR dataset) and it runs.
#
# THE PROBLEM (why this matters): on a T1w, MS WM lesions are HYPO-intense, so an
# intensity classifier (FSL FAST) calls them GRAY matter. Battaglini et al. 2012
# found 72% of lesion volume is misclassified as GM on the raw T1; filling the
# lesion voxels with normal-appearing-WM (NAWM) intensity first fixes ~94% of it.
#
# FSL's lesion_filling isn't in smriprep.sif, so we IMPLEMENT the fill ourselves
# (that's the point of opening the hood): for each lesion voxel, substitute the
# LOCAL mean NAWM intensity + noise matched to NAWM variance. Then we run FAST on
# the UNFILLED vs FILLED T1 and measure how much lesion volume flips GM -> WM.
#
# Inputs reused:
#   - $DERIV/lowlevel/anatomical/sub-XX/T1w_n4.nii.gz   (N4 T1 from Modality 1)
#   - $DERIV/lowlevel/anatomical/sub-XX/ants_aln.nii.gz (ANTs brain mask = best, from QC)
#   - $DERIV/lesion/sub-XX/lesion_mask.nii.gz           (SAMSEG lesion mask, step 1)
#   - $DERIV/lesion/sub-XX/samseg/seg.mgz               (for clean NAWM = WM labels - lesion)
#
# Run AFTER slurm/anat_lesion.sh (needs the lesion mask + samseg seg).
# =============================================================================
set -euo pipefail
source "${MSMRI_CONFIG:-/home/bradenf4/ms-mri-analysis/setup/config.sh}"
module load "$APPTAINER_MODULE"

LABEL=${1:-0040}
SIF=$CONTAINERS/smriprep.sif
LOW=$DERIV/lowlevel/anatomical/sub-${LABEL}   # Modality-1 outputs (T1w_n4, ants_aln)
LES=$DERIV/lesion/sub-${LABEL}                # SAMSEG outputs (lesion_mask, samseg/)
OUT=$LES/fill                                  # this step's outputs
mkdir -p "$OUT"

for f in "$LOW/T1w_n4.nii.gz" "$LOW/ants_aln.nii.gz" "$LES/lesion_mask.nii.gz" "$LES/samseg/seg.mgz"; do
    [[ -s "$f" ]] || { echo "MISSING prerequisite: $f  (run Modality-1 low-level + slurm/anat_lesion.sh first)"; exit 1; }
done

run () { apptainer exec --pwd /out \
    -B "$LOW":/low -B "$LES":/les -B "$OUT":/out "$SIF" "$@"; }

# --- STEP A: fill the lesions with local NAWM intensity (hand-rolled Battaglini) ---
echo "[`date`] filling lesions with local NAWM intensity + matched noise"
run python - <<'PY'
import numpy as np, nibabel as nib
from nilearn.image import resample_to_img
from scipy.ndimage import uniform_filter
np.random.seed(42)  # reproducible noise

t1   = nib.load("/low/T1w_n4.nii.gz")
img  = t1.get_fdata().astype(np.float32)
brain= resample_to_img(nib.load("/low/ants_aln.nii.gz"), t1, interpolation="nearest").get_fdata() > 0.5
les  = resample_to_img(nib.load("/les/lesion_mask.nii.gz"), t1, interpolation="nearest").get_fdata() > 0.5

# NAWM = SAMSEG cerebral-WM labels (2,41), on the T1 grid, MINUS lesion voxels.
seg  = resample_to_img(nib.load("/les/samseg/seg.mgz"), t1, interpolation="nearest").get_fdata()
wm   = np.isin(seg, [2, 41])
nawm = wm & ~les & brain

# Local NAWM mean via a box filter: sum(img*nawm)/count(nawm) in a 7-vox window.
W = 7
num = uniform_filter((img*nawm).astype(np.float32), size=W)
den = uniform_filter(nawm.astype(np.float32),       size=W)
local_mean = np.where(den > 1e-3, num/np.maximum(den,1e-6), img[nawm].mean())
sigma = float(img[nawm].std())

filled = img.copy()
noise  = np.random.normal(0.0, 0.5*sigma, size=img.shape).astype(np.float32)
filled[les] = local_mean[les] + noise[les]

nib.save(nib.Nifti1Image(filled, t1.affine, t1.header), "/out/T1w_filled.nii.gz")
# brain-masked copies for FAST (unfilled vs filled)
nib.save(nib.Nifti1Image((img   *brain).astype(np.float32), t1.affine, t1.header), "/out/brain_unfilled.nii.gz")
nib.save(nib.Nifti1Image((filled*brain).astype(np.float32), t1.affine, t1.header), "/out/brain_filled.nii.gz")
print(f"lesion voxels={int(les.sum())}  NAWM sigma={sigma:.1f}  lesion mean T1: "
      f"before={img[les].mean():.1f}  after={filled[les].mean():.1f}  (NAWM mean={img[nawm].mean():.1f})")
PY

# --- STEP B: FAST on unfilled vs filled brain ---
for tag in unfilled filled; do
    echo "[`date`] FAST ($tag)"
    run fast -t 1 -n 3 -o /out/fast_${tag} /out/brain_${tag}.nii.gz
done

# --- STEP C: quantify GM/WM reclassification WITHIN the lesion mask ---
echo "[`date`] measuring GM->WM flip inside the lesion"
run python - <<'PY'
import numpy as np, nibabel as nib
from nilearn.image import resample_to_img
ref = nib.load("/out/fast_unfilled_seg.nii.gz")          # FAST pveseg: 1=CSF 2=GM 3=WM
les = resample_to_img(nib.load("/les/lesion_mask.nii.gz"), ref, interpolation="nearest").get_fdata() > 0.5
def frac(seg_p):
    s = nib.load(seg_p).get_fdata()[les]
    n = max(les.sum(), 1)
    return 100*np.mean(s==1), 100*np.mean(s==2), 100*np.mean(s==3)  # %CSF, %GM, %WM
csf0,gm0,wm0 = frac("/out/fast_unfilled_seg.nii.gz")
csf1,gm1,wm1 = frac("/out/fast_filled_seg.nii.gz")
lines = [
 "FAST tissue class WITHIN the lesion mask (% of lesion voxels):",
 f"  UNFILLED : CSF {csf0:4.1f}   GM {gm0:4.1f}   WM {wm0:4.1f}",
 f"  FILLED   : CSF {csf1:4.1f}   GM {gm1:4.1f}   WM {wm1:4.1f}",
 f"  -> GM misclassification dropped {gm0:.1f}% -> {gm1:.1f}%; WM recovered {wm0:.1f}% -> {wm1:.1f}%",
 "(cf. Battaglini 2012: ~72% GM unfilled -> ~94% WM filled; exact numbers are subject/threshold-specific)",
]
print("\n".join(lines)); open("/out/lesionfill_compare.txt","w").write("\n".join(lines)+"\n")
PY

# --- STEP D: before/after overlays ---
run python - <<'PY'
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import numpy as np, nibabel as nib
from nilearn.image import resample_to_img
from nilearn import plotting
les = nib.load("/les/lesion_mask.nii.gz")
# pick a cut through the largest lesion cluster
L = les.get_fdata()>0.5
if L.sum():
    import numpy as np
    zc = np.argmax(L.sum(axis=(0,1))); yc = np.argmax(L.sum(axis=(0,2))); xc = np.argmax(L.sum(axis=(1,2)))
    aff = les.affine; cc = aff.dot([xc,yc,zc,1])[:3]
else:
    cc = (0,0,0)
fig,axes = plt.subplots(2,1,figsize=(13,7),facecolor="k")
for ax,(img,ttl) in zip(axes, [("/out/brain_unfilled.nii.gz","T1 UNFILLED (lesion=red)"),
                                ("/out/brain_filled.nii.gz","T1 FILLED (lesion=red)")]):
    d = plotting.plot_anat(img, axes=ax, cut_coords=cc, display_mode="ortho",
                           annotate=False, black_bg=True, title=ttl)
    d.add_contours("/les/lesion_mask.nii.gz", levels=[0.5], colors="r", linewidths=0.8)
fig.savefig("/out/lesionfill_overlay.png", dpi=140, facecolor="k"); plt.close(fig)
print("wrote lesionfill_overlay.png")
PY
echo "[`date`] DONE -> $OUT/{T1w_filled.nii.gz, fast_*, lesionfill_compare.txt, lesionfill_overlay.png}"
