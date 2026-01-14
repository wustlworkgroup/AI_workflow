# config.sh - Configuration for SRA Download Workflow
# This config file is for running SRA downloads on RIS cluster
# SETTING UP THE WORKING ENVIRONMENT

#################################################################
# Basic Working Environment
# Only need to set it up at the first time.
#################################################################
Data_type="SRA"
ris_path="/storage1/fs1/hirbea/Active"
export WORKING_DIR="$ris_path/AI_lab_V1"

# Project-specific settings (will be updated automatically when you run pipeline)
Project="" #"input by claude code after receiving the task"
bioproject_id="" #"input by claude code after receiving the task, e.g. PRJNA390610"

Project_folder="${WORKING_DIR}/Project"
Project_path="${Project_folder}/${Project}"

# SRA output directory (will be set when Project and bioproject_id are defined)

SRA_OUTPUT_DIR="${Project_path}/Rawdata/SRA_output_${bioproject_id}"

# Create project directories if Project is set
if [ -n "$Project" ]; then
  mkdir -p "$Project_path"
  if [ -n "$bioproject_id" ]; then
    mkdir -p "$SRA_OUTPUT_DIR"
  fi
fi

#################################################################
# LSF Job Settings for SRA Downloads (if using LSF)
#################################################################
# LSF resource defaults for SRA download jobs
MEMORY="${MEMORY:-12G}"                # LSF job memory limit (default 12G)
CORES="${CORES:-4}"                    # LSF job cores (default 4)
TIMELIMIT="${TIMELIMIT:-48}"           # LSF job time limit in hours (default 48)

# Storage allocation (used for Docker volumes if needed)
STORAGE_ALLOCATION="hirbea"

#################################################################
# Docker Configuration
#################################################################
# Docker image for SRA tools (contains pysradb, sra-tools, pigz)
docker_sra="aibiologist/sra-tools:v1"

#################################################################
# Storage and Volume Mounts for Docker (if using Docker)
#################################################################
# LSF Docker volumes - mount storage and scratch directories
# https://docs.ris.wustl.edu/doc/compute/recipes/ris-compute-storage-volumes.html
export LSF_DOCKER_VOLUMES="/scratch1/fs1/ris:/scratch1/fs1/ris \
/storage1/fs1/${STORAGE_ALLOCATION}/Active:/storage1/fs1/${STORAGE_ALLOCATION}/Active \
/storage2/fs1/${STORAGE_ALLOCATION}/Active:/storage2/fs1/${STORAGE_ALLOCATION}/Active"

#################################################################
# Environment Variables
#################################################################
# PATH settings
export PATH="/opt/conda/bin:$PATH"

# Python/R environment isolation (prevents conflicts with container packages)
export PYTHONNOUSERSITE=1
export R_PROFILE_USER=/.Rprofile
export R_ENVIRON_USER=/.Renviron

# Conda/Micromamba environment directories
# These directories will be used to cache conda/micromamba environments
CONDA_ENVS_BASE="/storage1/fs1/${STORAGE_ALLOCATION}/Active/conda"
export CONDA_ENVS_DIRS="${CONDA_ENVS_BASE}/envs/"
export CONDA_PKGS_DIRS="${CONDA_ENVS_BASE}/pkgs/"

# Create conda directories if they don't exist
mkdir -p "$CONDA_ENVS_DIRS" "$CONDA_PKGS_DIRS"

#################################################################
# SRA Tools Path Configuration
#################################################################
# Path to download_bioproject_sra.sh script
# The calling script will check for existence and try alternative paths
SRA_SCRIPT_PATH="${WORKING_DIR}/AI_workflow_SRA/PY_function/download_bioproject_sra.sh"