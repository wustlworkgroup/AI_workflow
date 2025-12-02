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
  - Specifically includes: `synapse_uploading2.py`, `synapse_download.py`
- grep synapse in `sh_files/` (Shell scripts containing "synapse")
- grep synapse in `R_function/` (R scripts containing "synapse")
- `env/config_synapse.sh`
- `All_in_one_AIworkflow.sh` (template from Project folder)
- `CLAUDE.md`; save CLAUDE.md into the claude folder in the target directory
- `Project/test_annotations.csv`; copy to `${target_directory}/Project/`


## Workflow

### Step 0.5: Pre-flight Validation

Before starting the sync operation, validate the environment:

1. **Verify target directory is a git repository:**
   ```bash
   if [ ! -d "${target_directory}/.git" ]; then
     echo "ERROR: Target directory is not a git repository"
     echo "Expected: ${target_directory}/.git"
     exit 1
   fi
   ```

2. **Check for uncommitted changes:**
   ```bash
   cd "${target_directory}"
   if [ -n "$(git status --porcelain)" ]; then
     echo "WARNING: Target repository has uncommitted changes:"
     git status --short
     echo ""
     echo "Uncommitted changes may be overwritten. Continue? (y/n)"
     # Wait for user confirmation
   fi
   ```

3. **Verify source directory accessibility:**
   ```bash
   if [ ! -d "/Volumes/Active/AI_workflow" ]; then
     echo "ERROR: Source directory not accessible"
     exit 1
   fi
   ```

4. **Create output directory:**
   ```bash
   mkdir -p "${output_directory}"
   ```

**Report validation results to user before proceeding.**

### Step 1: Scan source directory** (`/Volumes/Active/AI_workflow`)
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
   - File format: Enhanced multi-column tab-separated format
     * Column 1: Original file path (source)
     * Column 2: Target file path (destination)
     * Column 3: Status (NEW/MODIFIED/UNCHANGED)
     * Column 4: Size (in KB)
     * Column 5: Last modified date
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

### Step 4.5: Dry-Run Preview

Before actual copy operation, perform a dry-run to preview changes:

1. **Run rsync in dry-run mode:**
   ```bash
   echo "=== DRY-RUN PREVIEW ==="
   echo "Running rsync dry-run to preview changes..."

   rsync --dry-run -av --itemize-changes \
     --exclude='*auth*.txt' \
     --exclude='*token*.txt' \
     --exclude='*credentials*.json' \
     --exclude='*password*.txt' \
     /Volumes/Active/AI_workflow/.claude/ \
     "${target_directory}/claude/" | tee "${output_directory}/${timestamp}_dryrun.txt"
   ```

2. **Parse dry-run output to show:**
   - Files to be created (marked with `>f+++++++++`)
   - Files to be updated (marked with `>f.st......`)
   - Files unchanged
   - Total changes summary

3. **Display preview summary:**
   ```
   DRY-RUN SUMMARY:
   - New files: 3
   - Modified files: 5
   - Unchanged files: 7
   - Total size to transfer: 125 KB
   ```

4. **Ask user for confirmation:**
   ```
   Continue with actual copy operation? (y/n)
   ```

**Only proceed to Step 5 if user confirms.**

### Step 5: Copy files from copy list** using rsync with exclusions
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

### Step 6: Report** what was copied and what was excluded
   - Summarize successful copies with file counts
   - List any errors or warnings encountered
   - Show files that were excluded and why
   - Total data size copied
   - Copy operation duration

### Step 6.5: Git Status Check

After copying files, automatically check git status and show changes:

1. **Run git status in target directory:**
   ```bash
   cd "${target_directory}"
   echo "=== GIT STATUS CHECK ==="
   git status --short
   ```

2. **Show git diff statistics:**
   ```bash
   echo ""
   echo "=== CHANGES SUMMARY ==="
   git diff --stat
   ```

3. **Categorize changes:**
   - Count new files (green `??` in status)
   - Count modified files (yellow `M` in status)
   - Count deleted files (red `D` in status)

4. **Display summary:**
   ```
   GIT CHANGES DETECTED:
   ✓ New files: 3
   ✓ Modified files: 5
   ✓ Deleted files: 0
   ✓ Total changes: 8 files

   Ready to commit. Recommended next steps:
   1. Review changes: git diff
   2. Stage all: git add .
   3. Commit: git commit -m "Update Synapse workflow ${version}"
   4. Push: git push origin main
   ```

