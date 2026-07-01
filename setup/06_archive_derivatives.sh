#!/bin/bash
# Phase 2/3 — RETENTION: copy finished derivatives from autodelete -> archive.
#
# $DERIV lives on /nobackup/autodelete, which PURGES files unused for 12 weeks.
# When a stage is FINAL, run this to snapshot its outputs onto the persistent
# archive tier ($DERIV_ARCHIVE) so they survive the purge (README "purge guard").
#
# Usage:
#   bash setup/06_archive_derivatives.sh                       # archive ALL of $DERIV
#   bash setup/06_archive_derivatives.sh smriprep              # just the sMRIPrep outputs
#   bash setup/06_archive_derivatives.sh smriprep lowlevel/anatomical/sub-0040
#       -> archive only those subpaths (each RELATIVE to $DERIV)
#
# NB: this is a SNAPSHOT copy, not a live sync — re-run it after you regenerate
# outputs. rsync -a only transfers changed/new files, so re-runs are cheap.
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/config.sh"

# Subpaths (relative to $DERIV) to archive; default to the whole tree.
targets=("$@")
[[ ${#targets[@]} -eq 0 ]] && targets=(".")

for t in "${targets[@]}"; do
    src="$DERIV/$t"
    dst="$DERIV_ARCHIVE/$t"
    if [[ ! -e "$src" ]]; then
        echo "[skip] no such path under \$DERIV: $t"; continue
    fi
    mkdir -p "$(dirname "$dst")"
    echo "[`date`] rsync  $src  ->  $dst"
    # -a: recurse + preserve times/perms/symlinks. Trailing slash on src copies
    # its CONTENTS into dst (not dst/<name>/<name>).
    rsync -a --info=stats2 "$src/" "$dst/"
done

echo "[`date`] retention copy complete. Archive tree now:"
du -sh "$DERIV_ARCHIVE" 2>/dev/null || true
