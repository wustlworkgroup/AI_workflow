#!/bin/bash
#########################################################################
# All_in_one_AIworkflow_SRA.sh - Run SRA download workflow on RIS cluster
# This script provides a menu-driven interface for SRA data downloads
# Usage: ./All_in_one_AIworkflow_SRA.sh [Project] [Option] [bioproject_id] [memory] [cores] [timeLimit]
#   Or run without arguments for interactive menu
#########################################################################

# Configuration
WORKING_DIR="/storage1/fs1/hirbea/Active/AI_lab_V1"
BASE_CONFIG_FILE="${WORKING_DIR}/AI_workflow_SRA/env/config.sh"
Project_folder="${WORKING_DIR}/Project"

sh_files_path="${WORKING_DIR}/AI_workflow_SRA/sh_files"
DOCKER_SCRIPT="${sh_files_path}/1_Docker_SRA_download.sh"

# Get command line arguments (optional - for direct execution)
# Check environment variables first (for Docker execution), then use arguments
Project_arg="${Project:-$1}"
Option_arg="${2:-}"
bioproject_id_arg="${bioproject_id:-$3}"
memory_arg="$4"
cores_arg="$5"
timeLimit_arg="$6"

# If first argument is a number (1 or 2), treat it as option (for backward compatibility)
if [[ "$1" =~ ^[1-2]$ ]] && [[ -z "$Option_arg" ]]; then
    Option_arg="$1"
    Project_arg="${Project:-}"
    bioproject_id_arg="${bioproject_id:-}"
fi

# Function to display menu
show_menu() {
    echo "=========================================="
    echo "  SRA Download Workflow Menu"
    echo "=========================================="
    echo "1) Option 1: SRA Project download (using Docker/LSF)"
    echo "2) Option 2: SRA files download (ongoing - direct execution)"
    echo "3) Exit"
    echo "=========================================="
}


# Function to setup project configuration
setup_config() {
    local project="$1"
    local bioproject_id="$2"
    local project_path="${Project_folder}/${project}"
    local project_config="${project_path}/config_sra.sh"
    
    # Output informational messages to stderr so they don't interfere with return value
    echo "Setting up project configuration..." >&2
    
    # Create project directory
    mkdir -p "$project_path"
    
    # Copy config.sh to project directory if it doesn't exist
    if [ ! -f "$project_config" ]; then
        cp "$BASE_CONFIG_FILE" "$project_config"
        echo "✓ Config file copied to $project_config" >&2
    else
        echo "✓ Config file already exists at $project_config" >&2
    fi
    
    # Update config.sh with project-specific settings
    # Note: SRA_OUTPUT_DIR is automatically calculated from Project_path and bioproject_id in config.sh
    # (line 21: SRA_OUTPUT_DIR="${Project_path}/Rawdata/SRA_output_${bioproject_id}")
    # so we don't need to set it explicitly here - it will be correct when config is sourced
    sed -i "s|^Project=.*|Project=\"${project}\"|" "$project_config"
    if [ -n "$bioproject_id" ]; then
        sed -i "s|^bioproject_id=.*|bioproject_id=\"${bioproject_id}\"|" "$project_config"
    fi
    
      
    # Output only the config file path to stdout (for capture)
    echo "$project_config"
}

# Function to save config file backup after each run
save_config_backup() {
    local config_file="$1"
    local option_name="$2"
    local project="$3"
    
    if [ ! -f "$config_file" ]; then
        echo "⚠️  Warning: Config file not found, cannot create backup"
        return 1
    fi
    
    # Get project path from config file directory
    local project_path=$(dirname "$config_file")
    local backup_dir="${project_path}/config_backups"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"
    
    # Create timestamped backup filename
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/config_option${option_name}_${timestamp}.sh"
    
    # Copy config file to backup location
    cp "$config_file" "$backup_file"
    
    if [ $? -eq 0 ]; then
        echo "✓ Config backup saved: $(basename "$backup_file")"
        return 0
    else
        echo "✗ Failed to save config backup"
        return 1
    fi
}

