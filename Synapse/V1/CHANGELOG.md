# Changelog - Synapse V1

All notable changes to the Synapse workflow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [2025-12-02] - V1 Sync Update

### Added
- `.claude/` directory structure with synapse agent configurations
  - `.claude/agents/synapse-error-monitor.md` - LSF job error monitoring agent
  - `.claude/agents/synapse-github-remote.md` - GitHub sync automation agent
  - `.claude/agents/synapse-task-manager.md` - Synapse workflow orchestration agent
- `PY_function/synapse_download.py` - Python utility for Synapse downloads
- `sh_files/1_Docker_synapse_download.sh` - Shell script for Docker-based download workflow
- `Project/10172025_BAM_transfer/` - Example BAM transfer workflow
  - `config_synapse.sh` - Synapse configuration template
  - `All_in_one_AIworkflow.sh` - Complete workflow orchestration script
- `Project/test_annotations.csv` - Test annotation data

### Modified
- `CLAUDE.md` - Updated repository instructions with agent rules
- `Project/All_in_one_AIworkflow.sh` - Workflow improvements
- `README.md` - Documentation updates
- `claude/agents/synapse-task-manager.md` - Enhanced task management logic
- `claude/agents/synapse-github-remote.md` - Improved sync process

### Technical Details
- Total files synced: 11
- Source: `/Volumes/Active/AI_workflow`
- Target: `/Volumes/lyu.yang/MAC_1/Github/AI_workflow/Synapse/V1`
- Sync method: Individual file copy with keyword filtering
- Filter: `synapse|Synapse`

### Exclusions
- macOS resource fork files (`._*`)
- Local configuration (`.claude/settings.local.json`)
- User-specific project directories
- Output files from `gatk/` directory
- Test files

---

## Notes
This changelog tracks changes to the Synapse V1 codebase synced from the main AI_workflow repository.
