
#!/bin/bash
# this script is for running the WGS pipeline on RIS cluster

#cd /media/yang/Hirbe_drive_8/WGS_WEX/SR007741/sh_files
#dir

# FOR AI workflow, project path should be the same as Working_engine/Project
# AI agents willl copy this script to the project folder and edit it.
# ai input csv file based on the task, if it is the synapse uploading task, the csv file should contain synapse ID

# environment variable (engine,cannot be changed after setting up the project)
WORKING_DIR="/storage1/fs1/hirbea/Active/AI_workflow"  # Top level directory

Project="10172025_BAM_transfer" #"input by claude code after receiving the task"
csv_file="synapse_annotations.csv" #"input by claude code after receiving the task"
synapse_parent_id="syn70072706" #"input by claude code after receiving the task"
if [ -z "$Project" ]; then
  echo "Project is not set"
  exit 1
fi

 
####################################################################################

# Get user input
option="$1"

if [[ -z "$option" ]]; then
  echo "Please provide an option to run the pipeline:"
  echo "1 = synapse uploading files"
  exit 1
fi

if [ "$option" == "1" ]; then
  echo "uploading files to synapse is starting"
  CONFIG_FILE="${WORKING_DIR}/env/config_synapse.sh"
  Project_folder="/storage1/fs1/hirbea/Active/AI_workflow/Project" #"/storage1/fs1/hirbea/Active/WGS_WEX/Project"
  Project_path=${Project_folder}/${Project}
  # find csv file for synapse uploading
  if [ -z "$csv_file" ]; then
    csv_file=$(find $Project_folder/$Project/Sample_manifest/ -name "synapse_annotations.csv")
  else
    csv_file=$(find $Project_folder/$Project/Sample_manifest/ -name "$csv_file")
  fi 
  
  if [ -z "$csv_file" ]; then
    echo "csv file for synapse uploading is not found"
    exit 1
  fi

  # Process CSV file for carriage returns
  new_csv="${csv_file%.csv}_new.csv"
  if grep -q $'\r$' "$csv_file"; then
      tr -d '\r' < "$csv_file" > "$new_csv"
      echo "Converted file saved as $new_csv"
  else
    new_csv="$csv_file"
  fi

  #copy CONFIG_FILE to Project_path
  cp $CONFIG_FILE $Project_path/config_synapse.sh
  
  # Update config file with project-specific values
  sed -i "s|Project=.*|Project=${Project}|" "$Project_path/config_synapse.sh"
  sed -i "s|csv_file=.*|csv_file=${new_csv}|" "$Project_path/config_synapse.sh"
  sed -i "s|Project_path=.*|Project_path=${Project_path}|" "$Project_path/config_synapse.sh"
  sed -i "s|synapse_parent_id=.*|synapse_parent_id=${synapse_parent_id}|" "$Project_path/config_synapse.sh"
 
  
  # Source the config file to get sh_files_path
  source "$Project_path/config_synapse.sh"
  
  if [ -z "$sh_files_path" ]; then
    echo "Error: sh_files_path is not set. Please check your config.sh."
    exit 1
  fi
  
  # Set CONFIG_path for the script call
  CONFIG_path="$Project_path/config_synapse.sh"
  
  /bin/bash $sh_files_path/1_Docker_synapse_uploading2.sh $CONFIG_path


fi

