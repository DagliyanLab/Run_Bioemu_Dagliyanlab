# 🧬 BioEmu Multisite Structural Sampling & Reconstruction

**Repository for:** automated sampling and sidechain reconstruction  
of multi-phosphorylation domain variants using **BioEmu** on the  
**Alvis HPC (Sweden)** cluster.

---

## 📘 Overview

This repository provides ready-to-use SLURM workflows for:
1. **Sampling** – generating 3,000 conformations per protein variant.  
2. **Sidechain Reconstruction** – rebuilding sampled models with full sidechains.

Each stage is generic, modular, and fully compatible with future datasets.


---

## ⚙️ System Requirements

| Component | Requirement |
|------------|--------------|
| HPC system | Alvis (Chalmers, NAISS) |
| Scheduler | SLURM |
| GPU nodes | A100 (4 GPUs per node) |
| Python | 3.11+ |
| BioEmu env | `/mimer/.../venvs/bioemu-md` |

---

## 🚀 Quickstart

### 1️⃣ Sampling Phase
```bash
sbatch --array=1-$N%50 run_bioemu_generic.sh \
  manifests/manifest_multi_sites.tsv \
  outputs/multisite \
  E
```
2️⃣ Sidechain Rebuilding Phase

```
sbatch --array=1-$N%50 run_bioemu_rebuild_generic.sh \
  manifests/manifest_multi_sites.tsv \
  outputs/multisite \
  outputs/multisite_rebuilt \
  E
```

🧩 Replace E with Neutral or ALL as needed.

🧾 Manifest Format
Column	Description
task_id	Unique integer
protein	Protein ID
residue	Mutated residues
site_in_domain	Site positions in domain
variant	E / Neutral
task_tag	Unique name per variant
sequence	Domain amino acid sequence

📊 Outputs
Stage	Directory	Description
Sampling	outputs/multisite	Raw sampled conformations
Rebuild	outputs/multisite_rebuilt	Sidechain-complete structures
📈 Monitoring

```
squeue -u $USER              # View running jobs
less logs/sampling_*.out     # Check sampling logs
less logs/rebuild_*.out      # Check rebuild logs
```

🧠 Extending

Add new manifests with identical column format

Use the same scripts for new experiments

Change only:

Input manifest path

Output directory

Variant tag (E, Neutral, ALL)


