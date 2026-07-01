# Reading & progress checklist

A living guide — Claude updates the **Progress** boxes as the project advances, and
you check off the **Reading** boxes as you go. Last updated: 2026-06-30.

## Progress (where the project actually is)
- [x] Phase 0 — GitHub repo created & pushed (`bradenfairbanks11/ms-mri-analysis`)
- [x] Phase 1 — code-only repo scaffolded (storage split: archive=raw, autodelete=compute, home=code)
- [x] Phase 2 — pilot `sub-0040` fetched (6.1 GB); FreeSurfer license; TemplateFlow; 4 containers built; BIDS-validate _(pending)_
- [x] Phase 3.1 — **Anatomical (sMRIPrep)** — pipeline + low-level DONE
  - [x] sMRIPrep pilot run COMPLETED (51 min) → brain mask, dseg, GM/WM/CSF, MNI transforms, QC report
  - [x] low-level: N4 → BET → FAST, Dice + overlay vs sMRIPrep (**Dice 0.952**)
  - [x] read QC report + write up `notes/anatomical.md` (insight: template mask beats intensity BET at low-contrast borders — BET clips the frontal pole and leaks at the brainstem base; see boundary QC)
  - [x] bonus 3-way skull-strip (BET/SynthStrip/ANTs): inclusiveness spectrum BET<ANTs<SynthStrip; coverage vs precision
  - [x] boundary QC (montage + landmark zooms): ANTs best mask; GM scalar would pick worst mask (BET) → look at the mask, not the number
- [ ] Phase 3.2 — Functional (fMRIPrep + tedana, multi-echo)
- [ ] Phase 3.3 — Diffusion (QSIPrep, multi-shell)
- [ ] Phase 3.4 — Perfusion (ASLPrep, pCASL CBF)
- [ ] Scale-out — `--array` over all 28 subjects
- [ ] Group — MS vs control comparison (`notes/group.md`)

## Reading — Tier 1: understand THIS project (do first)
- [ ] `PLAN.md` — the master plan (most important file)
- [ ] `README.md` — storage split and why
- [ ] `setup/config.sh` — every path & pinned version in one place
- [ ] `slurm/anatomical.sh` — the sMRIPrep command running now (read the comments)
- [ ] `lowlevel/anatomical_underthehood.sh` — the manual steps, commented

## Reading — Tier 2: the workflow machinery
- [ ] BIDS layout — https://bids-standard.github.io/bids-starter-kit/ ("Folders and Files")
- [ ] BIDS Apps paper (Gorgolewski 2017) — https://doi.org/10.1371/journal.pcbi.1005209
- [ ] NiPreps philosophy + fMRIPrep paper (Esteban 2019) — https://doi.org/10.1038/s41592-018-0235-4
- [ ] Apptainer intro (1 page) — https://apptainer.org/docs/user/main/introduction.html
- [ ] DataLad Handbook "Basics" — http://handbook.datalad.org/en/latest/basics/
- [ ] BYU RC docs (Slurm + Storage) — https://rc.byu.edu/documentation/

## Reading — Tier 3: per-modality science (prioritize your gaps: ASL, multi-shell DWI, multi-echo)
- [ ] Anatomical — sMRIPrep docs https://www.nipreps.org/smriprep/
- [ ] Multi-echo fMRI — tedana approach https://tedana.readthedocs.io/en/stable/approach.html
- [ ] Multi-shell DWI — QSIPrep https://qsiprep.readthedocs.io/ ; FSL topup/eddy wikis
- [ ] pCASL perfusion — ASLPrep https://aslprep.readthedocs.io/ ; ASL white paper (Alsop 2015) https://doi.org/10.1002/mrm.25197

## Reading — Tier 4: the low-level tools (read the one for the modality you're on)
- [ ] ANTs N4 bias correction — https://doi.org/10.1109/TMI.2010.2046908
- [ ] FSL BET skull-strip — https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/BET (we use BET; sMRIPrep uses ANTs antsBrainExtraction)
- [ ] FSL FAST segmentation — https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FAST

## If you only read three things
1. `PLAN.md` 2. Andy's Brain Book (https://andysbrainbook.readthedocs.io/) — hands-on FSL/AFNI/fMRI
3. the sMRIPrep HTML QC report (Claude will walk you through it)
