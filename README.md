# ms-mri-analysis

Code-only repo for learning to analyze the **OpenNeuro ds007908** multi-modal MS
MRI dataset (28 subjects: 20 MS + 8 controls, baseline `ses-1`) on the BYU
supercomputer, using modern reproducible **BIDS-App containers** while also
opening the hood on one signature low-level step per modality.

Full project plan: [`PLAN.md`](PLAN.md).

## This repo holds ONLY code
Kilobytes of scripts and notes. **No data, derivatives, containers, or templates
are ever committed** (see `.gitignore`). Those live outside the repo:

| What | Location | Tier |
|---|---|---|
| Raw BIDS data (170 GB, DataLad) | `/nobackup/archive/usr/bradenf4/personal_projects/ms_dataset/BIDS/ds007908` | archive — persistent, slow |
| Derivatives, work, containers, templateflow, logs | `/nobackup/autodelete/usr/bradenf4/ms_dataset/` | autodelete — **fast, purged after 12 wks idle** |
| This code repo | `/home/bradenf4/ms-mri-analysis` | home — fast, **backed up** |

**Why this split** (BYU RC [Storage docs](https://rc.byu.edu/wiki/?id=Storage),
confirmed 2026-06-30): archive is the slow, persistent tier and "should generally
NOT be used directly from batch jobs"; autodelete is fast but deletes files
unused for 12 weeks. So jobs **read** raw data from archive (read-only) and
**write** all outputs to autodelete. Code stays in home because it's backed up
and never purged. All paths are centralized in [`setup/config.sh`](setup/config.sh) —
source it; don't hardcode paths in scripts.

> ⚠️ **Purge guard:** if the project goes idle, derivatives on autodelete vanish
> after 12 weeks (7-day `.snapshot` grace). When a stage is final, rsync it to
> `$DERIV_ARCHIVE` on archive for retention.

## Environment (BYU, verified 2026-06-30)
- Login node `login02/03` has internet; **compute nodes do not** — all downloads
  (`datalad get`, `apptainer build`, TemplateFlow, `git push`) run on the login
  node inside `tmux`. BIDS Apps run in SLURM jobs using pre-staged containers.
- Modules: `apptainer/1.4.5-hehrqcp`, `nodejs/18.19`, `miniconda3/24.3.0`.
  `gh` is **not** available → GitHub over SSH.
- conda env `datalad` (datalad + git-annex). Activate: `module load miniconda3 && source activate datalad`.

## Layout
```
setup/     one-time setup: container pulls, templateflow fetch, FS license, bids-validate
slurm/     BIDS-App SLURM batch scripts (pilot first, then --array over all 28)
lowlevel/  "open the hood" scripts reproducing one key step per modality
notes/     lab notebook, one markdown file per modality
setup/config.sh   <-- central paths & pinned container versions
```

## Workflow per modality ("run it, then open the hood")
1 = sMRIPrep (anat) · 2 = fMRIPrep (multi-echo func, +tedana) · 3 = QSIPrep (dwi) ·
4 = ASLPrep (perfusion). For each: SLURM BIDS-App run → manual low-level
signature step → notes. See `PLAN.md` for the full table and the under-the-hood
step per modality.

## Status
See `PLAN.md` and `notes/`. Pilot subject: **sub-0040**.
