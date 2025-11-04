#!/usr/bin/env bash
#SBATCH -A naiss2025-5-451
#SBATCH -p alvis
#SBATCH -J bioemu-rebuild
#SBATCH --gpus-per-node=A100:1
#SBATCH -t 5-00:00:00
#SBATCH -o /mimer/NOBACKUP/groups/naiss2025-5-451/Bioemu/logs/rebuild_%x_%A_%a.out
#SBATCH -e /mimer/NOBACKUP/groups/naiss2025-5-451/Bioemu/logs/rebuild_%x_%A_%a.err

set -euo pipefail

# ===== 参数检查 =====
if [ $# -lt 4 ]; then
  echo "Usage: $0 MANIFEST_PATH INPUT_ROOT OUTPUT_ROOT VARIANT_FILTER(E|Neutral|ALL)" >&2
  exit 1
fi

MANIFEST="$1"      # e.g. /.../manifests/manifest_multi_sites.tsv
INPUT_ROOT="$2"    # e.g. /.../outputs/multisite
OUTPUT_ROOT="$3"   # e.g. /.../outputs/multisite_rebuilt
VARFILTER="$4"     # E / Neutral / ALL

# ===== 固定路径 =====
BASE=/mimer/NOBACKUP/groups/naiss2025-5-451/Bioemu
VENV="$BASE/venvs/bioemu-md"
LOGROOT="$BASE/logs"
mkdir -p "$LOGROOT" "$BASE/caches/embeds" "$BASE/caches/so3" "$BASE/work"

# ===== 每个任务自己的 work 目录（所有临时/缓存都放这里）=====
WID="${SLURM_JOB_ID:-manual}.${SLURM_ARRAY_TASK_ID:-0}"
WORK="$BASE/work/$WID"
mkdir -p "$WORK"

# ===== 严格约束所有写入路径到 BASE =====
export HOME="$BASE"                    # 避免写到真实家目录
export TMPDIR="$WORK/tmp"; mkdir -p "$TMPDIR"
export TMP="$TMPDIR"; export TEMP="$TMPDIR"
export PYTHONPYCACHEPREFIX="$WORK/pycache"

# HF/Transformers 缓存
export HF_HOME="$BASE/hf_home";                 mkdir -p "$HF_HOME"
export HF_HUB_CACHE="$BASE/hf_hub_cache";       mkdir -p "$HF_HUB_CACHE"
export TRANSFORMERS_CACHE="$BASE/transformers"; mkdir -p "$TRANSFORMERS_CACHE"

# 通用 cache/config
export XDG_CACHE_HOME="$BASE/xdg_cache";        mkdir -p "$XDG_CACHE_HOME"
export XDG_CONFIG_HOME="$BASE/xdg_config";      mkdir -p "$XDG_CONFIG_HOME"
export TORCH_HOME="$BASE/torch_home";           mkdir -p "$TORCH_HOME"
export MPLCONFIGDIR="$BASE/mpl_config";         mkdir -p "$MPLCONFIGDIR"

# CUDA 编译缓存
export CUDA_CACHE_PATH="$BASE/cuda_cache";      mkdir -p "$CUDA_CACHE_PATH"
export CUDA_CACHE_MAXSIZE=2147483647

# OpenMP/BLAS 线程
NCPU="${SLURM_CPUS_PER_TASK:-8}"
export OMP_NUM_THREADS=$NCPU
export MKL_NUM_THREADS=$NCPU
export OPENBLAS_NUM_THREADS=$NCPU
export NUMEXPR_NUM_THREADS=$NCPU

# 避免 XLA 预分配（若被间接使用）
export XLA_PYTHON_CLIENT_PREALLOCATE=false

# ===== 根据 VARFILTER 选出对应的 manifest 行 =====
IDX="${SLURM_ARRAY_TASK_ID:-1}"

# manifest 列：task_id  protein  residue  site_in_domain  variant  task_tag  sequence ...
LINE=$(awk -v var="$VARFILTER" -v idx="$IDX" '
  BEGIN{FS="\t"; c=0}
  NR==1 {next}  # 跳过表头
  {
    if (var=="ALL" || $5==var) {
      c++
      if (c==idx) {
        print $0
        exit
      }
    }
  }
' "$MANIFEST" || true)

if [ -z "$LINE" ]; then
  echo "[FATAL] No matching row for VARFILTER=$VARFILTER at index $IDX in $MANIFEST" >&2
  exit 2
fi

read -r TASK_ID PROT RES POS VAR TAG SEQ _REST <<< "$LINE"

if [ -z "${PROT:-}" ] || [ -z "${TAG:-}" ]; then
  echo "[FATAL] Parsed manifest line is malformed: $LINE" >&2
  exit 3
fi

# ===== 输入/输出目录结构 =====
# 默认假设采样输出在：$INPUT_ROOT/<PROTEIN>/<task_tag>/
INDIR="$INPUT_ROOT/${PROT}/${TAG}"
OUTDIR="$OUTPUT_ROOT/${PROT}/${TAG}"

mkdir -p "$OUTDIR"

echo "=== $(date) | node=${SLURM_NODELIST:-?} job=${SLURM_JOB_ID:-?}/${SLURM_ARRAY_TASK_ID:-?} ==="
echo "MANIFEST=$MANIFEST"
echo "VARFILTER=$VARFILTER  IDX=$IDX  TASK_ID=$TASK_ID  TAG=$TAG  PROT=$PROT"
echo "INDIR=$INDIR"
echo "OUTDIR=$OUTDIR"

# ===== 检查输入采样文件是否存在 =====
XTC="$INDIR/samples.xtc"
PDB="$INDIR/topology.pdb"

if [ ! -s "$XTC" ] || [ ! -s "$PDB" ]; then
  echo "[FATAL] Missing input sampling files in $INDIR"
  echo "       Expect: samples.xtc and topology.pdb"
  ls -lh "$INDIR" || true
  exit 4
fi

# ===== 激活 venv（不使用 conda）=====
module purge >/dev/null 2>&1 || true
module load Python/3.11.5-GCCcore-13.2.0 virtualenv/20.24.6-GCCcore-13.2.0
source "$VENV/bin/activate"
python -c "import sys; print('[INFO] Python:', sys.executable, sys.version)"

# ===== GPU 信息（可选）=====
python - <<'PY' || true
try:
    import torch
    print(f"[INFO] Torch {torch.__version__}, CUDA: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"[INFO] GPU: {torch.cuda.get_device_name(0)}")
except Exception as e:
    print("[WARN] Torch check failed:", e)
PY

# ===== 运行支链重建 =====
start_time=$(date +%s)
echo "[RUN] sidechain rebuild: $XTC & $PDB -> $OUTDIR"

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# 在这里替换为你原来用的“支链重建”命令
# 例如（示意，仅占位！）：
#
# srun --cpu-bind=cores python -u -m bioemu.rebuild_sidechains \
#   --input_trajectory "$XTC" \
#   --input_topology  "$PDB" \
#   --output_dir      "$OUTDIR"
#
# 请用你自己现有的重建脚本/模块和参数替换下面这行：
srun --cpu-bind=cores python -u -m bioemu.rebuild_sidechains \
  --input_trajectory "$XTC" \
  --input_topology   "$PDB" \
  --output_dir       "$OUTDIR"
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

end_time=$(date +%s)
echo "[DONE] $(date) | rebuild took $((end_time-start_time))s"

# ===== 输出检查 & 清单（按你实际生成的文件名改）=====
# 这里假设你重建后生成 rebuilt.xtc / rebuilt.pdb 之类的文件
if ls "$OUTDIR"/* 1> /dev/null 2>&1; then
  echo "[OK] Rebuild outputs in $OUTDIR:"
  ls -lh "$OUTDIR"
else
  echo "[WARN] No output files found in $OUTDIR"
fi

(
  echo "== REBUILD MANIFEST ($(date)) =="
  printf "TAG=%s  PROT=%s  VAR=%s  VARFILTER=%s\n" "$TAG" "$PROT" "$VAR" "$VARFILTER"
  echo "INDIR=$INDIR"
  echo "OUTDIR=$OUTDIR"
  find "$OUTDIR" -maxdepth 2 -type f -printf "%TY-%Tm-%Td %TT  %9s  %p\n" | sort
) > "$OUTDIR/MANIFEST_rebuild.txt"

# ===== 清理工作目录 =====
rm -rf "$WORK" || true
