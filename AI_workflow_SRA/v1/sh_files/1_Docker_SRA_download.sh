#!/usr/bin/bash
#########################################################################
# 1_Docker_SRA_download.sh - Submit SRA download job to LSF cluster
# This script loads config.sh and submits SRA download job
# This script is used to submit the SRA download workflow to the LSF cluster
#########################################################################

# Load configuration file
CONFIG_FILE="$1"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Error: Config file '$CONFIG_FILE' not found!"
    echo "Usage: $0 <path_to_config.sh>"
    exit 1
fi

####################################################################################
# Part 1: Validate required variables
####################################################################################
required_vars=(bioproject_id SRA_OUTPUT_DIR Project_path SRA_SCRIPT_PATH WORKING_DIR MEMORY CORES TIMELIMIT)
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Error: Required variable $var is not set in config.sh"
    exit 1
  fi
done

# Validate SRA script exists
if [ ! -f "$SRA_SCRIPT_PATH" ]; then
    echo "Error: SRA download script not found: $SRA_SCRIPT_PATH"
    exit 1
fi

# Validate bioproject_id format (optional but helpful)
if [[ ! "$bioproject_id" =~ ^PRJ[A-Z]{2}[0-9]+$ ]]; then
    echo "⚠️  Warning: BioProject ID format may be incorrect: $bioproject_id"
    echo "Expected format: PRJNA######, PRJEB######, or PRJDB######"
fi

####################################################################################
# Part 2: Docker image (loaded from config.sh)
####################################################################################
# docker_sra is already loaded from config.sh (line 47), use it directly
echo "Using Docker image: $docker_sra"

####################################################################################
# Part 3: Set job name and output files
####################################################################################
job_name="${Project}_SRA_download_${bioproject_id}_$(date +%Y%m%d_%H%M%S)"
log_dir="${Project_path}/logs"
log_file="${log_dir}/${job_name}.log"
error_file="${log_dir}/${job_name}.err"

# Create log directory
mkdir -p "$log_dir"

####################################################################################
# Part 4: Set SRA download script path and validate
####################################################################################
# SRA_SCRIPT_PATH is already set from config, but validate it exists
if [ ! -f "$SRA_SCRIPT_PATH" ]; then
    echo "Error: SRA download script not found: $SRA_SCRIPT_PATH"
    exit 1
fi

# Validate SRA output directory can be created
mkdir -p "$SRA_OUTPUT_DIR"
if [ ! -d "$SRA_OUTPUT_DIR" ]; then
    echo "Error: Cannot create SRA output directory: $SRA_OUTPUT_DIR"
    exit 1
fi

####################################################################################
# Part 5: Submit job to LSF
####################################################################################
echo "=========================================="
echo "Submitting SRA Download Job"
echo "=========================================="
echo "Job Name: $job_name"
echo "BioProject ID: $bioproject_id"
echo "Output Directory: $SRA_OUTPUT_DIR"
echo "SRA Script: $SRA_SCRIPT_PATH"
echo "Docker Image: $docker_sra"
echo "Memory: $MEMORY"
echo "Cores: $CORES"
echo "Time Limit: ${TIMELIMIT} hours"
echo "Working Directory: $WORKING_DIR"
echo "Project Path: $Project_path"
echo "=========================================="

# Submit the job to LSF
# The -a "docker($docker_sra)" flag ensures the entire command runs inside the Docker container
# Pass bioproject_id and SRA_OUTPUT_DIR as arguments to download_bioproject_sra.sh
# Also pass CORES and MEMORY as arguments
# Note: The Docker image (aibiologist/sra-tools:v1) has micromamba with pysradb, sra-tools, and pigz
# THREADS and PARALLEL are calculated by download_bioproject_sra.sh from CORES argument
# Capture job ID from bsub output (bsub returns: "Job <job_id> is submitted to queue <queue>")
bsub_output=$(bsub -cwd "$Project_path" \
     -q general \
     -n "$CORES" \
     -M "$MEMORY" \
     -G compute-hirbea \
     -a "docker($docker_sra)" \
     -W "${TIMELIMIT}:00" \
     -o "$log_file" \
     -e "$error_file" \
     -J "$job_name" \
     -R "rusage[mem=$MEMORY] span[hosts=1]" \
     /bin/bash -c "/bin/bash \"${SRA_SCRIPT_PATH}\" \"${bioproject_id}\" \"${SRA_OUTPUT_DIR}\" \"${CORES}\" \"${MEMORY}\"" 2>&1)

# Extract job ID from bsub output
# bsub returns format: "Job <job_id> is submitted to queue <queue>"
job_id=$(echo "$bsub_output" | grep -oP 'Job <\K[0-9]+(?=>)' || echo "")

# Display bsub output
echo "$bsub_output"

# Save job submission details to result file
result_file="${log_dir}/${job_name}.result"
echo "==========================================" > "$result_file"
echo "SRA Download Job Submitted" >> "$result_file"
echo "==========================================" >> "$result_file"
echo "Job ID: $job_id" >> "$result_file"
echo "Job Name: $job_name" >> "$result_file"
echo "BioProject ID: $bioproject_id" >> "$result_file"
echo "Output Directory: $SRA_OUTPUT_DIR" >> "$result_file"
echo "Memory: $MEMORY | Cores: $CORES" >> "$result_file"
echo "Log file: $log_file" >> "$result_file"
echo "Error file: $error_file" >> "$result_file"
echo "==========================================" >> "$result_file"

if [ -n "$job_id" ]; then
    echo ""
    echo "Job submitted successfully!"
    echo "Job ID: $job_id"
    echo "Job Name: $job_name"
    echo "Log file: $log_file"
    echo "Error file: $error_file"
    echo "Result file: $result_file"
    echo ""
    echo "Check job status with:"
    echo "  bjobs $job_id"
    echo "  bjobs -J $job_name"
    echo ""
    echo "Monitor job output with:"
    echo "  tail -f $log_file"
else
    echo ""
    echo "Error: Job submission failed or job ID not captured!"
    echo "Please check the error messages above"
    exit 1
fi
