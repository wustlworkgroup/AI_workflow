# Skill: RIS_sra_download

## Purpose

Download genomic sequencing data from NCBI's Sequence Read Archive (SRA) **only on RIS** and **only through the official entry script** `All_in_one_AIworkflow_SRA.sh`, with a controlled, reproducible execution pattern.

This skill **forbids**:
- Running on local machines or non-RIS clusters
- Running SRA tools (prefetch, fasterq-dump) directly without the wrapper script
- Modifying or bypassing `All_in_one_AIworkflow_SRA.sh` or `download_bioproject_sra.sh`

## Preconditions (MUST be true)

1. Project directory exists: `Project/<PROJECT_NAME>/`
2. Valid NCBI BioProject ID (format: PRJNA######, PRJEB######, or PRJDB######)
3. RIS connection available (authentication configured)
4. Sufficient disk space on RIS storage (large projects can be 100+ GB)
5. `All_in_one_AIworkflow_SRA.sh` script available at: `/storage1/fs1/hirbea/Active/AI_lab_V1/AI_workflow_SRA/env/All_in_one_AIworkflow_SRA.sh`

## Execution Rules (STRICT)

### 0. RIS CPU and memory setting
**Ask user to provide CPU and memroy** if no change, keep user default setting

### 1. Session access

**RIS SSH Connection Command** (use this variable in all commands below):

```bash
ris_autho_path="/Volumes/hirbea/Active/AI_lab_V1/env/autho.txt"
RIS_SSH_CMD='python3 /Volumes/hirbea/Active/AI_lab_V1/PY_function/ris_ssh_connect.py "$ris_autho_path"'
```

**You MUST** use the RIS SSH connection script for ALL commands:

```bash
$RIS_SSH_CMD --cmd "YOUR_COMMAND_HERE"
```

**Do NOT** run commands directly via `ssh` or without the ris_ssh_connect.py wrapper

### 2. Working directory

**You MUST** change into the project directory on RIS within the --cmd parameter:

```bash
$RIS_SSH_CMD --cmd "cd /storage1/fs1/hirbea/Active/AI_lab_V1/Project/<PROJECT_NAME> && YOUR_COMMAND"
```

### 3. Download entry point

**You MUST** launch the download using `All_in_one_AIworkflow_SRA.sh` with the correct arguments:
**Ask user to provide custom CPU number and memory:**
  - CPU number should be a digit (e.g., 4, 8, 16)
  - Memory should be number+G format (e.g., 12G, 120G)
  - Time limit should be a number in hours (e.g., 48) 

**If user provides custom CPU and memory:**
```bash
$RIS_SSH_CMD --cmd "cd /storage1/fs1/hirbea/Active/AI_lab_V1/Project/<PROJECT_NAME> && \
         bash /storage1/fs1/hirbea/Active/AI_lab_V1/AI_workflow_SRA/env/All_in_one_AIworkflow_SRA.sh \
         <PROJECT_NAME> 1 <BIOPROJECT_ID> [memory] [cores] [timeLimit]"
```

**If user does not provide CPU and memory:**
```bash
$RIS_SSH_CMD --cmd "cd /storage1/fs1/hirbea/Active/AI_lab_V1/Project/<PROJECT_NAME> && \
         bash /storage1/fs1/hirbea/Active/AI_lab_V1/AI_workflow_SRA/env/All_in_one_AIworkflow_SRA.sh \
         <PROJECT_NAME> 2 <BIOPROJECT_ID>"
```

**Arguments:**
- `PROJECT_NAME` - Project name (must match directory name in Project/)
- `1` or `2` - Option: 1=Docker/LSF submission, 2=Direct execution; use 1 only 
- `BIOPROJECT_ID` - BioProject ID (e.g., PRJNA390610)
- `[memory]` - Optional: Memory limit (e.g., 120G, default: 12G) only for RIS
- `[cores]` - Optional: Number of cores (default: 4) only  For RIS


**You MUST NOT**:
- Submit custom `bsub` jobs without using the wrapper script
- Run downloads outside of project folders
- Override internal execution logic
- Call `download_bioproject_sra.sh` directly (use `All_in_one_AIworkflow_SRA.sh` instead)

**Resume the failed tak**
- get project ID from failed task
- start downloading from the beginning

## Usage Pattern

### Standard Execution

**Step 1**: Verify project directory structure

```bash
# Check local project directory exists
ls -la /Volumes/hirbea/Active/AI_lab_V1/Project/<PROJECT_NAME>/
```

**Step 2**: Execute download on RIS using All_in_one_AIworkflow_SRA.sh


**Step 3**: Monitor download progress

```bash
# Check LSF job status  
$RIS_SSH_CMD --cmd "bjobs -w"

# Check specific job 
$RIS_SSH_CMD --cmd "bjobs -J <PROJECT_NAME>_SRA_download_<BIOPROJECT_ID>_*"

# Check download logs
$RIS_SSH_CMD --cmd "cd /storage1/fs1/hirbea/Active/AI_lab_V1/Project/<PROJECT_NAME>/SRA_output_<BIOPROJECT_ID> && \
         tail -f logs/SRR*.log"
```


## Configuration File Setup


## Output Structure

After successful completion on RIS:

```
/storage1/fs1/hirbea/Active/AI_lab_V1/Project/<PROJECT_NAME>/
├── SRA_output_<BIOPROJECT_ID>/
│   ├── meta/
│   │   ├── <BIOPROJECT_ID>.metadata.tsv    # Full metadata from pysradb
│   │   └── <BIOPROJECT_ID>.srr.txt         # List of SRR accessions
│   ├── sra/
│   │   └── *.sra                           # SRA files (if KEEP_SRA=1)
│   ├── fastq/
│   │   └── SRR*.fastq.gz                   # Compressed FASTQ files
│   │       └── SRR*_1.fastq.gz             # Paired-end read 1
│   │       └── SRR*_2.fastq.gz             # Paired-end read 2 (if paired)
│   ├── tmp/                                # Temporary files (usually empty)
│   └── logs/
│       └── SRR*.log                        # Individual download logs per SRR
├── logs/                                   # LSF job logs (for Option 1)
│   ├── <PROJECT_NAME>_SRA_download_<BIOPROJECT_ID>_*.log
│   ├── <PROJECT_NAME>_SRA_download_<BIOPROJECT_ID>_*.err
│   └── <PROJECT_NAME>_SRA_download_<BIOPROJECT_ID>_*.result
└── config_sra.sh                           # Project-specific config file
```


## Validation Checklist

Before running, verify:

- [ ] Project directory exists: `Project/<PROJECT_NAME>/`
- [ ] Valid BioProject ID (PRJNA######, PRJEB######, or PRJDB######)
- [ ] RIS authentication configured (`/Volumes/lyu.yang/MAC_1/env/autho.txt`)
- [ ] Sufficient disk space on RIS storage
- [ ] `All_in_one_AIworkflow_SRA.sh` script exists on RIS at: `/storage1/fs1/hirbea/Active/AI_lab_V1/AI_workflow_SRA/env/All_in_one_AIworkflow_SRA.sh`


## Security Guidelines

**IMPORTANT**:
- Downloaded data may contain sensitive information - check data access policies
- Ensure compliance with NCBI data usage policies
- Store downloaded data securely within project folders on RIS storage
- Do not share downloaded data without proper authorization
- Never commit authentication files (`autho.txt`) to version control

## Related Skills/Agents

- **local_sra_download**: Download SRA data locally (not on RIS)
- **ris-login**: RIS SSH connection and session management
- **RNAseq workflow**: Process downloaded RNA-seq data on RIS

## Integration with Main Repository

This skill is triggered by keywords in the main CLAUDE.md:
- "SRA download" + "RIS"
- "download SRA data on RIS"
- "RIS SRA project"

Project structure follows main repository conventions:
- `Project/<PROJECT_NAME>/` - Project directory
- `Project/<PROJECT_NAME>/SRA_output_<BIOPROJECT_ID>/` - SRA download output
- `Project/<PROJECT_NAME>/config_sra.sh` - Project-specific configuration
- `Project/<PROJECT_NAME>/logs/` - LSF job logs (for Option 1)
