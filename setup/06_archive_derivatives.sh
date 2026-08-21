#!/bin/bash
# Phase 2/3 — RETENTION: copy finished derivatives from autodelete -> archive.
#
# $DERIV lives on /nobackup/autodelete, which PURGES files unused for 12 weeks.
# When a stage is FINAL, run this to snapshot its outputs onto the persistent
# archive tier ($DERIV_ARCHIVE) so they survive the purge (README "purge guard").
#
# Usage:
#   bash setup/06_archive_derivatives.sh smriprep              # just the sMRIPrep outputs
#   bash setup/06_archive_derivatives.sh smriprep lowlevel/anatomical/sub-0040
#       -> archive only those subpaths (each RELATIVE to $DERIV)
#
# TARGETS ARE NOW REQUIRED (changed 2026-08-21).
#   This used to default to "." — the ENTIRE $DERIV tree — so running it bare
#   pushed smriprep/, lesion/, and every hand-run lowlevel/ ANTs/FSL intermediate
#   onto archive. Archive is for things worth keeping forever; scratch is for
#   intermediates you can regenerate. Retention should be a decision per finished
#   stage, not a reflex. Name what you mean.
#
# Archive is capped at 1 M inodes and is migrating to a much slower backing store,
# so it is a bad host for many-small-file trees. Before archiving something large
# and file-dense, consider tarring it (ORC's small-file guidance) — see
# ~/spirituality_fmri/scripts/promote_to_archive.sh for that pattern.
#
# NB: this is a SNAPSHOT copy, not a live sync — re-run it after you regenerate
# outputs. rsync -a only transfers changed/new files, so re-runs are cheap.
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/config.sh"

# Subpaths (relative to $DERIV) to archive. No default: see above.
targets=("$@")
if [[ ${#targets[@]} -eq 0 ]]; then
    echo "ERROR: name at least one subpath under \$DERIV to archive." >&2
    echo >&2
    echo "  \$DERIV = $DERIV" >&2
    echo "  available:" >&2
    for d in "$DERIV"/*/; do [[ -d "$d" ]] && echo "    $(basename "$d")" >&2; done
    echo >&2
    echo "  e.g.  bash setup/06_archive_derivatives.sh smriprep" >&2
    echo >&2
    echo "Refusing to archive all of \$DERIV by default — that is how scratch" >&2
    echo "intermediates end up permanently on the archive tier." >&2
    exit 2
fi
for t in "${targets[@]}"; do
    if [[ "$t" == "." || "$t" == "./" || "$t" == "/" ]]; then
        echo "ERROR: '$t' means the whole \$DERIV tree. Name specific subpaths instead." >&2
        exit 2
    fi
done

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
