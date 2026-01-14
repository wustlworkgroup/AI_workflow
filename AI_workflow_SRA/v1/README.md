# AI_workflow_SRA  
**1-Page Quick Guide**

Automated pipeline to download sequencing data from **NCBI SRA** using **BioProject IDs**, running on the **WUSTL RIS cluster**.

---

## What This Does

- Input: **BioProject ID** (e.g. `PRJNA390610`)
- Output: **FASTQ.gz files + metadata**
- Runs on RIS using Docker + LSF
- Resume-safe and parallelized

---

## Requirements

- WUSTL **RIS account**
- **Claude Code** installed
- SSH access to RIS
- A valid **BioProject ID** from NCBI SRA

---

## Setup (Once)

### 1. Clone the workflow
```bash
git clone https://github.com/wustlworkgroup/AI_workflow.git
cd AI_workflow/AI_workflow_SRA/v1
```

### 2. Install Claude agents
cp -r claude/ /path/to/your/project/.claude/
cd /path/to/your/project
claude-code .

### 3. Configure RIS authentication

Create (do not commit):

env/autho.txt

RIS_HOST=your_username@ris.wustl.edu
KEY_PATH=/path/to/your/private_key
PORT=22

###4 Run the Pipeline
Recommended (via Claude)

In Claude Code:

Input 
"Download SRA data for BioProject PRJNA390610 in project MECA_data"


Claude will:

Create project directory

Submit RIS job

Monitor progress

Notify when finished

**Manual (optional)**
bash env/All_in_one_AIworkflow_SRA.sh \
  MECA_data 1 PRJNA390610 12G 4 48
  
**Data structure**
 
Project/MECA_data/
├── Rawdata/
│   └── SRA_output_PRJNA390610/
│       ├── fastq/   # FASTQ.gz
│       ├── meta/    # metadata tables
│       └── logs/
└── logs/            # LSF job logs
