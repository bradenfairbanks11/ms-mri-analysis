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
> ⚠️ **Refined later (see Boundary QC below).** This section is my *first-pass* read
> from the 2-way overlay. The landmark zooms corrected one claim: BET doesn't simply
> "clip the brainstem" — it clips the **frontal pole** but **leaks** at the brainstem
> *base* down into the cord/clivus. Read this as the initial hypothesis; the Boundary
> QC section is the settled finding.

- **Observed (sub-0040 overlay):** BET (intensity) looked like it clipped the
  **brainstem** and the **frontal pole**; sMRIPrep's template-based mask covered them
  cleanly. *(Brainstem part later corrected → leak, not clip.)*
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

## 3-way skull-strip comparison (lowlevel/skullstrip_3way.sh)
Same N4'd T1, three philosophies — BET (intensity), SynthStrip (CNN), ANTs (template):

| Pair | Dice |   | Mask | voxels | ~mL |
|---|---|---|---|---|---|
| SynthStrip↔ANTs | **0.956** |   | BET | 2,450,935 | ~1255 (tightest) |
| BET↔ANTs | 0.952 |   | ANTs | 2,525,909 | ~1293 (middle) |
| BET↔SynthStrip | **0.919** |   | SynthStrip | 2,739,903 | ~1403 (loosest) |

- **Spectrum of inclusiveness:** BET < ANTs < SynthStrip (not "BET wrong, others right").
- SynthStrip is the OUTERMOST contour everywhere (green) — robust/never-clips but keeps a
  ~150 mL dura/CSF rim. BET clips brainstem/frontal pole. ANTs (Atropos-refined) is in between.
- Prior-carrying methods (SynthStrip, ANTs) agree most; BET & SynthStrip are the two extremes.
- **Takeaway:** no universally "correct" mask — it's coverage (SynthStrip) vs precision (tighter).
  For MS: SynthStrip safe for not losing brainstem lesions, but its rim would inflate
  volume/atrophy metrics → tighten before quantifying.
- Artifacts: `skullstrip_3way.png` (ANTs fill, BET red, SynthStrip green), `skullstrip_3way.txt`.

## Boundary QC — how to actually judge a mask (skullstrip_qc.sh)
GM volume alone is a SCALAR and can be right for the wrong reasons → judge masks visually
against anatomy. Artifacts: `qc_montage.png` (axial/coronal/sagittal, 3 contours),
`qc_zoom.png` (vertex/sinus, frontal pole, brainstem zooms), `qc_gm.txt`.

GM (FAST within each mask, triage only): BET 523.9 · ANTs 533.1 · SynthStrip 552.3 mL.

Visual findings (sub-0040):
- **Vertex/sup. sagittal sinus:** SynthStrip (green) bulges out over the dura/sinus → this
  IS the source of its +GM (dura ≈ GM intensity → FAST calls it GM).
- **Frontal pole:** BET tightest (mild clip), SynthStrip loosest (rim), ANTs between.
- **Brainstem/foramen:** BET LEAKS inferiorly into cord/clivus (non-brain); ANTs & SynthStrip
  cut cleanly. (Corrects earlier "BET clips brainstem" — it's actually erratic: clip up front,
  leak at the base.)
- **Verdict:** ANTs is the best mask here (no dura rim, no leak — Atropos refinement works),
  SynthStrip 2nd (needs erosion before volumetry), BET worst.

**KEY LESSON (validated):** ranking by GM volume would pick BET as "cleanest" (lowest GM) —
the exact mask with the worst spatial error (its leak went into low-intensity cord, not GM).
The scalar inverts the truth. → metrics = triage to flag outliers; the MASK is the judge.
