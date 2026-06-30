# FreeSurfer license (required by sMRIPrep / fMRIPrep / QSIPrep / ASLPrep)

These BIDS Apps refuse to run without a valid FreeSurfer license file. It's free.

## One-time steps (Braden — browser action)
1. Register at https://surfer.nmr.mgh.harvard.edu/registration.html (free).
2. You'll receive a `license.txt` (a few lines: email, a number, two keys).
3. Put it on the cluster at the path the scripts expect:
   ```
   ~/.freesurfer_license.txt
   ```
   e.g. paste the contents:
   ```
   nano ~/.freesurfer_license.txt    # paste, save
   chmod 600 ~/.freesurfer_license.txt
   ```

The scripts pass it into containers via `APPTAINERENV_FS_LICENSE` (see `config.sh`
`$FS_LICENSE`). It is gitignored — never committed.

## Shortcut
You already have a FreeSurfer license from your other fMRIPrep work at:
`/nobackup/archive/usr/bradenf4/software/fmri_prep/preprocessing/license.txt`
If that's still valid you can just reuse it:
```
cp /nobackup/archive/usr/bradenf4/software/fmri_prep/preprocessing/license.txt ~/.freesurfer_license.txt
chmod 600 ~/.freesurfer_license.txt
```
