🧮 Step-by-Step: Job Submission
1️⃣ Count the number of jobs per variant
cd /mimer/NOBACKUP/groups/naiss2025-5-451/Bioemu

NE=$(awk 'BEGIN{FS="\t"} NR>1 && $5=="E"{c++} END{print c}' \
  manifests/manifest_multi_sites.tsv)

NN=$(awk 'BEGIN{FS="\t"} NR>1 && $5=="Neutral"{c++} END{print c}' \
  manifests/manifest_multi_sites.tsv)

echo "E variants:       $NE"
echo "Neutral variants: $NN"

2️⃣ Submit E-variant jobs
sbatch --array=1-$NE%50 \
  run_bioemu_generic.sh \
  manifests/manifest_multi_sites.tsv \
  outputs/multisite \
  E

3️⃣ Submit Neutral-variant jobs
sbatch --array=1-$NN%50 \
  run_bioemu_generic.sh \
  manifests/manifest_multi_sites.tsv \
  outputs/multisite \
  Neutral

4️⃣ (Optional) Run all variants at once
N=$(( $(wc -l < manifests/manifest_multi_sites.tsv) - 1 ))

sbatch --array=1-$N%50 \
  run_bioemu_generic.sh \
  manifests/manifest_multi_sites.tsv \
  outputs/multisite \
  ALL

🧠 %50 controls maximum concurrency (adjust per available GPUs).

🧩 Extending to New Datasets

Use the same script for any future manifest with the same column structure.
Just change:

Input manifest path

Output root

Variant tag (e.g. E, Neutral, ALL)

Example:

sbatch --array=1-$N%50 \
  run_bioemu_generic.sh \
  manifests/new_dataset.tsv \
  outputs/new_dataset \
  ALL

🧠 Notes

Each task uses one GPU and defaults to 3,000 samples.

Temporary files are cleaned automatically.

All cache and config files are restricted to the project base directory.

Tested on Alvis (A100) with Python 3.11 + Torch CUDA support.
