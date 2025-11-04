# 🧬 BioEmu Sidechain Rebuilding Protocol

**Project:** BioEmu – Multisite Domain Reconstruction  
**Task:** Rebuild sidechains after structure sampling  
**System:** Alvis HPC (CPU/GPU nodes)  
**Maintainer:** [Your Lab / Name]  
**Last updated:** YYYY-MM-DD  

---

## 📘 Overview

This protocol describes how to perform **sidechain rebuilding**  
for previously sampled protein domains (from `bioemu.sample`).

Each job takes the sampled topology (`topology.pdb`)  
and trajectory (`samples.xtc`), rebuilds all sidechains,  
and writes new PDB/trajectory outputs for further refinement.

---

## ⚙️ Requirements

| Component | Path / Version | Description |
|------------|----------------|--------------|
| Base path | `/mimer/NOBACKUP/groups/naiss2025-5-451/Bioemu` | Project root |
| Input data | `/mimer/.../outputs/multisite` | From sampling step |
| Python environment | `/mimer/.../venvs/bioemu-md` | Includes BioEmu |
| Scheduler | SLURM | Jobs run on Alvis cluster |
| Node type | A100 GPU nodes | Each job uses one GPU |

---

## 📄 Input Files

The input directories are created automatically by the **sampling step**.

Expected structure:
outputs/multisite/

├── Q8CFI0-3/

│ ├── Q8CFI0-3_S12-S16-S20_E/

│ │ ├── topology.pdb

│ │ ├── samples.xtc

│ │ └── MANIFEST_sampling.txt

│ └── Q8CFI0-3_S12-S16-S20_Neutral/

│ ├── topology.pdb

│ ├── samples.xtc

│ └── MANIFEST_sampling.txt

└── ...


---

## 🚀 Universal SLURM Script

File:  
`run_bioemu_rebuild_generic.sh`

This script can rebuild all variants (`E`, `Neutral`, or `ALL`)  
using the same manifest file used during sampling.

### 🔧 Usage

```bash
sbatch --array=1-N%MAX \
  run_bioemu_rebuild_generic.sh \
  MANIFEST_PATH \
  INPUT_ROOT \
  OUTPUT_ROOT \
  VARIANT_FILTER
```

🧮 Submitting Jobs

Step 1 — Count number of tasks

```
cd /mimer/NOBACKUP/groups/naiss2025-5-451/Bioemu

NE=$(awk 'BEGIN{FS="\t"} NR>1 && $5=="E"{c++} END{print c}' manifests/manifest_multi_sites.tsv)
NN=$(awk 'BEGIN{FS="\t"} NR>1 && $5=="Neutral"{c++} END{print c}' manifests/manifest_multi_sites.tsv)

echo "E variants:       $NE"
echo "Neutral variants: $NN"
```

Step 2 — Submit jobs per variant (E variant):

```
sbatch --array=1-$NE%50 \
  run_bioemu_rebuild_generic.sh \
  manifests/manifest_multi_sites.tsv \
  outputs/multisite \
  outputs/multisite_rebuilt \
  E
```
Neutral variant:

```
sbatch --array=1-$NN%50 \
  run_bioemu_rebuild_generic.sh \
  manifests/manifest_multi_sites.tsv \
  outputs/multisite \
  outputs/multisite_rebuilt \
  Neutral
```

Run all variants together:

```
N=$(( $(wc -l < manifests/manifest_multi_sites.tsv) - 1 ))

sbatch --array=1-$N%50 \
  run_bioemu_rebuild_generic.sh \
  manifests/manifest_multi_sites.tsv \
  outputs/multisite \
  outputs/multisite_rebuilt \
  ALL
```

🧩 Inside the Script

The script:

Reads a specific line from the manifest (filtered by variant type)

Finds corresponding input files in INPUT_ROOT/<protein>/<task_tag>

Runs the rebuilding command

Saves all outputs into the same relative path under OUTPUT_ROOT

Rebuilding command (replace with your version):

```
srun --cpu-bind=cores python -u -m bioemu.rebuild_sidechains \
  --input_trajectory "$XTC" \
  --input_topology   "$PDB" \
  --output_dir       "$OUTDIR"
```

Replace this with your actual module/arguments as needed.

✅ Output Check

Each completed task should include:

File	Description
rebuilt_topology.pdb	Rebuilt sidechain structure
rebuilt_samples.xtc	Rebuilt trajectory (if applicable)
MANIFEST_rebuild.txt	Record of rebuild metadata
🩺 Troubleshooting
Symptom	Cause	Fix
Missing input sampling files	Sampling step not completed	Verify samples.xtc and topology.pdb exist
No output files found	Rebuild script error	Check .out log
No matching row for VARFILTER	Index too high	Adjust --array range
Job killed	Wrong GPU config	Keep --gpus-per-node=A100:1
🧠 Tips

The same manifest can be reused across sampling and rebuilding.

You can easily rerun only failed jobs by limiting the array range.

This structure allows full reproducibility and clear job tracking.