# Function to validate inputs
validate_inputs() {
    local project="$1"
    local bioproject_id="$2"
    local option="$3"
    local config_file="$4"
    
    if [[ -z "$project" ]]; then
        echo "✗ Error: Project name is required"
        echo "Usage: $0 [Project] [Option] [bioproject_id] [memory] [cores] [timeLimit]"
        exit 1
    fi
    
    if [[ -z "$bioproject_id" ]]; then
        echo "✗ Error: bioproject_id is required (e.g., PRJNA390610)"
        exit 1
    fi
    
    # Validate bioproject_id format (should start with PRJ)
    if [[ ! "$bioproject_id" =~ ^PRJ[A-Z]{2}[0-9]+$ ]]; then
        echo "⚠️  Warning: bioproject_id format may be incorrect: $bioproject_id"
        echo "Expected format: PRJNA######, PRJEB######, or PRJDB######"
        read -p "Continue anyway? (y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    if [ ! -f "$config_file" ]; then
        echo "✗ Error: Config file not found: $config_file"
        exit 1
    fi
    
    # Validate option
    if [[ "$option" != "1" ]] && [[ "$option" != "2" ]]; then
        echo "✗ Error: Invalid option: $option (must be 1 or 2)"
        exit 1
    fi
    
    # Validate scripts based on option
    if [[ "$option" == "1" ]]; then
        if [ ! -f "$DOCKER_SCRIPT" ]; then
            echo "✗ Error: Docker script not found: $DOCKER_SCRIPT"
            exit 1
        fi
    fi
    
    echo "✓ Input validation passed"
}

# Function to get resource parameters interactively
get_resources_interactive() {
    # If arguments were provided, use them
    if [[ -n "$memory_arg" ]] || [[ -n "$cores_arg" ]] || [[ -n "$timeLimit_arg" ]]; then
        return 0
    fi
    
    # Otherwise, prompt for values (only for option 1)
    if [[ "$Option_arg" == "1" ]]; then
        # Load defaults from base config file
        if [ -f "$BASE_CONFIG_FILE" ]; then
            source "$BASE_CONFIG_FILE"
        fi
        
        # Get default values (with fallbacks if config not loaded)
        local default_memory="${MEMORY:-12G}"
        local default_cores="${CORES:-4}"
        local default_time="${TIMELIMIT:-48}"
        
        echo ""
        echo "Resource Configuration (for Docker/LSF job):"
        echo "------------------------------------------"
        
        # Get memory
        read -p "Memory limit [${default_memory}] (or press Enter for default): " mem_input
        if [[ -n "$mem_input" ]]; then
            memory_arg="$mem_input"
        else
            # Use default from config file
            memory_arg="$default_memory"
        fi
        
        # Get cores
        read -p "Number of cores [${default_cores}] (or press Enter for default): " core_input
        if [[ -n "$core_input" ]]; then
            cores_arg="$core_input"
        else
            # Use default from config file
            cores_arg="$default_cores"
        fi
        
        # Get time limit
        read -p "Time limit in hours [${default_time}] (or press Enter for default): " time_input
        if [[ -n "$time_input" ]]; then
            timeLimit_arg="$time_input"
        else
            # Use default from config file
            timeLimit_arg="$default_time"
        fi
        
        echo "------------------------------------------"
    fi
}

# Function to set resource parameters
set_resources() {
    local config_file="$1"
    local mem="$2"
    local core="$3"
    local time="$4"
    
    # Set memory
    if [[ -n "$mem" ]]; then
        # Capitalize and ensure 'G' suffix
        mem=$(echo "$mem" | tr '[:lower:]' '[:upper:]')
        if [[ "$mem" != *"G"* ]]; then
            mem="${mem}G"
        fi
        sed -i "s|^MEMORY=.*|MEMORY=\"${mem}\"|" "$config_file"
        echo "✓ Memory set to $mem"
    fi
    
    # Set cores
    if [[ -n "$core" ]]; then
        sed -i "s|^CORES=.*|CORES=${core}|" "$config_file"
        echo "✓ Cores set to $core"
    fi
    
    # Set time limit
    if [[ -n "$time" ]]; then
        sed -i "s|^TIMELIMIT=.*|TIMELIMIT=${time}|" "$config_file"
        echo "✓ Time limit set to ${time} hours"
    fi
}

# Function to display workflow information
show_workflow_info() {
    local config_file="$1"
    local option="$2"
    
    source "$config_file"
    
    echo "=========================================="
    if [[ "$option" == "1" ]]; then
        echo "  SRA Project Download (Docker/LSF)"
    else
        echo "  SRA Files Download (Direct Execution)"
    fi
    echo "=========================================="
    echo "Project:            $Project"
    echo "BioProject ID:      $bioproject_id"
    echo "Project Path:       $Project_path"
    echo "SRA Output Dir:     $SRA_OUTPUT_DIR"
    if [[ "$option" == "1" ]]; then
        echo "Memory:              ${MEMORY:-120G}"
        echo "Cores:               ${CORES:-16}"
        echo "Time Limit:          ${TIMELIMIT:-48} hours"
    fi
    echo "=========================================="
}

