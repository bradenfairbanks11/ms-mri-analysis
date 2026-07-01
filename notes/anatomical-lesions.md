# Lab notebook — Modality 1b: MS lesion handling (PARKED)

Pilot subject: **sub-0040**. Status: **PARKED (2026-06-30)** — scripts written and
pristine, but not run on ds007908. Resume when a dataset with **T2w or (ideally)
FLAIR** is available.

> This file = lesions as a **nuisance** (fill / mask in preprocessing). For lesions
> as the **signal of interest** (DWI-based localization; lesion-symptom mapping),
> see [`lesion-research-directions.md`](lesion-research-directions.md).

## The decision (why parked)
ds007908 ships **T1w only** — no T2w, no FLAIR anywhere in the 28 subjects
(verified). MS white-matter lesions are only *partially* visible on T1w (the
destructive, T1-hypointense "black hole" subset); most lesions that light up on
FLAIR are invisible or ambiguous on T1. Forcing a T1-only lesion segmentation
would yield a mask we couldn't trust, so we deliberately **do not** run it here.
A parked, correct template is worth more than a bad analysis.

## Why lesions must be handled at all (the core mechanism)
On T1w, WM lesions are **hypo-intense** — darker than normal WM, drifting toward
*gray-matter* intensity. So an intensity classifier (FSL FAST / ANTs Atropos)
misreads them: Battaglini et al. 2012 found **~72% of lesion volume misclassified
as GM** on the raw T1, corrected to **~94% WM** after lesion filling. That error
propagates into:
- **Tissue volumetry** — inflates GM, holes out WM; a direct confound for MS
  atrophy (you'd measure "more GM" in sicker patients — backwards).
- **Spatial normalization** — the intensity-driven warp to a (lesion-free)
  template is distorted by lesion voxels.
- **Surfaces (recon-all)** — WM surface placement corrupted near lesions.
- **Functional confounds** — lesion signal leaks into WM/CSF nuisance regressors.

## The conceptual pipeline (two jobs, then three uses)
**Job 1 — segment the lesions** → a binary lesion mask. Normally from FLAIR.
**Job 2 — use the mask**, three independent ways:
1. **Lesion filling** (Battaglini 2012) — inpaint lesion voxels on the T1 with
   normal-appearing-WM (NAWM) intensity + matched noise, *before* segmentation /
   surfaces, so intensity tools never see the anomaly.
2. **Cost-function masking** (Brett 2001) — during registration, compute the
   similarity cost only over NON-lesion voxels, so the lesion (absent in the
   template) doesn't pull the warp. NiPreps convention: a binary
   `sub-XX[_ses-Y]_label-lesion_roi.nii.gz` (lesion=1, in T1w space) in `anat/`,
   plus a `.bidsignore` entry for `*_roi.nii.gz`.
3. **Confound masking** — subtract the lesion from WM/CSF masks before aCompCor
   in the functional stage.

## SAMSEG — how the tool works (for the T2w/FLAIR resume)
- **SAMSEG** = Sequence-Adaptive Multimodal SEGmentation (FreeSurfer, Puonti
  2016). Bayesian *generative* model: deformable probabilistic atlas as spatial
  prior + Gaussian-mixture intensity model, solved jointly with a bias-field
  estimate. "Sequence adaptive" because it learns intensities from the data
  rather than assuming a contrast → accepts any set of input contrasts.
- **--lesion** (Cerri 2021): lesions modelled as *outliers* to the healthy-tissue
  model, with a **VAE** shape prior so detections are contiguous/plausible.
  `--lesion-mask-pattern` gives lesion intensity direction per contrast
  (0 = hypo = T1w; 1 = hyper = T2w/FLAIR); `--threshold` binarises the posterior.
- **Contrast ideality:** FLAIR > T2w >> T1-only (CSF suppression is why FLAIR wins).
- **Gotcha (this cluster):** `run_samseg --lesion` needs `tensorflow.compat.v1`
  + legacy `scipy.ndimage.interpolation` (removed in scipy ≥ 1.9). smriprep.sif's
  FreeSurfer 7.3.2 python has no tensorflow → --lesion fails there. Needs a
  TF-enabled FreeSurfer env (override with `LESION_SIF=...`). Plain SAMSEG runs anywhere.

## Artifacts (parked, ready)
- `slurm/anat_lesion.sh` — SAMSEG (multi-contrast; auto-adds FLAIR/T2w if present).
- `lowlevel/lesion_filling_underthehood.sh` — hand-rolled Battaglini fill +
  FAST before/after, to reproduce the GM→WM flip on a real mask.
- (not yet written) sMRIPrep re-run with `label-lesion_roi` cost-function masking.

## To resume
1. Obtain T2w/FLAIR (check whether the source study has FLAIR not uploaded to
   OpenNeuro, or use a dataset that includes it).
2. Get a TF-enabled FreeSurfer for `--lesion` (or run plain SAMSEG for structures
   only). 3. Run the two scripts above; then wire the mask into sMRIPrep.
