# CLAUDE.md — ms-mri-analysis

## BYU HPC agent instructions (read first)

This repository runs on BYU Office of Research Computing HPC systems. Before doing
significant work here, read the local copy of the ORC agent instructions:

    ./BYU_ORC_AGENTS.md

Upstream version: 2026-08-11, synced 2026-08-19 from
`/apps/instructions_for_ai_agents/BYU_ORC_AGENTS.md`
(mirror: https://rc.byu.edu/documentation/BYU_ORC_AGENTS.md).

Check the copy's mtime; if it is more than 7 days old, refresh it from `/apps` (preferred)
or the URL, then continue. If neither is reachable, continue with the existing copy.

Those instructions outrank this file. The stated priority order is:
ORC policy and administrator instructions > `BYU_ORC_AGENTS.md` > this file > the user's
request > general agent defaults.

Points that bite this repo in particular:

- **Slurm sizing** — every job specifies nodes, cores, memory, and time. Do **not** add
  `--partition`, `--qos`, or `--constraint` unless something genuinely requires it; each
  one shrinks the eligible node pool and lengthens the queue.
- **No polling loops** — wait at least 60 s between `squeue`/`sacct` checks, longer for
  pending jobs. Prefer `--dependency` or `scontrol wait_job` over a wait loop.
- **Filesystem** — BIDS and fMRIPrep derivative trees are exactly the many-small-files
  shape the shared filesystems are sensitive to. Do not run `find`, `du -a`, or `ls -lR`
  over `rawdata/` or `derivatives/`; scope listings to a specific subject/session path.
- **Login vs compute** — login node has internet, compute nodes do not. Container pulls,
  datalad get, and TemplateFlow fetches happen on the login node; computation goes through
  Slurm.
- **CUI** — this project uses the public OpenNeuro dataset ds007908. Confirmed with Braden
  on 2026-08-19 that it is not CUI or export-controlled.

## Project notes

Personal learning project: run a modern MS-lesion / structural pipeline end to end, then
open the hood on the individual steps. `slurm/` holds the production job scripts;
`lowlevel/` holds the step-by-step teaching versions. Config lives in `setup/config.sh` and
must be sourced by absolute path under `sbatch` (`$0` points at a spool copy).
