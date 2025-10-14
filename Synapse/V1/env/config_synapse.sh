# config.sh - Configuration for ai-workflow Pipeline
# this config files is the engine
# SETTING UP THE WORKING ENVIRONMENT

# only need to set it up at the first time.
STORAGE_ALLOCATION="hirbea"
Working_engine="/storage1/fs1/${STORAGE_ALLOCATION}/Active/AI_workflow"
PY_function_path="$Working_engine/PY_function"
sh_files_path="$Working_engine/sh_files"
env_path="$Working_engine/env"

# Project-specific variables (updated by All_in_one_AIworkflow.sh)
Project=""
csv_file=""
Project_path=""
synapse_parent_id=""
token_file_path="$env_path/synapse_full_token.txt"
#############################################################
GATK_HOME="$Working_engine/tmp"
GATK_path="$Working_engine/gatk"
mkdir -p "$GATK_path"
mkdir -p "$GATK_HOME"
##########################################################################

# LSF Job Settings - General defaults
timeLimit="240"   # Time limit in hours for LSF jobs
memory="40G"
cores=8

# Pipeline-specific settings
# Fastq to BAM settings (higher memory for alignment)
synapse_memory="20G"
synapse_cores=4
    
# if there is gpu
PATH="/opt/conda/bin:/usr/local/cuda/bin:$PATH"
#############################################################

#set docker 
docker_synapse="aibiologist/synapse:v1" # 


# Storage and Reference Paths

#export LSF_DOCKER_VOLUMES="/storage1/fs1/${STORAGE_ALLOCATION}/Active:/storage1/fs1/${STORAGE_ALLOCATION}/Active /opt/thpc:/opt/thpc /scratch1/fs1/ris:/scratch1/fs1/ris"
export LSF_DOCKER_VOLUMES="/opt/thpc:/opt/thpc /scratch1/fs1/ris:/scratch1/fs1/ris \
/storage1/fs1/${STORAGE_ALLOCATION}/Active:/storage1/fs1/${STORAGE_ALLOCATION}/Active \
/storage2/fs1/${STORAGE_ALLOCATION}/Active:/storage2/fs1/${STORAGE_ALLOCATION}/Active"


#https://docs.ris.wustl.edu/doc/compute/recipes/ris-compute-storage-volumes.html
# LSF Settings
export GATK_HOME
export PATH=$GATK_HOME:$PATH
export PATH="/opt/conda/bin:$PATH"

export CONDA_ENVS_DIRS="/storage1/fs1/${STORAGE_ALLOCATION}/Active/conda/envs/"
export CONDA_PKGS_DIRS="/storage1/fs1/${STORAGE_ALLOCATION}/Active/conda/pkgs/"

