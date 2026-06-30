# Lab notebook — Modality 1: Anatomical (sMRIPrep)

Pilot subject: **sub-0040**. Status: **pipeline + low-level DONE** (2026-06-30); QC read-through pending.

## Headline result
- **Dice(my BET mask, sMRIPrep brain_mask) = 0.952** — BET = 2,450,935 voxels,
  sMRIPrep = 2,525,909 (BET slightly tighter). See `mask_compare.png`.
- sMRIPrep run: 51 min. Low-level (N4+BET+FAST+compare): 10 min.

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
| BET skull-strip → `my_brainmask` | `desc-brain_mask` (**ANTs template-based**) | FSL `bet` |
| FAST 3-class segmentation | `dseg` / `probseg` GM-WM-CSF | FSL `fast` |

> Note: sMRIPrep skull-strips with **ANTs `antsBrainExtraction.sh`** (template-based),
> not BET. We use BET (simple, intensity-based) on purpose, so the Dice/overlay shows
> where a fast classic method diverges from the app's template approach.

## QC examined
- [ ] sMRIPrep HTML report: brain mask contour, MNI registration overlay
- [ ] Dice (my mask vs sMRIPrep): `mask_compare.txt` → **____**
- [ ] Overlay `mask_compare.png`: where do they disagree? (expect edges/dura/cerebellum)

## What I learned / questions
- **Observed (sub-0040 overlay):** BET (intensity) clipped the **brainstem** and the
  **frontal pole**; sMRIPrep's template-based mask covered them cleanly.
- **Why:** BET grows a surface outward and stops at local intensity edges, so it fails
  where there's no clean edge — the brainstem merges into the spinal cord, and the
  frontal pole is thin tissue against orbital bone/sinus (air), low-contrast. ANTs
  `antsBrainExtraction.sh` registers a template *with prior brain shape*, so it keeps
  those regions even when intensity is ambiguous.
- **Principle:** local/intensity methods fail at thin / near-bone-or-air / low-contrast
  regions; registration/template methods are robust there (slower, needs good reg).
- **MS relevance:** brainstem = common MS lesion/atrophy site; a clipped mask corrupts
  downstream volumes, MNI registration, and signal coverage. This is why fMRIPrep/QSIPrep/
  ASLPrep all *reuse* this one sMRIPrep brain rather than re-stripping.
- Follow-up to try: re-run BET with a lower `-f` (keeps more) or `antsBrainExtraction.sh`
  and see if the brainstem/frontal-pole coverage improves.
