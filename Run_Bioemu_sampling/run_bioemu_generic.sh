#!/usr/bin/env bash
#SBATCH -A naiss2025-5-451
#SBATCH -p alvis
#SBATCH -J bioemu-generic
#SBATCH --gpus-per-node=A100:1
#SBATCH -t 5-00:00:00
#SBATCH -o /mimer/NOBACKUP/groups/naiss2025-5-451/Bioemu/logs/sampling_%x_%A_%a.out
#SBATCH -e /mimer/NOBACKUP/groups/naiss2025-5-451/Bioemu/logs/sampling_%x_%A_%a.err

set -euo pipefail

# ===== 参数检查 =====
# 1: manifest 路径
# 2: 输出根目录（比如 /mimer/.../outputs/multisite）
# 3: variant 过滤标签（E / Neutral / WT / ALL），ALL 表示不过滤
if [ $# -lt 2 ]; then
  echo "Usage: $0 MANIFEST OUTROOT [VARIANT_TAG|ALL]" >&2
  exit 1
fi

MANIFEST="$1"
OUTROOT="$2"
VAR_FILTER="${3:-ALL}"   # 默认 ALL

# ===== 固定路径（环境 & cache 之类）=====
BASE=/mimer/NOBACKUP/groups/naiss2025-5-451/Bioemu
VENV="$BASE/venvs/bioemu-md"
LOGROOT="$BASE/logs"
mkdir -p "$LOGROOT" "$BASE/caches/embeds" "$BASE/caches/so3" "$BASE/work"

# ===== 每个任务自己的 work 目录 =====
WID="${SLURM_JOB_ID:-manual}.${SLURM_ARRAY_TASK_ID:-0}"
WORK="$BASE/work/$WID"
mkdir -p "$WORK"

# ===== 严格约束所有写入路径到 BASE =====
export HOME="$BASE"
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

# ===== 读取 manifest（按 VAR_FILTER 过滤）=====
IDX="${SLURM_ARRAY_TASK_ID:-1}"

# manifest 列：task_id  protein  residue  site_in_domain  variant  task_tag  sequence
# 按第 5 列（variant）过滤，只统计匹配 VAR_FILTER 的行，
# 第 IDX 个匹配行用于当前任务。
read -r TASK_ID PROT RES POS VAR TAG SEQ _REST < <(
  awk -v n="$IDX" -v var="$VAR_FILTER" '
    BEGIN{FS="\t"}
    NR==1{next}   # 跳过表头
    {
      if (var=="ALL" || $5==var) {
        cnt++
        if (cnt==n) {
          print $1, $2, $3, $4, $5, $6, $7
          exit
        }
      }
    }' "$MANIFEST"
)

# 如果没有取到行：说明 IDX 超出该 variant 的行数，直接退出即可
if [ -z "${TASK_ID:-}" ]; then
  echo "[INFO] No matching row for VAR_FILTER=$VAR_FILTER at index $IDX; exiting."
  exit 0
fi

if [ -z "${SEQ:-}" ] || [ -z "${PROT:-$PROT}" ] || [ -z "${VAR:-$VAR}" ]; then
  echo "[FATAL] Manifest line (filtered index $IDX) malformed in: $MANIFEST" >&2
  exit 2
fi

# ===== 输出目录：OUTROOT/<Protein>/<task_tag>/ =====
OUTDIR="$OUTROOT/${PROT}/${TAG}"
mkdir -p "$OUTDIR"

echo "=== $(date) | node=${SLURM_NODELIST:-?} job=${SLURM_JOB_ID:-?}/${SLURM_ARRAY_TASK_ID:-?} ==="
echo "MANIFEST=$MANIFEST"
echo "VAR_FILTER=$VAR_FILTER  IDX=$IDX  TASK_ID=$TASK_ID  TAG=$TAG"
echo "OUTDIR=$OUTDIR"

# ===== 激活 venv =====
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

# ===== 运行采样 =====
NUM_SAMPLES="${NUM_SAMPLES:-3000}"
SEED="${SEED:-42}"

start_time=$(date +%s)
echo "[RUN] bioemu.sample -> $OUTDIR  (num_samples=$NUM_SAMPLES, seed=$SEED)"

srun --cpu-bind=cores python -u -m bioemu.sample \
  --sequence "$SEQ" \
  --num_samples "$NUM_SAMPLES" \
  --output_dir "$OUTDIR" \
  --cache_embeds_dir "$BASE/caches/embeds" \
  --cache_so3_dir    "$BASE/caches/so3"

end_time=$(date +%s)
echo "[DONE] $(date) | took $((end_time-start_time))s"

# ===== 输出检查 & 清单 =====
if [ -s "$OUTDIR/samples.xtc" ] && [ -s "$OUTDIR/topology.pdb" ]; then
  echo "[OK] Outputs:"
  ls -lh "$OUTDIR/samples.xtc" "$OUTDIR/topology.pdb"
else
  echo "[WARN] Missing samples.xtc/topology.pdb in $OUTDIR"
  ls -lh "$OUTDIR" || true
fi

( echo "== MANIFEST ($(date)) ==";
  printf "TAG=%s  PROT=%s  RES=%s  POS=%s  VAR=%s  NUM_SAMPLES=%s  SEED=%s\n" \
    "$TAG" "$PROT" "$RES" "$POS" "$VAR" "$NUM_SAMPLES" "$SEED";
  find "$OUTDIR" -maxdepth 2 -type f -printf "%TY-%Tm-%Td %TT  %9s  %p\n" | sort
) > "$OUTDIR/MANIFEST_sampling.txt"

# ===== 清理工作目录 =====
rm -rf "$WORK" || true
