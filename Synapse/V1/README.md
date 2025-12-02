# Synapse Upload & Download Workflow - Claude AI Agents

AI-powered automation workflow for uploading and downloading files to/from Synapse using Claude Code agents on the RIS (Research Infrastructure Services) cluster at WUSTL.

## Overview

This repository contains Claude AI agents and scripts for automated Synapse file uploads and downloads with LSF job management on the RIS cluster.

**Version:** V1
**Last Sync:** 2025-12-02 09:54:44

## Features

- 🤖 Automated Synapse file uploads and downloads via Claude AI agents
- 📊 CSV-based file annotation management
- 🖥️ RIS cluster integration with LSF job scheduling
- 🔍 Real-time job monitoring and error detection
- 🐳 Docker containerization support
- 📥 Download files from Synapse folders or CSV lists

## Repository Structure

```
.
├── .claude/                         # Claude AI agent definitions (NEW structure)
│   └── agents/
│       ├── synapse-task-manager.md      # Manages Synapse upload/download tasks
│       ├── synapse-error-monitor.md     # Monitors LSF jobs and errors
│       └── synapse-github-remote.md     # Syncs files to GitHub
├── claude/                          # Legacy agent definitions
│   ├── agents/
│   │   ├── synapse-task-manager.md      # Manages Synapse upload tasks
│   │   ├── synapse-error-monitor.md     # Monitors LSF jobs and errors
│   │   ├── synapse-github-remote.md     # Syncs files to GitHub
│   │   ├── samtools-task-manager.md     # Manages Samtools BAM operations
│   │   └── ris-login.md                 # Handles RIS SSH authentication
│   └── CLAUDE.md                        # Claude Code project instructions
├── PY_function/
│   ├── synapse_uploading2.py            # Synapse upload Python script
│   └── synapse_download.py              # Synapse download Python script
├── sh_files/
│   ├── 1_Docker_synapse_uploading2.sh   # Docker wrapper for uploads
│   └── 1_Docker_synapse_download.sh     # Docker wrapper for downloads
├── env/
│   └── config_synapse.sh                # Synapse configuration template
├── Project/
│   ├── 10172025_BAM_transfer/           # Example BAM transfer workflow
│   │   ├── config_synapse.sh                # Synapse configuration
│   │   └── All_in_one_AIworkflow.sh         # Workflow orchestration script
│   ├── All_in_one_AIworkflow.sh         # Main workflow orchestration script
│   └── test_annotations.csv             # Example annotation file
├── CLAUDE.md                        # Repository instructions (root level)
├── CHANGELOG.md                     # Version history and changes
└── README.md                        # This file
```

## Prerequisites

1. **Claude Code** - Install from [claude.ai/code](https://claude.ai/code)
2. **Synapse Account** - Register at [synapse.org](https://www.synapse.org/)
3. **RIS Access** - WUSTL RIS cluster credentials

## Setup Instructions

### 1. Install Claude AI Agents Locally

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd Synapse/V1
   ```

2. Copy the `claude/` directory to your working directory as `.claude/`:
   ```bash
   cp -r claude/ /path/to/your/project/.claude/
   ```

3. Open your project in Claude Code:
   ```bash
   cd /path/to/your/project
   claude-code .
   ```

### 2. Configure RIS Authentication

Create an authentication file for the RIS login agent:

**File:** `auth.txt` (keep this file secure and **never commit to git**)

**Format:**
```
RIS_HOST=your_username@ris.wustl.edu
PASSWORD=your_password
PORT=22
```

**Alternative (using SSH key):**
```
RIS_HOST=your_username@ris.wustl.edu
KEY_PATH=/path/to/your/private_key
PORT=22
```

### 3. Configure Synapse Credentials

Create a Synapse authentication token file:

**File:** `synapse_token.txt` (keep this file secure and **never commit to git**)

**Content:** Your Synapse personal access token (get from https://www.synapse.org/#!PersonalAccessTokens:)

## Usage

### Using Claude AI Agents

1. **Start a Synapse upload task:**
   ```
   Ask Claude: "Start synapse upload for syn12345678, folder 10172025_BAM_transfer, csv synapse_annotations.csv"
   ```

2. **Download files from Synapse:**
   ```
   Ask Claude: "Download files from Synapse folder syn12345678 to /path/to/download"
   ```

3. **Monitor job status:**
   ```
   Ask Claude: "Check job status"
   ```

4. **Sync files to GitHub:**
   ```
   Ask Claude: "Use synapse-github-remote agent"
   ```

### CSV Annotation Format

Create a CSV file with the following structure for uploads:

**Example:**
```csv
files,resourceType,dataType,specimenID,assay
/path/to/file.bam,experimentalData,genomicVariants,SAMPLE-001,wholeGenomeSeq
```

## Available Claude Agents

### synapse-task-manager
Executes Synapse upload workflows by preparing and running the All_in_one_AIworkflow.sh script.

### synapse-download
Downloads files from Synapse using `synapse_download.py`. Supports downloading from folders or CSV lists of Synapse IDs.

### synapse-error-monitor
Monitors LSF jobs and analyzes errors from RIS cluster output files.

### synapse-github-remote
Copies essential files to GitHub repository while excluding sensitive data.

### samtools-task-manager
Manages Samtools operations like BAM integrity checking and BAI index generation.

### ris-login
Handles RIS cluster SSH authentication, connection, and session management.

## Security Notes

⚠️ **Important:** Never commit these files to version control:
- `auth.txt`, `autho.txt` - RIS credentials
- `*token*.txt` - Synapse tokens
- `*credentials*.json` - Any credential files
- `.env` - Environment variables
- Files in `Project/` directory - May contain sensitive paths

## Troubleshooting

### Common Issues

1. **Authentication failed:** Check your `auth.txt` format and credentials
2. **Job not starting:** Verify RIS cluster access and LSF availability
3. **Upload errors:** Check Synapse token validity and parent folder permissions
4. **Download errors:** Verify Synapse IDs are correct and you have read permissions

### Getting Help

- Check Claude Code docs: [docs.claude.com](https://docs.claude.com)
- Review agent logs in `github_update/` directory
- Check LSF job output files in `gatk/` directory

## Contributing

This workflow is designed for internal use at WUSTL RIS. For questions or suggestions, contact the maintainer.

## License

Internal use only - WUSTL RIS

---

**Last Updated:** 2025-12-02 09:54:44
**Maintained by:** Claude AI Agent - synapse-github-remote
**Sync Version:** V1