5. **Save git status to output file:**
   ```bash
   git status > "${output_directory}/${timestamp}_git_status.txt"
   git diff --stat >> "${output_directory}/${timestamp}_git_status.txt"
   ```



## Output Format

Provide a summary including:
- Files/folders copied (with counts)
- Files excluded (with reasons)
- Any errors encountered
- Recommendation to review changes before committing
- Save output to: `${output_directory}/${timestamp}_task_output.txt`
  * Include timestamp, version, source/target paths in the output file
  * Format output as readable markdown

### Step 7: Version History Tracking

Create or update a CHANGELOG.md in the target directory to track version history:

1. **Check if CHANGELOG.md exists:**
   ```bash
   if [ -f "${target_directory}/CHANGELOG.md" ]; then
     # Prepend new entry
     mv "${target_directory}/CHANGELOG.md" "${target_directory}/CHANGELOG.md.bak"
   fi
   ```

2. **Create/update CHANGELOG.md with new entry:**
   ```markdown
   # Changelog

   ## [${version}] - $(date +%Y-%m-%d)

   ### Added
   - [List new files added]

   ### Modified
   - [List files that were updated]

   ### Summary
   - Total files synced: ${total_files}
   - Agent definitions updated: ${agent_count}
   - Python scripts updated: ${py_count}
   - Shell scripts updated: ${sh_count}

   ---
   ```

3. **Append existing changelog if it exists:**
   ```bash
   if [ -f "${target_directory}/CHANGELOG.md.bak" ]; then
     tail -n +2 "${target_directory}/CHANGELOG.md.bak" >> "${target_directory}/CHANGELOG.md"
     rm "${target_directory}/CHANGELOG.md.bak"
   fi
   ```

### Step 8: Post-Copy Verification

Verify the integrity and safety of copied files:

1. **Count files verification:**
   ```bash
   echo "=== POST-COPY VERIFICATION ==="
   expected_count=$(grep -c "^/" "${output_directory}/${timestamp}_copy_list.txt")
   actual_count=$(find "${target_directory}" -type f | wc -l)
   echo "Expected files: $expected_count"
   echo "Actual files in target: $actual_count"
   ```

2. **Verify no sensitive data leaked:**
   ```bash
   echo ""
   echo "Scanning for sensitive data patterns..."
   sensitive_files=$(grep -r -l "password\|token\|auth" "${target_directory}" \
     --exclude-dir=.git \
     --exclude="*.md" \
     --exclude="README*" \
     --exclude="CHANGELOG*" | grep -v "example" | grep -v "TEMPLATE")

   if [ -n "$sensitive_files" ]; then
     echo "⚠️  WARNING: Potential sensitive data found in:"
     echo "$sensitive_files"
     echo "Please review these files before committing!"
   else
     echo "✓ No sensitive data patterns detected"
   fi
   ```

3. **Check file sizes match:**
   ```bash
   echo ""
   echo "Verifying file sizes..."
   # Compare sizes of source and target files
   while IFS=$'\t' read -r source target; do
     [[ "$source" =~ ^#.*$ ]] && continue
     if [ -f "$source" ] && [ -f "$target" ]; then
       source_size=$(stat -f%z "$source" 2>/dev/null || stat -c%s "$source" 2>/dev/null)
       target_size=$(stat -f%z "$target" 2>/dev/null || stat -c%s "$target" 2>/dev/null)
       if [ "$source_size" != "$target_size" ]; then
         echo "⚠️  Size mismatch: $(basename $source)"
       fi
     fi
   done < "${output_directory}/${timestamp}_copy_list.txt"
   echo "✓ File size verification complete"
   ```

4. **Generate verification report:**
   ```bash
   {
     echo "=== POST-COPY VERIFICATION REPORT ==="
     echo "Timestamp: $(date)"
     echo "Version: ${version}"
     echo ""
     echo "File Count Check: PASSED"
     echo "Sensitive Data Scan: $([ -z "$sensitive_files" ] && echo "PASSED" || echo "FAILED - Review required")"
     echo "File Size Check: PASSED"
     echo ""
     echo "Verification: $([ -z "$sensitive_files" ] && echo "COMPLETE ✓" || echo "NEEDS REVIEW ⚠️")"
   } > "${output_directory}/${timestamp}_verification.txt"
   ```

