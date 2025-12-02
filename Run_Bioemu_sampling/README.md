🧮 Step-by-Step: Job Submission	

1️⃣ Count the number of jobs per variant

```
cd /mimer/NOBACKUP/groups/naiss2025-5-451/Bioemu

4️⃣ (Optional) Run all variants at once

N=$(( $(wc -l < manifests/manifest_multi_sites.tsv) - 1 ))

sbatch --array=1-$N%50 \
  run_bioemu_generic.sh \
  manifests/manifest_multi_sites.tsv \
  outputs/multisite \
  ALL \
  1000
```
The last 1000 stands for seed; for multiple batches, the job should be submitted multiple times with different seeds.

🧩 Extending to New Datasets

Use the same script for any future manifest with the same column structure.
Just change:

Input manifest path

Output root

Variant tag (e.g. E, Neutral, ALL)

Example:
```
sbatch --array=1-$N%50 \
  run_bioemu_generic.sh \
  manifests/new_dataset.tsv \
  outputs/new_dataset \
  ALL \
  1000
```
🧠 Notes

Each task uses one GPU and defaults to 3,000 samples.

Temporary files are cleaned automatically.

All cache and config files are restricted to the project base directory.

Tested on Alvis (A100) with Python 3.11 + Torch CUDA support.
