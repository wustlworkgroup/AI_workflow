#!/usr/bin/bash
#du -hsx .[^.]* * 2>/dev/null | sort -rh | head -10  
#########################################################################
#Part1
# Must include all part 1 for the bsub running

# Load configuration file
CONFIG_FILE="$1"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Error: Config file '$CONFIG_FILE' not found!"
    exit 1
fi


# Check required variables
required_vars=(csv_file synapse_parent_id token_file_path)
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Error: Required variable $var is not set."
    exit 1
  fi
done
# GATK_path is set in config.sh
echo $GATK_path


echo "Memory Allocation: $synapse_memory"
echo "Cores: $synapse_cores"
echo "Time Limit: $timeLimit"

####################################################################################
# Part2
# Need to add correct docker for running
docker="$docker_synapse"
echo "Docker is $docker" 
###############################################################################
# part 3
# Need correct input file and PY function to run
echo "csv_file is $csv_file"
#new_csv="${csv_file%.csv}_new.csv"
#echo "$new_csv"
echo "$csv_file"
echo "$token_file_path"


jobname="${Project}_synapse_upload_$(date +%Y%m%d_%H%M%S)"
output_file="$GATK_path/${jobname}_OUTPUT.txt"
# Submit the job to LSF and capture the job ID
job_id=$(bsub -cwd "$GATK_HOME" -q general -n "$synapse_cores" -M "$synapse_memory" -G compute-hirbea \
        -a "docker($docker)" -W "${timeLimit}:00" \
        -o "$output_file" \
        -J "$jobname" \
        -R "rusage[mem=$synapse_memory] span[hosts=1]" /bin/bash -c \
        "mkdir -p $GATK_HOME/.synapseCache && export SYNAPSE_CACHE_FOLDER=$GATK_HOME/.synapseCache && source /opt/conda/etc/profile.d/conda.sh && conda activate synapseclient && python3 ${PY_function_path}/synapse_uploading2.py --authToken ${token_file_path} --file_path ${csv_file} --parent_id ${synapse_parent_id}" | grep -o '<[0-9]*>' | sed 's/[<>]//g')
   
echo "Synapse upload job submitted with ID: $job_id"

# Save job id, output file name and synapse_parent_id to a file
echo "$job_id $jobname $output_file $synapse_parent_id" >> $GATK_path/${job_id}_INFO.txt
  






