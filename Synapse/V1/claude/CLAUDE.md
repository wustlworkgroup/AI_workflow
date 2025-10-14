# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

AI workflow repository for automation tasks that run on the RIS (Research Infrastructure Services) system at WUSTL (Washington University in St. Louis).

## Agents rules
All agents can only change files in /project.


## Core Utilities

### Synapse Upload ([synapse_uploading2.py](PY_function/synapse_uploading2.py))
Uploads files to Synapse (scientific data repository) with annotations.

**Usage:**
```bash
python PY_function/synapse_uploading2.py \
  --authToken synapse_token.txt \
  --file_path files_to_upload.csv \
  --parent_id syn12345
```

**CSV format:** Must have a `files` column with file paths. Optional annotation columns: `resourceType`, `dataType`, `specimenID`, `assay`.

**Note:** Line 66 has a syntax error (`dfrom` instead of `from`) that needs fixing.

### RIS SSH Connection ([ris_ssh_connect.py](PY_function/ris_ssh_connect.py))
Executes SSH commands on RIS hosts using credentials from an auth file.

**Usage:**
```bash
# Basic connection test
python PY_function/ris_ssh_connect.py /path/to/auth.txt

# Run specific command
python PY_function/ris_ssh_connect.py /path/to/auth.txt --cmd "ls -la /home/yang"

# Use SSH key instead of password
python PY_function/ris_ssh_connect.py /path/to/auth.txt --key /path/to/id_rsa
```

**Auth file format (key=value):**
```
RIS_HOST=yang@ris.wustl.edu
PASSWORD=supersecret
PORT=22
```

## Architecture

- **Authentication:** Token-based for Synapse; password or SSH key for RIS connections
- **RIS Integration:** All SSH connections are configured for WUSTL RIS infrastructure
- **Error Handling:** Both utilities use retry logic for network operations and provide detailed error messages
- **Security:** Auth credentials stored in external files (never commit `autho.txt` or similar files)

## Directory Structure

- `PY_function/` - Python utilities for RIS workflows  
- `sh_files/` - Shell scripts  
- 'R_function" - R scripts 
