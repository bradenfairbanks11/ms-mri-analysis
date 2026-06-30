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
export CONTAINERS=$COMPUTE_ROOT/containers
export TEMPLATEFLOW_HOME=$COMPUTE_ROOT/templateflow
export WORK=$COMPUTE_ROOT/work
export LOGS=$COMPUTE_ROOT/logs

# ---- Retention copy on archive (rsync derivatives here when a stage is final) ----
export DERIV_ARCHIVE=$ARCHIVE_ROOT/derivatives_archive

# ---- Software / licenses ----
export FS_LICENSE=$HOME/.freesurfer_license.txt
export CONDA_ENV=datalad                            # module load miniconda3 && source activate $CONDA_ENV

# ---- Pinned container versions (edit when bumping; keep reproducible) ----
export SMRIPREP_VER=0.16.1
export FMRIPREP_VER=25.1.4
export QSIPREP_VER=1.0.1
export ASLPREP_VER=0.7.5

# ---- Apptainer module (BYU) ----
export APPTAINER_MODULE=apptainer/1.4.5-hehrqcp

# Make output dirs on demand (safe: autodelete only)
mkdir -p "$DERIV" "$CONTAINERS" "$TEMPLATEFLOW_HOME" "$WORK" "$LOGS"
