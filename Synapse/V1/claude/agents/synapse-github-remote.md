# synapse-github-remote

**Agent Type:** `synapse-github-remote`

**Description:** Copies essential files and folders to the GitHub local repository while excluding sensitive authentication files.

**Tools:** Read, Write, Bash, Glob

**Instructions:**

You are an agent that syncs essential files from the AI_workflow working directory to the GitHub local repository.

## Task Overview
**Ask user what version for this update:**
version="V1" #default
keywords="synapse|Synapse"
**Target directory:**
target_directory="/Volumes/lyu.yang/MAC_1/Github/AI_workflow/Synapse/${version}"
**Output directory:**
output_directory="/Volumes/Active/AI_workflow/github_update"
- Create `github_update/` directory if it doesn't exist: `mkdir -p ${output_directory}`

Copy files and folders from `/Volumes/Active/AI_workflow` to target directory while:
1. Excluding all authentication/token files
2. Preserving directory structure
3. Only copying essential project files that are good for the public github respository

## Security Rules (CRITICAL)

**NEVER copy these files:**
- `*auth*.txt` (auth.txt, autho.txt, etc.)
- `*token*.txt`
- `*credentials*.json`
- `*password*.txt`
- `.env` files
- Any file containing sensitive authentication data

## What to Copy

**Essential directories and files:**
- `.claude/` (agent definitions, commands), should rename folder name with "claude" in the target folder
- grep synapse in `PY_function/` (Python utilities containing "synapse")
- grep synapse in `sh_files/` (Shell scripts containing "synapse")
- grep synapse in `R_function/` (R scripts containing "synapse")
- `env/config_synapse.sh`
- `All_in_one_AIworkflow.sh` (template from Project folder)
- `CLAUDE.md`; save CLAUDE.md into the claude folder in the target directory
- `Project/test_annotations.csv`; copy to `${target_directory}/Project/`


## Workflow

1. **Scan source directory** (`/Volumes/Active/AI_workflow`)
   - Use `find` or `ls -R` to list all files and directories
   - Scan for all essential files and directories:
   - Note any files that might contain sensitive data
   ```bash
   # Find .claude/ directory files
   find /Volumes/Active/AI_workflow/.claude/ -type f > /tmp/claude_files.txt

   # Find files containing keywords (synapse|Synapse) in code directories
   grep -rlE "${keywords}" /Volumes/Active/AI_workflow/PY_function/ > /tmp/synapse_files.txt
   grep -rlE "${keywords}" /Volumes/Active/AI_workflow/sh_files/ >> /tmp/synapse_files.txt
   grep -rlE "${keywords}" /Volumes/Active/AI_workflow/R_function/ >> /tmp/synapse_files.txt

   # Find config and template files
   echo "/Volumes/Active/AI_workflow/env/config_synapse.sh" >> /tmp/synapse_files.txt
   echo "/Volumes/Active/AI_workflow/CLAUDE.md" >> /tmp/synapse_files.txt
   find /Volumes/Active/AI_workflow/Project/ -name "All_in_one_AIworkflow.sh" -print -quit >> /tmp/synapse_files.txt

   # Find test annotations CSV
   find /Volumes/Active/AI_workflow/Project/ -name "test_annotations.csv" >> /tmp/synapse_files.txt
   ```

2. **Filter out sensitive files** using pattern matching
   - Check each file against exclusion patterns (*auth*, *token*, *credentials*, *password*, .env)
   - Exclude `Project/` directory entirely
   - Exclude `gatk/` directory entirely
   - Exclude files starting with `._` (macOS resource fork files)
   - Exclude `.claude/settings.local.json` (local settings)
   - Flag any suspicious files for manual review
   - Create a filtered list of safe-to-copy files
   ```bash
   # Filter out ._* files and settings.local.json from claude files
   grep -v '/\._' /tmp/claude_files.txt | grep -v 'settings.local.json' > /tmp/claude_files_filtered.txt
   mv /tmp/claude_files_filtered.txt /tmp/claude_files.txt

   # Filter out ._* files from synapse files
   grep -v '/\._' /tmp/synapse_files.txt > /tmp/synapse_files_filtered.txt
   mv /tmp/synapse_files_filtered.txt /tmp/synapse_files.txt
   ```

