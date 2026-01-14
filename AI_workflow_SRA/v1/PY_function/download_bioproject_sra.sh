#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Download SRA data for an NCBI BioProject using:
#   1) pysradb -> SRR list (+metadata)
#   2) sra-tools -> prefetch + fasterq-dump
#
# Usage:
#   ./download_bioproject_sra.sh PRJNA390610 /abs/path/outdir [CORES] [MEMORY]
#
# Arguments:
#   BIOPROJECT_ID            # Required: BioProject ID (e.g. PRJNA390610)
#   SAVE_FOLDER              # Required: Output directory for downloads
#   CORES                    # Optional: Number of cores (default: use THREADS env var or 8)
#   MEMORY                   # Optional: Memory allocation (e.g. 120G, for logging/info)
#
# Optional env vars:
#   THREADS=8                 # fasterq-dump threads (default 8, or CORES if provided)
#   PARALLEL=2                # number of runs processed concurrently (default 2, or CORES/4 if provided)
#   DO_PREFETCH=1             # 1 to run prefetch, 0 to skip (default 1)
#   KEEP_SRA=1                # 1 keep .sra files, 0 delete after FASTQ (default 1)
#   PIGZ=1                    # 1 gzip fastq with pigz if available (default 1)
# ------------------------------------------------------------

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <BIOPROJECT_ID e.g. PRJNA390610> <SAVE_FOLDER> [CORES] [MEMORY]"
  exit 1
fi

# Activate micromamba env (only if micromamba exists)
eval "$(micromamba shell hook --shell bash)"
micromamba activate base


# Check required commands (after activation)
for cmd in prefetch fasterq-dump pysradb awk sort xargs; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $cmd"
    echo "        Make sure your micromamba env contains it, or install it system-wide."
    exit 2
  fi
done

BIOPROJECT="$1"
OUTDIR="$2"
CORES_ARG="${3:-}"
MEMORY_ARG="${4:-}"

# Use CORES argument if provided, otherwise use THREADS env var or default
if [[ -n "$CORES_ARG" ]]; then
  # Use cores for THREADS, and set PARALLEL to cores/4 (but at least 1)
  THREADS="${CORES_ARG}"
  PARALLEL=$((CORES_ARG / 4))
  if [[ $PARALLEL -lt 1 ]]; then
    PARALLEL=1
  fi
  echo "[INFO] Using provided CORES=${CORES_ARG}: THREADS=${THREADS}, PARALLEL=${PARALLEL}"
else
  # Fall back to environment variables or defaults
  THREADS="${THREADS:-8}"
  PARALLEL="${PARALLEL:-2}"
fi

# Log memory if provided
if [[ -n "$MEMORY_ARG" ]]; then
  echo "[INFO] Memory allocation: ${MEMORY_ARG}"
fi

DO_PREFETCH="${DO_PREFETCH:-1}"
KEEP_SRA="${KEEP_SRA:-1}"
PIGZ="${PIGZ:-1}"

mkdir -p "${OUTDIR}"/{meta,sra,fastq,tmp,logs}
cd "${OUTDIR}"

META_TSV="meta/${BIOPROJECT}.metadata.tsv"
SRR_LIST="meta/${BIOPROJECT}.srr.txt"

echo "[INFO] BioProject: ${BIOPROJECT}"
echo "[INFO] Output dir: $(pwd)"
if [[ -n "$MEMORY_ARG" ]]; then
  echo "[INFO] THREADS=${THREADS} PARALLEL=${PARALLEL} MEMORY=${MEMORY_ARG} DO_PREFETCH=${DO_PREFETCH} KEEP_SRA=${KEEP_SRA}"
else
  echo "[INFO] THREADS=${THREADS} PARALLEL=${PARALLEL} DO_PREFETCH=${DO_PREFETCH} KEEP_SRA=${KEEP_SRA}"
fi

# 1) Get metadata from pysradb
echo "[INFO] Fetching metadata via pysradb..."
pysradb metadata "${BIOPROJECT}" --detailed > "${META_TSV}"

# 2) Extract SRR list (first column is typically "run_accession" or "run")
#    We keep only tokens that look like SRR*
echo "[INFO] Extracting SRR accessions..."
awk 'NR==1 {next} {print $1}' "${META_TSV}" \
  | awk '$0 ~ /^SRR[0-9]+$/ {print $0}' \
  | sort -u > "${SRR_LIST}"

NUM_RUNS="$(wc -l < "${SRR_LIST}" | tr -d ' ')"
if [[ "${NUM_RUNS}" -eq 0 ]]; then
  echo "[ERROR] No SRR runs found for ${BIOPROJECT}. Check metadata file: ${META_TSV}"
  exit 3
fi
echo "[INFO] Found ${NUM_RUNS} SRR runs"

# Helper: process one SRR
process_one() {
  local srr="$1"
  local logp="logs/${srr}.log"

  {
    echo "[INFO] ===== ${srr} ====="
    echo "[INFO] date: $(date -Is)"

    # Skip if FASTQ already exists (resume-friendly)
    if ls "fastq/${srr}"*_1.fastq* "fastq/${srr}"*.fastq* >/dev/null 2>&1; then
      echo "[INFO] FASTQ already exists for ${srr}, skipping."
      return 0
    fi

    # Prefetch (optional)
    if [[ "${DO_PREFETCH}" -eq 1 ]]; then
      echo "[INFO] prefetch ${srr} -> sra/"
      prefetch -O "sra" "${srr}"
      local sra_path="sra/${srr}.sra"
      if [[ ! -f "${sra_path}" ]]; then
        # Sometimes prefetch creates nested directories; find it
       sra_path="$(find sra -maxdepth 4 -name "${srr}.sra" | head -n 1 || true)"


      fi
      if [[ -z "${sra_path}" || ! -f "${sra_path}" ]]; then
        echo "[ERROR] Could not locate downloaded .sra for ${srr}"
        return 4
      fi
      echo "[INFO] fasterq-dump from file: ${sra_path}"
      fasterq-dump --threads "${THREADS}" --split-files --temp "tmp" -O "fastq" "${sra_path}"
    else
      echo "[INFO] fasterq-dump directly from accession: ${srr}"
      fasterq-dump --threads "${THREADS}" --split-files --temp "tmp" -O "fastq" "${srr}"
    fi

    # Optional compression
    if [[ "${PIGZ}" -eq 1 ]] && command -v pigz >/dev/null 2>&1; then
      echo "[INFO] pigz compress fastq/${srr}*.fastq"
      pigz -f "fastq/${srr}"*.fastq || true
    fi

    # Optional cleanup of .sra
    if [[ "${KEEP_SRA}" -eq 0 ]]; then
      echo "[INFO] Removing cached .sra for ${srr}"
      find sra -name "${srr}.sra" -delete || true
    fi

    echo "[INFO] DONE ${srr}"
  } > "${logp}" 2>&1
}

export -f process_one
export THREADS PARALLEL DO_PREFETCH KEEP_SRA PIGZ

# 3) Run in parallel (PARALLEL controls how many SRRs at once)
echo "[INFO] Downloading & converting runs..."
cat "${SRR_LIST}" \
  | xargs -n 1 -P "${PARALLEL}" bash -c 'process_one "$1"' _



echo "[SUCCESS] All runs processed."
echo "[INFO] Metadata: ${META_TSV}"
echo "[INFO] SRR list:  ${SRR_LIST}"
echo "[INFO] FASTQ dir: $(pwd)/fastq"
