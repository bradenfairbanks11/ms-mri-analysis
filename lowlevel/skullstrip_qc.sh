#!/bin/bash
#SBATCH --job-name=msmri_skullstrip_qc
#SBATCH --output=/nobackup/autodelete/usr/bradenf4/ms_dataset/logs/%x_%j.out
#SBATCH --error=/nobackup/autodelete/usr/bradenf4/ms_dataset/logs/%x_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=1:00:00
# =============================================================================
# Modality 1 — boundary QC of the three skull-strip masks (the RIGHT way to judge).
#
# A scalar (GM volume, Dice) can be right for the wrong reasons, so the PRIMARY
# judge here is visual: the three mask edges drawn on the T1, scanned across the
# whole brain AND zoomed at the landmarks where they diverge.
#
#   Colours:  BET = red,  SynthStrip = green,  ANTs(sMRIPrep) = gold
#
# Outputs (in derivatives/lowlevel/anatomical/sub-XX/):
#   qc_montage.png  — axial+coronal+sagittal montages, 3 contours on the T1
#   qc_zoom.png     — midsagittal + zoom insets (vertex/sinus, frontal pole, brainstem)
#   qc_gm.txt       — GM volume from FAST run *inside each mask* (triage only)
# =============================================================================
set -euo pipefail
source "${MSMRI_CONFIG:-/home/bradenf4/ms-mri-analysis/setup/config.sh}"
module load "$APPTAINER_MODULE"

LABEL=${1:-0040}
SIF=$CONTAINERS/smriprep.sif
LOW=$DERIV/lowlevel/anatomical/sub-${LABEL}
run () { apptainer exec --pwd /out -B "$LOW":/out -B "$DERIV":/deriv "$SIF" "$@"; }

ANTS_MASK_HOST=$(find "$DERIV/smriprep/sub-${LABEL}" -name '*desc-brain_mask.nii.gz' ! -path '*space-MNI*' | sort | head -1)
ANTS_MASK=/deriv/${ANTS_MASK_HOST#$DERIV/}

# --- step 1: align all three masks onto the T1w_n4 grid (binary) -------------
run python - "$ANTS_MASK" <<'PY'
import sys, nibabel as nib, numpy as np
from nilearn.image import resample_to_img
t1 = nib.load("/out/T1w_n4.nii.gz")
src = {"bet":"/out/T1w_brain_mask.nii.gz","syn":"/out/synthstrip_mask.nii.gz","ants":sys.argv[1]}
for tag,p in src.items():
    m = resample_to_img(nib.load(p), t1, interpolation="nearest")
    nib.save(nib.Nifti1Image((m.get_fdata()>0.5).astype('uint8'), t1.affine, t1.header),
             f"/out/{tag}_aln.nii.gz")
    print("aligned", tag)
PY

# --- step 2: FAST within each mask -> GM volume (triage metric) ---------------
: > "$LOW/qc_gm.txt"
for tag in bet syn ants; do
    run fslmaths /out/T1w_n4.nii.gz -mas /out/${tag}_aln.nii.gz /out/brain_${tag}.nii.gz
    run fast -t 1 -n 3 -o /out/fast_${tag} /out/brain_${tag}.nii.gz
done
run python - <<'PY'
import nibabel as nib, numpy as np
out=[]
for tag,name in [("bet","BET"),("syn","SynthStrip"),("ants","ANTs")]:
    g=nib.load(f"/out/fast_{tag}_pve_1.nii.gz"); vox=np.prod(g.header.get_zooms())
    out.append(f"{name:11s} GM = {g.get_fdata().sum()*vox/1000:7.1f} mL")
open("/out/qc_gm.txt","w").write("FAST GM within each mask (triage only; look at the montage to judge):\n"+"\n".join(out)+"\n")
print("\n".join(out))
PY

# --- step 3: the montages + landmark zooms (the actual judge) ----------------
run python - <<'PY'
import numpy as np, nibabel as nib
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from nilearn import plotting
t1="/out/T1w_n4.nii.gz"
masks={"bet":("red","/out/bet_aln.nii.gz"),"syn":("lime","/out/syn_aln.nii.gz"),"ants":("gold","/out/ants_aln.nii.gz")}

# ---- montage: one row per orientation, 3 contours each ----
fig,axes=plt.subplots(3,1,figsize=(14,9),facecolor="k")
for ax,mode in zip(axes,["z","y","x"]):
    d=plotting.plot_anat(t1,display_mode=mode,cut_coords=7,axes=ax,annotate=False,black_bg=True)
    for c,p in masks.values(): d.add_contours(p,levels=[0.5],colors=c,linewidths=0.8)
fig.suptitle("Skull-strip boundaries — BET=red  SynthStrip=green  ANTs=gold",color="w")
fig.savefig("/out/qc_montage.png",dpi=140,facecolor="k"); plt.close(fig)
print("wrote qc_montage.png")

# ---- landmark zoom on the mid-sagittal slice (try/except so it never kills the job) ----
try:
    can=nib.as_closest_canonical(nib.load(t1)); T=can.get_fdata()
    M={k:nib.as_closest_canonical(nib.load(p)).get_fdata()>0.5 for k,(c,p) in masks.items()}
    union=M["ants"]|M["syn"]|M["bet"]; xs,ys,zs=np.where(union)
    xi=int(round(np.mean(xs)))                          # mid-sagittal
    sl=lambda A:np.rot90(A[xi,:,:])                      # (y,z)->display
    y0,y1,z0,z1=ys.min(),ys.max(),zs.min(),zs.max()
    H=sl(T).shape
    def box(name,ylo,yhi,zlo,zhi):  # convert world bbox frac -> display extent (cols=y, rows=flipped z)
        return name,(ylo,yhi,zlo,zhi)
    # display coords: imshow of rot90 -> rows = (Zmax..Zmin), cols = (Ymin..Ymax)
    panels=[("mid-sagittal (full)",y0,y1,z0,z1),
            ("vertex / sup. sagittal sinus",y0,y1,int(z0+0.72*(z1-z0)),z1),
            ("frontal pole",int(y0+0.70*(y1-y0)),y1,int(z0+0.35*(z1-z0)),z1),
            ("brainstem / foramen magnum",int(y0+0.30*(y1-y0)),int(y0+0.70*(y1-y0)),z0,int(z0+0.45*(z1-z0)))]
    fig,axs=plt.subplots(1,4,figsize=(20,7),facecolor="k")
    base=sl(T)
    for ax,(title,ya,yb,za,zb) in zip(axs,panels):
        ax.imshow(base,cmap="gray",origin="upper"); ax.set_title(title,color="w",fontsize=11); ax.axis("off")
        for k,(c,p) in masks.items():
            ax.contour(sl(M[k]).astype(float),levels=[0.5],colors=c,linewidths=1.1)
        # crop: cols=y (Ymin..Ymax left->right), rows=z flipped (Zmax top)
        ax.set_xlim(ya, yb); ax.set_ylim(H[0]-za, H[0]-zb)
    fig.suptitle("Mid-sagittal zooms — BET=red  SynthStrip=green  ANTs=gold",color="w")
    fig.savefig("/out/qc_zoom.png",dpi=140,facecolor="k"); plt.close(fig); print("wrote qc_zoom.png")
except Exception as e:
    print("zoom panel failed (montage still saved):", repr(e))
PY
echo "[`date`] DONE -> $LOW/qc_montage.png, qc_zoom.png, qc_gm.txt"