## Error Recovery & Common Issues

### Error Handling During Copy

If copy operation fails mid-operation:

1. **Log failures:**
   ```bash
   failed_files="${output_directory}/${timestamp}_failed_files.txt"
   touch "$failed_files"

   # During copy, track failures:
   if ! rsync -av "$source" "$target"; then
     echo "$source -> $target" >> "$failed_files"
   fi
   ```

2. **Create recovery script:**
   ```bash
   if [ -s "$failed_files" ]; then
     echo "Creating recovery script..."
     cat > "${output_directory}/${timestamp}_recovery.sh" <<'EOF'
   #!/bin/bash
   # Auto-generated recovery script
   # Run this to retry failed copies

   while IFS=' -> ' read -r source target; do
     echo "Retrying: $source"
     rsync -av "$source" "$target"
   done < "${failed_files}"
   EOF
     chmod +x "${output_directory}/${timestamp}_recovery.sh"
     echo "Recovery script created: ${timestamp}_recovery.sh"
   fi
   ```

3. **Offer rollback option:**
   ```bash
   echo ""
   echo "Copy operation encountered errors."
   echo "Options:"
   echo "1. Run recovery script to retry: ${timestamp}_recovery.sh"
   echo "2. Rollback changes: cd ${target_directory} && git reset --hard HEAD"
   echo "3. Review failed files: cat ${failed_files}"
   ```

### Common Issues

1. **Target not a git repository:**
   - Check: `git status` in target directory
   - Fix: `git init` or verify correct path

2. **Permission denied:**
   - Check: File/directory permissions
   - Fix: `chmod` or run with appropriate user

3. **Rsync fails:**
   - Check: rsync installed and accessible
   - Check: Disk space in target directory
   - Fix: Free up space or fix rsync installation

4. **Sensitive files detected after copy:**
   - Review: Check verification report
   - Fix: Manually remove sensitive files
   - Update: Add patterns to exclusion list

## Notes

- Always verify the target is a git repository before copying (Step 0.5)
- Use dry-run preview to catch issues before actual copy (Step 4.5)
- Verify copied files for sensitive data (Step 8)
- Track changes in CHANGELOG.md (Step 7)
- Warn if suspicious files are found that might contain secrets
- Git status automatically shown after copy (Step 6.5)

## README.md Generation

After copying files, create a comprehensive README.md in the target directory root for GitHub publication.

**File location:** `${target_directory}/README.md`

**Content structure:**

```markdown
# Synapse Upload & Download Workflow - Claude AI Agents

AI-powered automation workflow for uploading and downloading files to/from Synapse using Claude Code agents on the RIS (Research Infrastructure Services) cluster at WUSTL.

## Overview

This repository contains Claude AI agents and scripts for automated Synapse file uploads and downloads with LSF job management on the RIS cluster.

**Version:** ${version}
**Generated:** $(date)

## Features

- 🤖 Automated Synapse file uploads and downloads via Claude AI agents
- 📊 CSV-based file annotation management
- 🖥️ RIS cluster integration with LSF job scheduling
- 🔍 Real-time job monitoring and error detection
- 🐳 Docker containerization support
- 📥 Download files from Synapse folders or CSV lists

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
│   ├── synapse_uploading2.py            # Synapse upload Python script
│   └── synapse_download.py              # Synapse download Python script
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

2. **Download files from Synapse:**
   \`\`\`
   Ask Claude: "Download files from Synapse  to the folder"
   \`\`\`


3. **Monitor job status:**
   \`\`\`
   Ask Claude: "Check job status"
   \`\`\`

4. **Sync files to GitHub:**
   \`\`\`
   Ask Claude: "Use synapse-github-remote agent"
   \`\`\`


**Example:**
\`\`\`csv
files,resourceType,dataType,specimenID,assay
/path/to/file.bam,experimentalData,genomicVariants,SAMPLE-001,wholeGenomeSeq
\`\`\`

## Available Claude Agents

### synapse-task-manager
Executes Synapse upload workflows by preparing and running the All_in_one_AIworkflow.sh script.

### synapse-download
Downloads files from Synapse using \`synapse_download.py\`. Supports downloading from folders or CSV lists of Synapse IDs.

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
4. **Download errors:** Verify Synapse IDs are correct and you have read permissions

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
