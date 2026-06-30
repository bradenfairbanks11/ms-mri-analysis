# Lab notebook — Modality 1: Anatomical (sMRIPrep)

Pilot subject: **sub-0040**. Status: _not yet run_.

## What I ran
- Full pipeline: `slurm/anatomical.sh` (sMRIPrep `$SMRIPREP_VER`, `--fs-no-reconall` for the pilot)
- Open-the-hood: `lowlevel/anatomical_underthehood.sh`

## What sMRIPrep does, stage by stage
_(fill in after reading the HTML QC report `$DERIV/smriprep/sub-0040.html`)_
1. Intensity non-uniformity (N4 bias) correction —
2. Brain extraction (ANTs, OASIS template) —
3. Spatial normalization to MNI152NLin2009cAsym —
4. Tissue segmentation (FAST) —
5. (Surfaces via recon-all — skipped in pilot) —

## How my manual step maps onto it
| My step (low-level) | sMRIPrep's equivalent | Tool |
|---|---|---|
| N4 bias correction | "Intensity non-uniformity correction" | ANTs `N4BiasFieldCorrection` |
| SynthStrip skull-strip → `my_brainmask` | `desc-brain_mask` (ANTs-based) | FreeSurfer `mri_synthstrip` |
| FAST 3-class segmentation | `dseg` / `probseg` GM-WM-CSF | FSL `fast` |

## QC examined
- [ ] sMRIPrep HTML report: brain mask contour, MNI registration overlay
- [ ] Dice (my mask vs sMRIPrep): `mask_compare.txt` → **____**
- [ ] Overlay `mask_compare.png`: where do they disagree? (expect edges/dura/cerebellum)

## What I learned / questions
- Why might SynthStrip (CNN) and sMRIPrep's ANTs brain extraction differ at the edges?
-