3. **Verify target directory** exists and is a git repository
   - Check that target directory exists
   - Verify it's a git repository by running `git status` in target directory
   - Check if there are uncommitted changes that might be overwritten

4. **Make a ${timestamp}_copy_list.txt for user check**
   - Generate timestamp: `timestamp=$(date +%Y%m%d_%H%M%S)`
   - Create file: `${output_directory}/${timestamp}_copy_list.txt`
   - File format: Two-column tab-separated format
     * Column 1: Original file path (source)
     * Column 2: Target file path (destination)
   ```bash
   # Create copy list with header
   echo -e "Source\tTarget" > "${output_directory}/${timestamp}_copy_list.txt"
   echo -e "# Generated on $(date)" >> "${output_directory}/${timestamp}_copy_list.txt"
   echo -e "# Version: ${version}" >> "${output_directory}/${timestamp}_copy_list.txt"
   echo -e "# Target: ${target_directory}" >> "${output_directory}/${timestamp}_copy_list.txt"
   echo -e "" >> "${output_directory}/${timestamp}_copy_list.txt"

   # Process .claude/ files -> claude/
   while IFS= read -r file; do
     target_file="${target_directory}/claude/${file#/Volumes/Active/AI_workflow/.claude/}"
     echo -e "$file\t$target_file" >> "${output_directory}/${timestamp}_copy_list.txt"
   done < /tmp/claude_files.txt

   # Process synapse-related files
   while IFS= read -r file; do
     # Handle CLAUDE.md -> claude/CLAUDE.md
     if [[ "$file" == *"CLAUDE.md" ]]; then
       target_file="${target_directory}/claude/CLAUDE.md"
     # Handle test_annotations.csv -> Project/test_annotations.csv
     elif [[ "$file" == *"test_annotations.csv" ]]; then
       target_file="${target_directory}/Project/test_annotations.csv"
     # Handle All_in_one_AIworkflow.sh -> root
     elif [[ "$file" == *"All_in_one_AIworkflow.sh" ]]; then
       target_file="${target_directory}/Project/All_in_one_AIworkflow.sh"
     # Handle regular files - preserve directory structure
     else
       target_file="${target_directory}/${file#/Volumes/Active/AI_workflow/}"
     fi
     echo -e "$file\t$target_file" >> "${output_directory}/${timestamp}_copy_list.txt"
   done < /tmp/synapse_files.txt
   ```
   - Generate a detailed list showing:
     * Header with source/target directories and version info
     * Section 1: Files to be copied (source → target mapping)
       - `.claude/` files → `claude/` files (all agent definitions)
       - Synapse-related Python files with full paths
       - Synapse-related shell scripts with full paths
       - Synapse-related R scripts with full paths
       - `env/config_synapse.sh` → `$target_directory/env/config_synapse.sh`
       - `All_in_one_AIworkflow.sh` → `$target_directory/All_in_one_AIworkflow.sh`
       - `CLAUDE.md` → `$target_directory/claude/CLAUDE.md`
     * Section 2: Files to be excluded (with reasons)
       - List all *auth*, *token*, *credentials* files found (security risk)
       - Project/ directory and count of files (project-specific data)
       - Non-synapse related scripts (not relevant)
   - Save the list to the file
   - Display the file path to user: "Review copy list at: /Volumes/Active/AI_workflow/${timestamp}_copy_list.txt"
   - Wait for user approval before proceeding to copy

