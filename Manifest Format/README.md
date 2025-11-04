
---

## 📄 Manifest Format (`.tsv`)

Example: `manifests/manifest_multi_sites.tsv`

| Column | Example | Description |
|--------|----------|-------------|
| `task_id` | 1 | Unique numeric index |
| `protein` | Q8CFI0-3 | UniProt or ID |
| `residue` | S;S;S | Residues mutated |
| `site_in_domain` | 12;16;20 | Domain site positions |
| `variant` | E / Neutral | Mutation type |
| `task_tag` | Q8CFI0-3_S12-S16-S20_E | Unique task label |
| `sequence` | MIRLQKNTANIRNIC... | Domain sequence used for sampling |

🧩 **Important:**
- Only domains with ≥2 phosphorylation sites are included.
- `variant` column controls whether to run `E`, `Neutral`, or `WT` sampling.
- The sequence already reflects the variant substitution.