# Function to run Option 1: SRA Project download (Docker/LSF)
run_option1_docker() {
    local config_file="$1"
    local project="$2"
    local bioproject_id="$3"
    
    echo "=========================================="
    echo "  Option 1: SRA Project Download (Docker/LSF)"
    echo "=========================================="
    
    # Validate Docker script exists
    if [ ! -f "$DOCKER_SCRIPT" ]; then
        echo "✗ Error: Docker script not found: $DOCKER_SCRIPT"
        return 1
    fi
    
    if [ ! -x "$DOCKER_SCRIPT" ]; then
        echo "⚠️  Warning: Docker script is not executable, attempting to run anyway..."
    fi
    
    echo "Docker script: $DOCKER_SCRIPT"
    echo "Config file: $config_file"
    echo "Submitting SRA download job to LSF..."
    echo ""
    
    /bin/bash "$DOCKER_SCRIPT" "$config_file"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo ""
        echo "=========================================="
        echo "✓ Option 1: Job submitted successfully!"
        echo "=========================================="
        echo "Check job status with:"
        echo "  bjobs -J ${project}_SRA_download_${bioproject_id}_*"
        echo "=========================================="
        return 0
    else
        echo ""
        echo "=========================================="
        echo "✗ Option 1: Job submission failed!"
        echo "=========================================="
        return 1
    fi
}

# Function to run Option 2: SRA files download (direct execution)
run_option2_direct() {
    local config_file="$1"
    local project="$2"
    local bioproject_id="$3"
    
    echo "=========================================="
    echo "  Option 2: SRA Files Download (Direct Execution)"
    echo "=========================================="
    
    source "$config_file"
    
    if [ ! -f "$SRA_SCRIPT_PATH" ]; then
        echo "✗ Error: SRA download script not found: $SRA_SCRIPT_PATH"
        return 1
    fi
    
    echo "Running SRA download directly..."
    /bin/bash "$SRA_SCRIPT_PATH" "$bioproject_id" "$SRA_OUTPUT_DIR"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo ""
        echo "=========================================="
        echo "✓ Option 2: Download completed successfully!"
        echo "=========================================="
        echo "Output directory: $SRA_OUTPUT_DIR"
        echo "=========================================="
        return 0
    else
        echo ""
        echo "=========================================="
        echo "✗ Option 2: Download failed!"
        echo "=========================================="
        return 1
    fi
}

