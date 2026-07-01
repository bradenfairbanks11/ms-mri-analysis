# Lesion research directions (PARKED ideas)

Companion to [`anatomical-lesions.md`](anatomical-lesions.md). That file covers
lesions as a *nuisance* in preprocessing (fill / mask). This file parks the
"lesion as the *signal of interest*" ideas for when we have better data
(T2w/FLAIR) or reach Modality 3 (diffusion). None run on ds007908 as-is.

---

## A. Localizing lesions from DWI (since we have multi-shell DWI but no T2/FLAIR)
Question we explored: with no T2w/FLAIR, can the diffusion data point at where WM
lesions are? **Partially yes — two mechanisms — but sensitive, not specific, so
it yields noisy candidates, not a trustworthy mask.**

1. **The b=0 image is secretly a T2w image.** DWI is spin-echo EPI with long TE,
   so the non-diffusion-weighted (b0) volumes are **T2-weighted** → MS lesions
   (long T2) appear **hyperintense** on the b0. But it's a *bad* T2: ~2 mm res,
   EPI-distorted (correctable with the AP/PA fmaps via topup/eddy), and NO CSF
   suppression (T2-like, not FLAIR-like) so periventricular lesions blur into CSF.

2. **Diffusion metrics flag tissue damage.** In lesions: **FA↓, MD↑, RD↑**
   (RD specifically ~ demyelination), neurite density↓ on NODDI (our b=1500/3000
   multi-shell supports it). A focal low-FA/high-MD patch = candidate lesion.

**Why it can't replace FLAIR — the specificity problem.** Low FA / high MD is
NOT unique to lesions; it also occurs in crossing-fiber regions (low FA is normal
there), diffusely-abnormal NAWM in MS, CSF partial-volume at ventricle edges, and
aging. Thresholding diffusion abnormality → many false positives. (Opposite
failure mode from T1-only, which was *insensitive*; DWI is *unspecific*.)

**Acute vs chronic:** high-b DWI lights up *stroke* (restricted diffusion, acute
cytotoxic edema) but MS lesions are mostly chronic and usually do NOT restrict —
so high-b DWI is not an MS-lesion detector.

**Research-grade idea worth trying in Modality 3 — multimodal outlier intersection:**
```
lesion candidate = (T1-hypointense within WM)  AND  (FA↓ / MD↑ at same location)
```
The AND kills each modality's false positives (crossing fibers aren't T1-dark;
T1 noise isn't diffusion-abnormal). Requires registering the distortion-corrected
DWI (QSIPrep + our fmaps) to the T1 first. Not clinical-grade, but a defensible
improvement over either alone and a good learning project.

**Where DWI genuinely wins:** *characterizing* damage, not detecting it —
RD (demyelination), NODDI neurite density (axonal loss) *within* known lesions.
T2/FLAIR find lesions; DWI measures how destroyed they are.

---

## B. Lesion as signal → association with behavior/symptoms
The "opposite" of preprocessing: treat lesion intensity/size/location as the
variable and relate it to behavior. Directly on-point for ds007908 ("trajectories
of cognitive impairment in MS") — but needs (i) trustworthy masks (FLAIR) and
(ii) the cognitive/behavioral scores (likely a `phenotype/` folder we haven't
fetched; `participants.tsv` only had group/age/sex).

Three axes: **size** (total lesion volume, count), **intensity** (T1 "black
holes", MTR, qT1/T2 → tissue-destruction severity), **location** (which tracts/
networks) — location is usually the most predictive.

Analysis ladder (simple → sophisticated):
1. **Global** — total lesion volume vs symptom score.
2. **VLSM** (voxel-based lesion-symptom mapping) — per-voxel lesioned-vs-not test;
   mass-univariate + permutation correction. Tools: NiiStat.
3. **Multivariate LSM** — models voxel covariance (lesions are blobs). Tools:
   SVR-LSM, LESYMAP (R).
4. **Disconnection / network mapping** — overlay mask on a normative connectome,
   relate the *disconnection pattern* to symptoms. Tools: Lesion Quantification
   Toolkit (Griffis), NeMo (Kuceyeski), BCBtoolkit, Lesion Network Mapping (Fox/Boes).

**Key MS motivator — the clinico-radiological paradox:** total lesion volume
correlates only weakly with disability; a tiny lesion in a critical tract can
disable while a large "silent" one does not. That's *why* the ladder climbs from
volume → voxel → network — each rung captures what raw load misses. So the real
science lives in the **intensity** and **location** axes, not size.

---

## Key references (shared reading list for both sessions)
- SAMSEG: Puonti et al. 2016; lesion ext.: Cerri et al. 2021
- Lesion filling: Battaglini et al. 2012 · Cost-function masking: Brett et al. 2001
- DTI in MS: Filippi/Rocca reviews · NODDI: Zhang et al. 2012
- LSM: Bates et al. 2003 (VLSM); Pustina et al. 2018 (LESYMAP)
- Disconnection: Griffis et al. 2021 (LQT); Kuceyeski et al. 2013 (NeMo)