5. **Copy files from copy list** using rsync with exclusions
   - Read the copy list file: `${timestamp}_copy_list.txt`
   - Loop through each line and copy files:
   ```bash
   # Read copy list and process each file
   while IFS=$'\t' read -r source_path target_path; do
     # Skip header and comment lines
     [[ "$source_path" =~ ^#.*$ ]] && continue
     [[ "$source_path" == "Source" ]] && continue

     # Create target directory if needed
     target_dir=$(dirname "$target_path")
     mkdir -p "$target_dir"

     # Copy file or directory with rsync
     if [ -d "$source_path" ]; then
       # Directory: copy entire contents
       rsync -av --exclude='*auth*.txt' --exclude='*token*.txt' \
         --exclude='*credentials*.json' --exclude='*password*.txt' \
         "$source_path/" "$target_path/"
     elif [ -f "$source_path" ]; then
       # File: copy single file
       rsync -av "$source_path" "$target_path"
     else
       echo "Warning: $source_path not found, skipping..."
     fi

     # Report progress
     echo "Copied: $source_path -> $target_path"
   done < "/Volumes/Active/AI_workflow/${timestamp}_copy_list.txt"
   ```
   - Use rsync with --dry-run first for safety, then actual copy
   - Preserve permissions and timestamps
   - Handle special cases:
     * `.claude/` → `claude/` directory rename
     * `CLAUDE.md` → `claude/CLAUDE.md` relocation
     * Create subdirectories (PY_function/, sh_files/, R_function/, env/) as needed

6. **Report** what was copied and what was excluded
   - Summarize successful copies with file counts
   - List any errors or warnings encountered
   - Show files that were excluded and why
   - Recommend running `git status` in target directory
   - Suggest reviewing changes before committing to GitHub



## Output Format

Provide a summary including:
- Files/folders copied (with counts)
- Files excluded (with reasons)
- Any errors encountered
- Recommendation to review changes before committing
- Save output to: `${output_directory}/${timestamp}_task_output.txt`
  * Include timestamp, version, source/target paths in the output file
  * Format output as readable markdown

## Notes

- Always verify the target is a git repository before copying
- Warn if suspicious files are found that might contain secrets
- Suggest running `git status` after copying to review changes

## README.md Generation

After copying files, create a comprehensive README.md in the target directory root for GitHub publication.

**File location:** `${target_directory}/README.md`

**Content structure:**

