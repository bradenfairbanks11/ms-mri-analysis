#!/bin/bash
# ============================================================
# Central path config for the MS-MRI analysis project.
# Source this at the top of every setup/slurm/lowlevel script:
#     source "$(dirname "$0")/../setup/config.sh"
#
# Storage strategy (decided 2026-06-30, see README / BYU RC docs):
#   - RAW data        -> /nobackup/archive   (persistent, slow, never purged)
#   - DERIVATIVES/work -> /nobackup/autodelete (fast; PURGED after 12 wks idle)
#   - CODE            -> /home (this repo; backed up; never purged)
# BYU docs: archive "should generally NOT be used directly from batch jobs",
# so jobs READ raw data from archive (ro) but WRITE all outputs to autodelete.
# ============================================================

# ---- Raw data (archive, persistent) ----
export ARCHIVE_ROOT=/nobackup/archive/usr/bradenf4/personal_projects/ms_dataset
export RAW=$ARCHIVE_ROOT/BIDS/ds007908            # BIDS dataset root (DataLad)

# ---- Compute outputs (autodelete, fast) ----
export COMPUTE_ROOT=/nobackup/autodelete/usr/bradenf4/ms_dataset
export DERIV=$COMPUTE_ROOT/derivatives
export WORK=$COMPUTE_ROOT/work
export LOGS=$COMPUTE_ROOT/logs

# ---- Software: /home, NOT autodelete (fixed 2026-08-19) ----
# These used to live under $COMPUTE_ROOT. That is the 12-week-unused purge tier, so the
# containers and the TemplateFlow cache would silently vanish while this project is
# parked, and jobs would fail at some random future date. Worse, compute nodes have NO
# internet — a purged container cannot be re-pulled from inside a job. /home is backed
# up, never purged, and has 2 TB free. Shared with ~/spirituality_fmri and
# ~/missionary_language, which use the same TemplateFlow archive.
export CONTAINERS=$HOME/software/containers
export TEMPLATEFLOW_HOME=$HOME/software/templateflow

# ---- Retention copy on archive (rsync derivatives here when a stage is final) ----
export DERIV_ARCHIVE=$ARCHIVE_ROOT/derivatives_archive

# ---- Software / licenses ----
export FS_LICENSE=$HOME/.freesurfer_license.txt
export CONDA_ENV=datalad                            # module load miniconda3 && source activate $CONDA_ENV

# ---- Pinned container versions (verified latest stable 2026-06-30) ----
# Matched NiPreps 2025 generation so fMRIPrep can reuse sMRIPrep's anat outputs.
# Docker images: nipreps/smriprep, nipreps/fmriprep, pennlinc/qsiprep, pennlinc/aslprep.
# NOTE: as of QSIPrep 26.x, reconstruction is a SEPARATE app (QSIRecon) — pull it
# too when you reach Phase 3 diffusion recon.
export SMRIPREP_VER=0.19.1
export FMRIPREP_VER=25.2.5      # LTS
export QSIPREP_VER=26.0.0
export ASLPREP_VER=26.0.3
export SYNTHSTRIP_VER=1.8         # standalone FreeSurfer SynthStrip (for low-level skull-strip comparison)

# ---- Apptainer module (BYU) ----
export APPTAINER_MODULE=apptainer/1.4.5-hehrqcp

# Make output dirs on demand (safe: autodelete + home only, never archive)
mkdir -p "$DERIV" "$CONTAINERS" "$TEMPLATEFLOW_HOME" "$WORK" "$LOGS"
