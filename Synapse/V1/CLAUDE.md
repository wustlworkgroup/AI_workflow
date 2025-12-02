# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

AI workflow repository for automation tasks that run on the RIS (Research Infrastructure Services) system at WUSTL (Washington University in St. Louis).

## Agents rules
All agents can only change files in /project.


## Agents

### RIS Login Agent
When users want to use ssh, use the **ris-login** agent for RIS cluster SSH authentication, connection, and session management.

### Synapse agents
When users want to work with Synapse workflows, use these agents:

#### Synapse Task Manager Agent
Use the **synapse-task-manager** agent for Synapse upload/download workflows. This agent prepares and executes the All_in_one_AIworkflow.sh script.

#### Synapse Error Monitor Agent
Use the **synapse-error-monitor** agent to monitor LSF jobs and analyze errors from RIS cluster output files.


### Samtools Task Manager Agent
Use the **samtools-task-manager** agent to execute samtools tasks using Docker locally or on RIS cluster with LSF.


## Architecture

- **Authentication:** Token-based for Synapse; password or SSH key for RIS connections
- **RIS Integration:** All SSH connections are configured for WUSTL RIS infrastructure
- **Error Handling:** Both utilities use retry logic for network operations and provide detailed error messages
- **Security:** Auth credentials stored in external files (never commit `autho.txt` or similar files)

## Directory Structure

- `PY_function/` - Python utilities for RIS workflows
- `sh_files/` - Shell scripts
- `R_function/` - R scripts
- `Project/` - Project-specific workflow directories (agents can modify files here) 