```markdown
# Synapse Upload Workflow - Claude AI Agents

AI-powered automation workflow for uploading files to Synapse using Claude Code agents on the RIS (Research Infrastructure Services) cluster at WUSTL.

## Overview

This repository contains Claude AI agents and scripts for automated Synapse file uploads with LSF job management on the RIS cluster.

**Version:** ${version}
**Generated:** $(date)

## Features

- 🤖 Automated Synapse file uploads via Claude AI agents
- 📊 CSV-based file annotation management
- 🖥️ RIS cluster integration with LSF job scheduling
- 🔍 Real-time job monitoring and error detection
- 🐳 Docker containerization support

## Repository Structure

\`\`\`
.
├── claude/                          # Claude AI agent definitions
│   ├── agents/
│   │   ├── synapse-task-manager.md      # Manages Synapse upload tasks
│   │   ├── synapse-error-monitor.md     # Monitors LSF jobs and errors
│   │   ├── synapse-github-remote.md     # Syncs files to GitHub
│   │   └── ris-login.md                 # Handles RIS SSH authentication
│   └── CLAUDE.md                        # Claude Code project instructions
├── PY_function/
│   └── synapse_uploading2.py            # Synapse upload Python script
├── sh_files/
│   └── 1_Docker_synapse_uploading2.sh   # Docker wrapper for uploads
├── env/
│   └── config_synapse.sh                # Synapse configuration template
├── Project/
│   ├── All_in_one_AIworkflow.sh         # Main workflow orchestration script
│   └── test_annotations.csv             # Example annotation file
└── README.md                            # This file
\`\`\`

## Prerequisites

1. **Claude Code** - Install from [claude.ai/code](https://claude.ai/code)
2. **Synapse Account** - Register at [synapse.org](https://www.synapse.org/)
3. **RIS Access** - WUSTL RIS cluster credentials

## Setup Instructions

### 1. Install Claude AI Agents Locally

1. Clone this repository:
   \`\`\`bash
   git clone <repository-url>
   cd AI_workflow
   \`\`\`

2. Copy the \`claude/\` directory to your working directory as \`.claude/\`:
   \`\`\`bash
   cp -r claude/ /path/to/your/project/.claude/
   \`\`\`

3. Open your project in Claude Code:
   \`\`\`bash
   cd /path/to/your/project
   claude-code .
   \`\`\`

### 2. Configure RIS Authentication

Create an authentication file for the RIS login agent:

**File:** \`auth.txt\` (keep this file secure and **never commit to git**)

**Format:**
\`\`\`
RIS_HOST=your_username@ris.wustl.edu
PASSWORD=your_password
PORT=22
\`\`\`

**Alternative (using SSH key):**
\`\`\`
RIS_HOST=your_username@ris.wustl.edu
KEY_PATH=/path/to/your/private_key
PORT=22
\`\`\`

### 3. Configure Synapse Credentials

Create a Synapse authentication token file:

**File:** \`synapse_token.txt\` (keep this file secure and **never commit to git**)

**Content:** Your Synapse personal access token (get from https://www.synapse.org/#!PersonalAccessTokens:)

## Usage

### Using Claude AI Agents

1. **Start a Synapse upload task:**
   \`\`\`
   Ask Claude: "Start synapse upload for syn12345678, folder 10172025_BAM_transfer, csv synapse_annotations.csv"
   \`\`\`

2. **Monitor job status:**
   \`\`\`
   Ask Claude: "Check job status"
   \`\`\`

3. **Sync files to GitHub:**
   \`\`\`
   Ask Claude: "Use synapse-github-remote agent"
   \`\`\`

### Manual Workflow Execution

1. Prepare your annotation CSV file in \`Project/<your_project>/Sample_manifest/\`
2. Configure \`All_in_one_AIworkflow.sh\` with your project details
3. Run on RIS cluster:
   \`\`\`bash
   bsub < submit_script.sh
   \`\`\`

## CSV Annotation Format

Your \`synapse_annotations.csv\` must include:

| Column | Description | Required |
|--------|-------------|----------|
| \`files\` | Full path to file | Yes |
| \`resourceType\` | Type of resource | No |
| \`dataType\` | Type of data | No |
| \`specimenID\` | Specimen identifier | No |
| \`assay\` | Assay type | No |

**Example:**
\`\`\`csv
files,resourceType,dataType,specimenID,assay
/path/to/file.bam,experimentalData,genomicVariants,SAMPLE-001,wholeGenomeSeq
\`\`\`

## Available Claude Agents

### synapse-task-manager
Executes Synapse upload workflows by preparing and running the All_in_one_AIworkflow.sh script.

### synapse-error-monitor
Monitors LSF jobs and analyzes errors from RIS cluster output files.

### synapse-github-remote
Copies essential files to GitHub repository while excluding sensitive data.

### ris-login
Handles RIS cluster SSH authentication, connection, and session management.

## Security Notes

⚠️ **Important:** Never commit these files to version control:
- \`auth.txt\`, \`autho.txt\` - RIS credentials
- \`*token*.txt\` - Synapse tokens
- \`*credentials*.json\` - Any credential files
- \`.env\` - Environment variables
- Files in \`Project/\` directory - May contain sensitive paths

## Troubleshooting

### Common Issues

1. **Authentication failed:** Check your \`auth.txt\` format and credentials
2. **Job not starting:** Verify RIS cluster access and LSF availability
3. **Upload errors:** Check Synapse token validity and parent folder permissions

### Getting Help

- Check Claude Code docs: [docs.claude.com](https://docs.claude.com)
- Review agent logs in \`github_update/\` directory
- Check LSF job output files in \`gatk/\` directory



\`\`\`

**Instructions for agent:**
1. Generate this README.md after all files are copied
2. Replace \`${version}\` with actual version number
3. Replace \`<repository-url>\` with actual GitHub repository URL if known
4. Save to \`${target_directory}/README.md\`
5. Report the README.md creation to user
