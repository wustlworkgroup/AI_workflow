import argparse
import csv
import sys
from pathlib import Path
from typing import List, Dict, Optional

from synapseclient import Synapse
from synapseclient.core.exceptions import SynapseError

USAGE = (
    "python synapse_download.py "
    "--authToken synapse_token.txt "
    "--file_path files_to_download.csv "
    "--output_dir /path/to/download/directory"
)


def synapse_login(token_file_path: Path) -> Synapse:
    """
    Login to Synapse using a token file.
    Uses SYNAPSE_CACHE_FOLDER environment variable if set.
    """
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
    Load a CSV that contains 'synapse_id' and 'save_path' columns.
    Returns a list of dicts, one per row.
    """
    csv_file = csv_path.expanduser()
    try:
        with csv_file.open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            if reader.fieldnames is None:
                raise SystemExit("CSV file must contain a header row with 'synapse_id' and 'save_path' columns.")

            # Validate required columns
            if "synapse_id" not in reader.fieldnames:
                raise SystemExit("CSV file must contain a 'synapse_id' column.")
            if "save_path" not in reader.fieldnames:
                raise SystemExit("CSV file must contain a 'save_path' column.")

            rows = []
            for row in reader:
                synapse_id = row.get("synapse_id", "").strip()
                save_path = row.get("save_path", "").strip()
                
                if not synapse_id:
                    continue
                
                # Store in consistent format
                row["synapse_id"] = synapse_id
                # Map save_path to local_path for compatibility with download_files
                row["local_path"] = save_path
                rows.append(row)
            return rows
    except OSError as exc:
        raise SystemExit(f"Unable to read CSV file '{csv_file}': {exc}") from exc


def check_synapse_id(syn: Synapse, entity_id: str) -> Dict:
    """
    Check if a Synapse ID exists and return entity information.
    Raises SystemExit if the ID doesn't exist.
    """
    try:
        print(f"Checking Synapse ID: {entity_id}")
        entity = syn.get(entity_id, downloadFile=False)
        
        # Print entity information
        print(f"✅ SUCCESS: Synapse ID '{entity_id}' exists")
        print(f"   Name: {entity.get('name', 'Unknown')}")
        print(f"   Type: {entity.get('concreteType', 'Unknown')}")
        
        # Try to get description if available
        description = entity.get('description', '')
        if description:
            print(f"   Description: {description}")
        else:
            print("   Description: No description available")
            
        print("")
        return entity
        
    except SynapseError as exc:
        error_msg = str(exc)
        if "404" in error_msg or "does not exist" in error_msg.lower():
            print(f"❌ ERROR: Synapse ID '{entity_id}' does not exist or is not accessible")
            print("   Please check:")
            print("   1. The Synapse ID is correct")
            print("   2. You have access to this entity")
            print("   3. The entity is not private or restricted")
            raise SystemExit(f"Pipeline stopped: Invalid Synapse ID '{entity_id}'") from exc
        else:
            print(f"❌ ERROR: Failed to access Synapse ID '{entity_id}': {error_msg}")
            raise SystemExit(f"Pipeline stopped: Cannot access Synapse ID '{entity_id}'") from exc


def download_single_file(syn: Synapse, synapse_id: str, save_path: str, overwrite: bool = False) -> bool:
    """
    Download a single file from Synapse to the specified save path.
    save_path must be a complete file path (including filename).
    Returns True if successful, False otherwise.
    """
    import shutil

    output_path = Path(save_path).expanduser().resolve()

    if output_path.exists() and not overwrite:
        print(f"⏭️  SKIPPED: '{output_path}' already exists", flush=True)
        return False

    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        # Download to parent directory first
        entity = syn.get(synapse_id, downloadLocation=str(output_path.parent))
        downloaded_path = Path(entity.path).expanduser().resolve()

        # If the downloaded file is not at the target location, copy it
        if downloaded_path != output_path:
            if downloaded_path.exists():
                shutil.copy2(str(downloaded_path), str(output_path))
                print(f"✅ DOWNLOADED: '{output_path}'", flush=True)
                return True
            else:
                print(f"❌ FAILED: Downloaded file not found at '{downloaded_path}'", flush=True)
                return False
        else:
            print(f"✅ DOWNLOADED: '{output_path}'", flush=True)
            return True
    except Exception as exc:
        print(f"❌ FAILED: Could not download '{synapse_id}': {exc}", flush=True)
        return False


def get_folder_structure(syn: Synapse, folder_id: str, base_path: Optional[Path] = None) -> List[Dict[str, str]]:
    """
    Recursively get all files from a Synapse folder and return a list with synapse_id and save_path.
    """
    files = []
    try:
        children = syn.getChildren(folder_id)
        
        for child in children:
            child_id = child.get('id')
            child_name = child.get('name', 'Unknown')
            # Check both 'type' and 'concreteType' fields for compatibility
            child_type = child.get('type') or child.get('concreteType', 'Unknown')
            
            # Check if it's a file (FileEntity)
            is_file = (
                child_type == 'org.sagebionetworks.repo.model.FileEntity' or
                child_type == 'file' or
                'FileEntity' in str(child_type)
            )
            
            # Check if it's a folder
            is_folder = (
                child_type == 'org.sagebionetworks.repo.model.Folder' or
                child_type == 'folder' or
                child_type == 'org.sagebionetworks.repo.model.Project' or
                'Folder' in str(child_type) or
                'Project' in str(child_type)
            )
            
            if is_file:
                # It's a file
                if base_path:
                    save_path = str(base_path / child_name)
                else:
                    save_path = child_name
                files.append({
                    'synapse_id': child_id,
                    'save_path': save_path
                })
            elif is_folder:
                # It's a folder, recurse into it
                if base_path:
                    subfolder_path = base_path / child_name
                else:
                    subfolder_path = Path(child_name)
                subfolder_files = get_folder_structure(syn, child_id, subfolder_path)
                files.extend(subfolder_files)
                
    except SynapseError as exc:
        print(f"⚠️  Warning: Could not list children of {folder_id}: {exc}")
    
    return files


def download_files_in_folder(syn: Synapse, synapse_id: str, output_dir: Path, overwrite: bool = False) -> None:
    """
    Download all files from a Synapse folder to the specified output directory.
    Recursively downloads all files maintaining the folder structure.
    """
    output_dir = output_dir.expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Get all files in the folder structure
    download_plan = get_folder_structure(syn, synapse_id, output_dir)
    
    if not download_plan:
        print(f"⚠️  No files found in folder {synapse_id}", flush=True)
        return
    
    # Download each file
    downloaded_count = 0
    skipped_count = 0
    failed_count = 0

   
    print(f"📁 Downloading {len(download_plan)} files from folder {synapse_id}...")
    for file_info in download_plan:
        save_path = file_info["save_path"]
        if download_single_file(syn, file_info["synapse_id"], save_path, overwrite):
            downloaded_count += 1
        elif Path(save_path).exists():
            skipped_count += 1
        else:
            failed_count += 1
    
    print(f"\n📊 Folder Download Summary:")
    print(f"   ✅ Downloaded: {downloaded_count} files")
    print(f"   ⏭️  Skipped: {skipped_count} files")
    print(f"   ❌ Failed: {failed_count} files")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Download files from Synapse using a CSV list of Synapse IDs.",
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
        help="Path to a CSV file with 'synapse_id' and 'save_path' columns.",
    )
    parser.add_argument(
        "--output_dir",
        required=True,
        type=Path,
        help="Directory to download files to.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing files. By default, existing files are skipped.",
    )
    return parser


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    # Login to Synapse
    syn = synapse_login(args.tokenfile_path)
    
    # Load file list from CSV
    file_list = load_file_list(args.file_path)
    
    if not file_list:
        print("No files found in the CSV; nothing to download.", flush=True)
        return 0
    
    # Validate all synapse IDs exist first and determine if they are files or folders
    print("Validating Synapse IDs...")
    entities_info = []
    for row in file_list:
        synapse_id = row["synapse_id"]
        entity = check_synapse_id(syn, synapse_id)  # Raises SystemExit if invalid
        
        # Determine if entity is a file or folder
        entity_type = entity.get('concreteType', '')
        is_folder = entity_type == 'org.sagebionetworks.repo.model.Folder'
        
        entities_info.append({
            'synapse_id': synapse_id,
            'save_path': row.get("local_path", "") or row.get("save_path", ""),
            'is_folder': is_folder,
            'entity': entity
        })
    
    # Download each entity (file or folder)
    downloaded_count = 0
    skipped_count = 0
    failed_count = 0
    
    # Resolve output_dir to absolute path
    output_dir = args.output_dir.expanduser().resolve()
    
    print("Starting downloads...")
    for info in entities_info:
        synapse_id = info["synapse_id"]
        save_path = info["save_path"]
        is_folder = info["is_folder"]
        
        if not save_path:
            print(f"⚠️  Warning: No save_path specified for {synapse_id}, skipping...", flush=True)
            failed_count += 1
            continue
        
        # Resolve save_path: if relative, make it relative to output_dir; if absolute, use as-is
        save_path_obj = Path(save_path)
        if not save_path_obj.is_absolute():
            # Relative path: resolve relative to output_dir
            resolved_save_path = (output_dir / save_path_obj).expanduser().resolve()
        else:
            # Absolute path: use as-is
            resolved_save_path = save_path_obj.expanduser().resolve()
        
        try:
            if is_folder:
                # Download folder recursively, preserving structure
                # save_path is treated as the parent directory where the folder will be created
                folder_name = info["entity"].get('name') or synapse_id
                base_dir = resolved_save_path
                folder_target = (base_dir / folder_name).expanduser().resolve()
                print(f"📁 Downloading folder {synapse_id} to {folder_target}...")
                download_files_in_folder(syn, synapse_id, folder_target, args.overwrite)
                downloaded_count += 1  # Count folder as one download
            else:
                # Download single file
                # save_path is ALWAYS treated as a directory - the file will be saved with its original name
                file_name = info["entity"].get('name', 'downloaded_file')
                # Force save_path to be treated as directory by appending the filename
                file_target = (resolved_save_path / file_name).expanduser().resolve()
                print(f"📄 Downloading file {synapse_id} to directory {resolved_save_path}...")
                if download_single_file(syn, synapse_id, str(file_target), args.overwrite):
                    downloaded_count += 1
                elif file_target.exists():
                    skipped_count += 1
                else:
                    failed_count += 1
        except Exception as exc:
            print(f"❌ FAILED: Unexpected error downloading '{synapse_id}': {exc}", flush=True)
            failed_count += 1
    
    # Print summary
    print(f"\n📊 Download Summary:")
    print(f"   ✅ Downloaded: {downloaded_count} files")
    print(f"   ⏭️  Skipped: {skipped_count} files")
    print(f"   ❌ Failed: {failed_count} files")
    print(f"   📁 Total processed: {downloaded_count + skipped_count + failed_count} files")
    print("Download complete.", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
