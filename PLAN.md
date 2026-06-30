# Briefing for Claude running on the BYU supercomputer

> **Cluster-session adaptations (applied 2026-06-30 on `login02`).** The original
> briefing below assumed `/nobackup/archive` was fast scratch with no purge. Verified
> against [BYU RC Storage docs](https://rc.byu.edu/wiki/?id=Storage) — it is the
> *slow, persistent* tier ("should generally NOT be used directly from batch jobs"),
> while `/nobackup/autodelete` is fast but purges files unused for 12 weeks. So:
> - **Raw data** stays on archive (persistent): `/nobackup/archive/usr/bradenf4/personal_projects/ms_dataset/BIDS/ds007908`
> - **Derivatives / containers / templateflow / work / logs** go on autodelete (fast): `/nobackup/autodelete/usr/bradenf4/ms_dataset/`
> - **Code repo** lives in `/home/bradenf4/ms-mri-analysis` (home is backed up, never purged) instead of a sibling `code/` dir.
> - `gh` is **not** available on this cluster → GitHub auth uses SSH (existing `~/.ssh/id_rsa`).
> - Paths centralized in `setup/config.sh`. Retention copies go to `$DERIV_ARCHIVE`.

You are Claude Code running on a BYU supercomputer **login node** (SLURM cluster, Apptainer
container runtime). A previous planning session (running on the user's Mac) produced this plan; you
are picking it up fresh. First, verify your environment: run `hostname`, `uname -a`,
`module spider apptainer`, and `module spider gh nodejs`. Then proceed.

## Who the user is / what they want
Braden is learning to analyze MRI data. He already has some AFNI/fMRI first-level experience but is
new to ASL, multi-shell DWI, and multi-echo fMRI. **Goal:** learn to analyze all four modalities in
the dataset below using modern reproducible **BIDS-App containers** as the backbone, *while also*
understanding the **low-level mechanics** of the key steps (the "run it, then open the hood" design
in Phase 3). He wants a **code-only git repo** that is kept strictly separate from the 170 GB of data.

## The dataset: OpenNeuro ds007908
"Multi-scale, multi-modal imaging assessment of trajectories of cognitive impairment in Multiple
Sclerosis" (3T Siemens Prisma, 64-ch coil, Weill Cornell). v1.0.0 = **20 MS patients + 8 healthy
controls = 28 subjects, one baseline session each (ses-1)**. It is a DataLad/git-annex dataset
(~170 GB) — the `.nii.gz` files are git-annex symlinks until fetched with `datalad get`.

Dataset root: `/nobackup/archive/usr/bradenf4/personal_projects/ms_dataset/BIDS/ds007908`

Per subject (`sub-XXXX/ses-1/`):
| Folder | What it is | Notable detail |
|--------|-----------|----------------|
| `anat` | T1w MPRAGE | 0.8 mm isotropic, defaced |
| `func` | resting-state fMRI | **multi-echo (5 echoes)**, up to 2 runs (some have 1) |
| `dwi`  | diffusion | multi-shell HCP-Lifespan, ~92 dir/shell, b=1500 & 3000, AP+PA |
| `perf` | pCASL perfusion | 11 control/label pairs, 2 s PLD |
| `fmap` | fieldmaps | blip-up/blip-down spin-echo EPI pairs for distortion correction |

## Critical environment facts (already established with the user)
- **Login node has internet; COMPUTE NODES DO NOT.** Everything that downloads (datalad `get`,
  `apptainer build` from docker://, TemplateFlow, git push) MUST run on the **login node**, inside
  `tmux` so it survives disconnects. BIDS Apps then run in SLURM jobs on compute nodes using
  pre-staged containers/templates.
- Scheduler: **SLURM** (`salloc` for interactive, `sbatch` for batch). Container runtime: **Apptainer**.
- Storage: see the cluster-adaptation note at the top. Archive = persistent/slow, autodelete =
  fast/purged-after-12-weeks. Confirmed via BYU RC docs.
- The user has a conda env named `datalad` (made via `module load miniconda3 && conda create -n
  datalad -c conda-forge datalad git-annex`). Activate with `module load miniconda3 && source
  activate datalad`.
- No GitHub account yet — set one up (Phase 0b).

---

## Phase 0 — GitHub setup (Claude-on-cluster is already done)
Claude Code is already installed and running on the login node (that's you). Now:
1. User creates a GitHub account at github.com (browser).
2. Authenticate on the login node — `gh` is unavailable here, so use SSH: existing key
   `~/.ssh/id_rsa.pub`, add it to GitHub, and `ssh -T git@github.com` to verify.
3. Create an empty repo, e.g. `ms-mri-analysis` (private is fine; the data is already public CC0).

## Phase 1 — Project scaffold + code-only git repo
Only `code/` (here: `/home/bradenf4/ms-mri-analysis`) is a git repo; data/derivatives/containers/
templateflow/logs all live outside it (see config.sh). Repo subdirs: `setup/`, `slurm/`,
`lowlevel/`, `notes/`, plus `.gitignore`, `README.md`, `PLAN.md`.
Then `git init`, write `.gitignore` FIRST, commit, add remote, push.

## Phase 2 — One-time setup (login node, internet required), scripts in setup/
1. **Pilot subject first — do NOT wait on the full 170 GB.** `datalad get -J 4 sub-0040` (one
   subject, all modalities) to develop the workflow; scale to all 28 later.
2. **BIDS-validate**: `apptainer run docker://bids/validator <ds007908>` (or deno bids-validator).
3. **FreeSurfer license** (required by sMRIPrep/fMRIPrep/QSIPrep/ASLPrep): register at
   surfer.nmr.mgh.harvard.edu, save to `~/.freesurfer_license.txt`.
4. **Pre-pull containers** to `$CONTAINERS` (pin exact versions for reproducibility):
   `apptainer build $CONTAINERS/smriprep.sif docker://nipreps/smriprep:<ver>` and likewise
   `nipreps/fmriprep`, `pennlinc/qsiprep`, `nipreps/aslprep`.
5. **Pre-download TemplateFlow** to `$TEMPLATEFLOW_HOME` (compute nodes can't fetch at runtime — the
   #1 cause of BIDS-App crashes on HPC):
   `TEMPLATEFLOW_HOME=$TEMPLATEFLOW_HOME python -c "from templateflow.api import get;
   get(['MNI152NLin2009cAsym','MNI152NLin6Asym','OASIS30ANTs','fsLR','fsaverage'])"`

## Phase 3 — Integrated learning workflow ("Run it, then open the hood")
For EACH modality, produce three artifacts:
1. `slurm/<modality>.sh` — SLURM batch script running the BIDS App via Apptainer on the pilot
   subject (later a `--array=0-27%4` job over all 28).
2. `lowlevel/<modality>_underthehood.{sh,ipynb}` — manually reproduce ONE or TWO signature steps
   with low-level tools on the same subject; compare to the app's output.
3. `notes/<modality>.md` — lab notebook: what the pipeline did stage-by-stage, how the manual step
   maps onto it, and the QC examined.

Common BIDS-App run pattern (binds handle the offline-node problem):
```bash
export APPTAINERENV_FS_LICENSE=~/.freesurfer_license.txt
export APPTAINERENV_TEMPLATEFLOW_HOME=/opt/templateflow
apptainer run --cleanenv \
  -B $RAW:/data:ro -B $DERIV:/out -B $WORK:/work -B $TEMPLATEFLOW_HOME:/opt/templateflow \
  $CONTAINERS/<app>.sif /data /out participant --participant-label 0040 -w /work [opts]
```

Order (each reuses the previous anatomical), with the signature low-level step:
| # | Modality | BIDS App | "Open-the-hood" low-level step |
|---|----------|----------|--------------------------------|
| 1 | Anatomical | sMRIPrep | Skull-strip (BET/SynthStrip), N4 bias correction, tissue seg (FSL FAST) -> compare brain mask + GM/WM/CSF to sMRIPrep. Optional `recon-all` to see surfaces. |
| 2 | Functional | fMRIPrep (reuse anat) | Multi-echo: echo combination + **tedana** ME-ICA denoising; manual `mcflirt`; inspect fMRIPrep confounds; one seed-based connectivity map. |
| 3 | Diffusion | QSIPrep + QSIRecon | Manual `dwidenoise` -> tensor fit (`dtifit`) -> FA/MD; understand `topup`/`eddy` using AP/PA fmaps. Optional MRtrix3 CSD + tractography taste. |
| 4 | Perfusion | ASLPrep (reuse anat) | **Hand-compute CBF** from control-label pairs with the single-compartment pCASL kinetic model in Python/nibabel -> compare to ASLPrep's CBF map. |

Then scale out to all 28 subjects with SLURM `--array` jobs writing to `$LOGS`. Finish with
`notes/group.md` for simple MS-vs-control group comparisons once derivatives exist.

## Verification checklist
- `git status` in the repo shows no data/derivatives staged; GitHub shows only scripts/notes; repo < a few MB.
- bids-validator passes (or only expected warnings); four `.sif` images present; `$TEMPLATEFLOW_HOME`
  populated; FreeSurfer license present.
- Per modality (pilot sub-0040): BIDS-App HTML QC report looks sane; expected derivatives exist
  (sMRIPrep brain mask; fMRIPrep desc-preproc_bold + confounds; QSIPrep preprocessed DWI + FA map;
  ASLPrep CBF map); low-level output visually matches the app for that step; notes written.
- Scale-out: `--array` job completes for all 28 with no failed tasks in `$LOGS`.

## Open items to confirm early
- `/nobackup` purge policy — **RESOLVED 2026-06-30**: autodelete purges after 12 weeks idle; archive
  persistent but slow. See top note.
- Exact BYU module names — **RESOLVED**: `apptainer/1.4.5-hehrqcp`, `nodejs/18.19`, `miniconda3/24.3.0`; `gh` absent.
- Pin specific BIDS-App container versions — defaults set in `setup/config.sh`; **verify latest stable before building**.
