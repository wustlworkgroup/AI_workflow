import argparse
import csv
import sys
from pathlib import Path
from typing import List

from synapseclient import File, Synapse
from synapseclient.core.exceptions import SynapseError
from typing import List, Dict
#files,resourceType,dataType,specimenID,assay,/path/to/file1.bam,genomic,exome,WU-734_Tumor,WGS,/path/to/file2.fastq,sequence,RNA,WU-561_Normal,RNAseq


USAGE = (
    "python synapse_uploading.py "
    "--authToken synapse_token.txt "
    "--file_path files_to_upload.csv "
    "--parent_id syn12345"
)


def synapse_login(token_file_path: Path) -> Synapse:
    token_path = token_file_path.expanduser()
    try:
        token = token_path.read_text(encoding="utf-8").strip()
    except OSError as exc:
        raise SystemExit(f"Unable to read token file '{token_path}': {exc}") from exc

    if not token:
        raise SystemExit(f"Token file '{token_path}' is empty.")

    # Set cache directory to a writable location
    import os
    cache_dir = os.environ.get('SYNAPSE_CACHE_FOLDER', '/tmp/.synapseCache')
    
    syn = Synapse(skip_checks=True, cache_root_dir=cache_dir)
    try:
        syn.login(authToken=token, silent=True)
    except SynapseError as exc:
        raise SystemExit(f"Synapse login failed: {exc}") from exc

    return syn


def load_file_list(csv_path: Path) -> List[Dict[str, str]]:
    """
    Load a CSV that contains at least a 'files' column and optionally
    annotation columns like resourceType, dataType, specimenID, assay.
    Returns a list of dicts, one per row.
    """
    csv_file = csv_path.expanduser()
    try:
        with csv_file.open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            if reader.fieldnames is None:
                raise SystemExit("CSV file must contain a header row with a 'files' column.")

            column = "files" if "files" in reader.fieldnames else reader.fieldnames[0]

            rows = []
            for row in reader:
                if not row.get(column):
                    continue
                row["files"] = str(Path(row[column]).expanduser())
                rows.append(row)
            return rows
    except OSError as exc:
        raise SystemExit(f"Unable to read CSV file '{csv_file}': {exc}") from exc


def check_synapse_id(syn: Synapse, parent_id: str) -> None:
    """
    Check if a Synapse ID exists and print its description.
    Stop the pipeline if the ID doesn't exist.
    """
    try:
        print(f"Checking Synapse ID: {parent_id}")
        entity = syn.get(parent_id, downloadFile=False)
        
        # Print entity information
        print(f"✅ SUCCESS: Synapse ID '{parent_id}' exists")
        print(f"   Name: {entity.get('name', 'Unknown')}")
        print(f"   Type: {entity.get('concreteType', 'Unknown')}")
        
        # Try to get description if available
        description = entity.get('description', '')
        if description:
            print(f"   Description: {description}")
        else:
            print("   Description: No description available")
            
        # Note: Permission checking removed to avoid deprecation warnings
        # The upload process will handle permission errors if they occur
        print("   Permissions: Will be verified during upload process")
            
        print("")
        
    except SynapseError as exc:
        error_msg = str(exc)
        if "404" in error_msg or "does not exist" in error_msg.lower():
            print(f"❌ ERROR: Synapse ID '{parent_id}' does not exist or is not accessible")
            print("   Please check:")
            print("   1. The Synapse ID is correct")
            print("   2. You have access to this project/folder")
            print("   3. The project/folder is not private or restricted")
            raise SystemExit(f"Pipeline stopped: Invalid Synapse ID '{parent_id}'") from exc
        else:
            print(f"❌ ERROR: Failed to access Synapse ID '{parent_id}': {error_msg}")
            raise SystemExit(f"Pipeline stopped: Cannot access Synapse ID '{parent_id}'") from exc  


def upload_files(syn: Synapse, parent_id: str, rows: List[Dict[str, str]]) -> None:
    """
    Upload files to Synapse, skipping files that already exist.
    """
    uploaded_count = 0
    skipped_count = 0
    
    for row in rows:
        file_path = Path(row["files"])
        if not file_path.exists():
            raise SystemExit(f"File '{file_path}' listed in CSV does not exist.")

        # Check if file already exists in Synapse using findEntityId (more efficient)
        filename = file_path.name
        try:
            existing_id = syn.findEntityId(filename, parent_id)
            if existing_id:
                print(f"⏭️  SKIPPED: '{file_path}' already exists in Synapse (ID: {existing_id})", flush=True)
                skipped_count += 1
                continue
                
        except Exception as e:
            print(f"⚠️  Warning: Could not check for existing files: {e}")
            # Continue with upload if we can't check for existing files

        # File doesn't exist, proceed with upload
        entity = File(str(file_path), parent=parent_id)

        # Extract annotations if present
        annotations = {}
        for key in ["resourceType", "dataType", "specimenID", "assay"]:
            if key in row and row[key]:
                annotations[key] = row[key]

        # Attach annotations
        if annotations:
            entity.annotations = annotations

        try:
            stored = syn.store(entity)
            print(f"✅ UPLOADED: '{file_path}' -> Synapse ID {stored['id']}", flush=True)
            uploaded_count += 1
        except Exception as e:
            print(f"❌ FAILED: Could not upload '{file_path}': {e}", flush=True)
    
    # Print summary
    print(f"\n📊 Upload Summary:")
    print(f"   ✅ Uploaded: {uploaded_count} files")
    print(f"   ⏭️  Skipped: {skipped_count} files")
    print(f"   📁 Total processed: {uploaded_count + skipped_count} files")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Upload files listed in a CSV (column 'files') to a Synapse project or folder.",
        epilog=f"Example:\n  {USAGE}",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--authToken",
        "--tokenfile",
        dest="tokenfile_path",
        required=True,
        type=Path,
        help="Path to a file containing a Synapse personal access token.",
    )
    parser.add_argument(
        "--file_path",
        required=True,
        type=Path,
        help="Path to a CSV file with a 'files' column listing local file paths.",
    )
    parser.add_argument(
        "--parent_id",
        required=True,
        help="Synapse ID of the destination project or folder (e.g., syn123).",
    )
    return parser


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    # Login to Synapse
    syn = synapse_login(args.tokenfile_path)
    
    # Check if the Synapse parent ID exists and print its description
    check_synapse_id(syn, args.parent_id)
    
    # Load file list from CSV
    file_paths = load_file_list(args.file_path)

    if not file_paths:
        print("No files found in the CSV; nothing to upload.", flush=True)
        return 0

    try:
        upload_files(syn, args.parent_id, file_paths)
    except SynapseError as exc:
        raise SystemExit(f"Synapse upload failed: {exc}") from exc

    print("Upload complete.", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