# Function to get project name interactively
get_project_interactive() {
    local project_var="$1"
    
    # Get list of available projects
    local project_array=()
    if [ ! -d "$Project_folder" ]; then
        echo "⚠️  Warning: Could not read project directory"
        echo "Will create new project directory if needed"
        return 0
    fi
    
    # Read projects into array, sorted
    while IFS= read -r line; do
        project_array+=("$line")
    done < <(find "$Project_folder" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
    
    if [ ${#project_array[@]} -eq 0 ]; then
        echo "⚠️  No projects found in ${Project_folder}"
        echo "Will create new project directory if needed"
        return 0
    fi
    
    # Display available projects
    echo ""
    echo "Available Projects:"
    echo "----------------"
    for i in "${!project_array[@]}"; do
        printf "%2d) %s\n" $((i+1)) "${project_array[$i]}"
    done
    echo "----------------"
    echo ""
    
    # Get user selection
    while true; do
        read -p "Select project by number [1-${#project_array[@]}] or enter project name: " selection
        
        # Check if input is empty
        if [[ -z "$selection" ]]; then
            echo "✗ Error: Selection cannot be empty"
            continue
        fi
        
        # Check if input is a number
        if [[ "$selection" =~ ^[0-9]+$ ]]; then
            local idx=$((selection - 1))
            if [ $idx -ge 0 ] && [ $idx -lt ${#project_array[@]} ]; then
                eval "$project_var=\"${project_array[$idx]}\""
                echo "✓ Selected project: ${project_array[$idx]}"
                return 0
            else
                echo "✗ Error: Invalid number. Please select between 1 and ${#project_array[@]}"
                continue
            fi
        else
            # Input is a project name
            eval "$project_var=\"$selection\""
            echo "✓ Using project name: $selection"
            return 0
        fi
    done
}

# Function to get bioproject_id interactively
get_bioproject_id_interactive() {
    local bioproject_id_var="$1"
    
    while true; do
        read -p "Enter BioProject ID (e.g., PRJNA390610): " bio_id
        
        if [[ -z "$bio_id" ]]; then
            echo "✗ Error: BioProject ID cannot be empty"
            continue
        fi
        
        # Validate format
        if [[ ! "$bio_id" =~ ^PRJ[A-Z]{2}[0-9]+$ ]]; then
            echo "⚠️  Warning: BioProject ID format may be incorrect: $bio_id"
            echo "Expected format: PRJNA######, PRJEB######, or PRJDB######"
            read -p "Continue anyway? (y/n): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        
        eval "$bioproject_id_var=\"$bio_id\""
        echo "✓ BioProject ID: $bio_id"
        return 0
    done
}

# Function to execute a specific option
execute_option() {
    local option="$1"
    local project="$2"
    local bioproject_id="$3"
    
    # Get project if not provided
    if [[ -z "$project" ]]; then
        if ! get_project_interactive "project"; then
            return 1
        fi
    fi
    
    # Get bioproject_id if not provided
    if [[ -z "$bioproject_id" ]]; then
        if ! get_bioproject_id_interactive "bioproject_id"; then
            return 1
        fi
    fi
    
    # Get resource parameters interactively if not provided as arguments (for option 1)
    if [[ "$option" == "1" ]]; then
        get_resources_interactive
    fi
    
    # Setup configuration
    PROJECT_CONFIG=$(setup_config "$project" "$bioproject_id")
    
    # Validate inputs
    validate_inputs "$project" "$bioproject_id" "$option" "$PROJECT_CONFIG"
    
    # Set resource parameters (for option 1)
    if [[ "$option" == "1" ]]; then
        set_resources "$PROJECT_CONFIG" "$memory_arg" "$cores_arg" "$timeLimit_arg"
    fi
    
    # Source config to get variables
    source "$PROJECT_CONFIG"
    
    # Execute the selected option
    local option_result=0
    case "$option" in
        1)
            show_workflow_info "$PROJECT_CONFIG" "1"
            run_option1_docker "$PROJECT_CONFIG" "$project" "$bioproject_id"
            option_result=$?
            ;;
        2)
            show_workflow_info "$PROJECT_CONFIG" "2"
            run_option2_direct "$PROJECT_CONFIG" "$project" "$bioproject_id"
            option_result=$?
            ;;
        *)
            echo "✗ Invalid option: $option"
            return 1
            ;;
    esac
    
    # Save config file backup after each execution
    save_config_backup "$PROJECT_CONFIG" "$option" "$project"
    
    return $option_result
}

# Main execution
main() {
    # Validate Option argument if provided
    if [[ -n "$Option_arg" ]]; then
        if [[ ! "$Option_arg" =~ ^[1-2]$ ]]; then
            echo "✗ Error: Invalid option number: $Option_arg"
            echo "Option must be 1 (Docker/LSF) or 2 (Direct execution)"
            exit 1
        fi
    fi
    
    # If Project, Option, and bioproject_id are provided as arguments, run directly (non-interactive mode)
    if [[ -n "$Project_arg" ]] && [[ -n "$Option_arg" ]] && [[ -n "$bioproject_id_arg" ]]; then
        echo "Running in direct execution mode..."
        execute_option "$Option_arg" "$Project_arg" "$bioproject_id_arg"
        return $?
    fi
    
    # If Project and Option are provided, prompt for bioproject_id
    if [[ -n "$Project_arg" ]] && [[ -n "$Option_arg" ]]; then
        echo "Project pre-selected: $Project_arg"
        echo "Option pre-selected: $Option_arg"
        execute_option "$Option_arg" "$Project_arg" "$bioproject_id_arg"
        return $?
    fi
    
    # If only Project is provided, show menu but pre-select project
    if [[ -n "$Project_arg" ]]; then
        echo "Project pre-selected: $Project_arg"
        show_menu
        read -p "Select an option [1-3]: " choice
        
        case $choice in
            1)
                execute_option "1" "$Project_arg" "$bioproject_id_arg"
                exit $?
                ;;
            2)
                execute_option "2" "$Project_arg" "$bioproject_id_arg"
                exit $?
                ;;
            3)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid option. Please select 1-3."
                exit 1
                ;;
        esac
    fi
    
    # Otherwise, show full interactive menu
    show_menu
    read -p "Select an option [1-3]: " choice
    
    case $choice in
        1)
            execute_option "1"
            exit $?
            ;;
        2)
            execute_option "2"
            exit $?
            ;;
        3)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please select 1-3."
            exit 1
            ;;
    esac
}

# Run main function
main
