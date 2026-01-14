# CLAUDE.md - SRA Workflow

This file provides guidance to Claude Code when working with the SRA (Sequence Read Archive) download workflow.

## Workflow Overview

The SRA workflow automates downloading genomic sequencing data from NCBI's Sequence Read Archive.

## Usage Instructions

**For Claude Code**: When a user requests SRA download, **ask user whether to run locally or on RIS**.

### Option 1: Local Execution
Use the `local_sra_download` skill
- **Skill documentation**: `.claude/skills/local_sra_download/SKILL.md`
- **Main script**: `.claude/skills/local_sra_download/scripts/download_bioproject_sra.sh`
- **Features**: Automated downloads, metadata extraction, parallel processing, resume-friendly
- **Requirements**: Local installation of pysradb, sra-tools, pigz

### Option 2: RIS Execution
Use the `RIS_sra_download` skill
- **Skill documentation**: `.claude/skills/RIS_sra_download/SKILL.md`
- **Main script**: `../PY_function/download_bioproject_sra.sh`
- **Features**: LSF job submission, RIS-optimized resources, resume-friendly, automated downloads
- **Requirements**: RIS access, pysradb, sra-tools, pigz on RIS
- **Use when**: User wants to download on RIS cluster
- **IMMPORTANT** DO NOT EDIT any config.sh or config_sra.sh files in the Project folder.
- **IMPORTANT** Do not genereate download pipeline without using skill
- **IMORTANT** only use "All_in_one_AIworkflow_SRA.sh" to download data from skill

```bash

$RIS_SSH_CMD --cmd "cd /storage1/fs1/hirbea/Active/AI_lab_V1/Project/<PROJECT_NAME> && \
         bash /storage1/fs1/hirbea/Active/AI_lab_V1/AI_workflow_SRA/env/All_in_one_AIworkflow_SRA.sh \
         <PROJECT_NAME> 1 <BIOPROJECT_ID> [memory] [cores] [timeLimit]"
```

All execution details, prerequisites, and instructions are documented in the respective skill documentation.

## Integration with Main Repository

This workflow is referenced in the main `/CLAUDE.md` file:
- **Trigger keywords**: "SRA download", "download SRA data", "SRA project", "NCBI SRA", "Sequence Read Archive"
- **Project location**: `Project/<PROJECT_NAME>/task/<TASK_FOLDER>/`
- **Skills**: `local_sra_download` or `RIS_sra_download`

## Additional Resources

- **Local execution**: [.claude/skills/local_sra_download/SKILL.md](../.claude/skills/local_sra_download/SKILL.md)
- **RIS execution**: [.claude/skills/RIS_sra_download/SKILL.md](../.claude/skills/RIS_sra_download/SKILL.md) (ongoing)
- **NCBI SRA**: https://www.ncbi.nlm.nih.gov/sra
