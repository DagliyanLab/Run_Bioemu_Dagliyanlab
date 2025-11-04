# 🧬 BioEmu Multisite Sampling Protocol

**Project:** BioEmu – multi-phosphorylation domain structural sampling  
**System:** Alvis HPC (A100 GPU nodes)  
**Maintainer:** [Dagliyanlab / Tara]  
**Last updated:** 2025-11-04  

---

## 📘 Overview

This protocol documents how to run **BioEmu** for proteins that contain  
**multiple phosphorylation sites in the same domain sequence**.

Each SLURM job performs a 3,000-sample structural simulation  
for one protein variant (either `E` or `Neutral`).

---

## ⚙️ System Requirements

| Component | Path / Version | Notes |
|------------|----------------|-------|
| Python environment | `/mimer/NOBACKUP/groups/naiss2025-5-451/Bioemu/venvs/bioemu-md` | Contains BioEmu |
| Project root | `/mimer/NOBACKUP/groups/naiss2025-5-451/Bioemu` | Base directory |
| GPU nodes | `A100` (4 per node) | Use one per job |
| Scheduler | SLURM | Jobs submitted via `sbatch` |

---

## 📁 Directory Layout

Bioemu/

├── manifests/

│ └── manifest_multi_sites.tsv

├── outputs/

│ └── multisite/ ← sampling results

├── logs/ ← job logs

├── caches/embeds/ ← embedding cache

├── caches/so3/

├── venvs/bioemu-md/ ← Python venv

└── run_bioemu_generic.sh ← universal SLURM script




