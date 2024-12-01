import pathlib
import logging
import shutil
import sys

from typing import Tuple

logger = logging.getLogger()

logger.setLevel(logging.WARNING)

EXCLUDED_FILETYPES = {'.log', '.txt'}

DRY_RUN = False

def init_logger():
    # Create a console handler and set its level to INFO
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)

    # Create a formatter and attach it to the handler
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)

    # Add the handler to the logger
    logger.addHandler(ch)

def get_files(base_pth: str) -> Tuple[list[pathlib.Path], list[pathlib.Path]]:
    asset_files: list[pathlib.Path] = []
    json_files: list[pathlib.Path] = []

    base = pathlib.Path(base_pth)

    for file in base.rglob('*'):
        if file.is_file() and file.suffix.lower() not in EXCLUDED_FILETYPES:
            if file.suffix.lower() == '.json':
                json_files.append(file)
            else:
                asset_files.append(file)

    logger.info(f"{len(asset_files)} asset files detected.")
    logger.info(f"{len(json_files)} json files detected.")

    return asset_files, json_files

def lower_ext(file: pathlib.Path, dry_run: bool = True):
    """Lower case all file extensions."""
    def _rename(file: pathlib.Path, new_file_name: str, dry_run: bool):
        """ Proceed to rename.
        We use a temporary file as intermediary to avoid shutil.SameFileError when only the case
        differ.
        """
        new_file_path = file.parent / new_file_name
        temp_name = file.parent / f"temp_{file.name}"

        if not dry_run:
            file.rename(temp_name)
            temp_name.rename(new_file_path)

        logger.info(f"Renamed: {file} -> {new_file_path}")

    if file.suffix.lower() == '.json':
        logger.debug(file)
        try:
            base_filename, ext = file.stem.rsplit('.', 1)
            if ext != ext.lower():
                _rename(file, f"{base_filename}.{ext.lower()}.json", dry_run)
        except ValueError:
            logger.warning(f"Ignoring renaming {file}. The JSON file does not contain an asset file extension.")

    if file.suffix != file.suffix.lower():
        _rename(file, file.stem + file.suffix.lower(), dry_run)

def resolve_sidecar(file: pathlib.Path, dry_run: bool = True):
    """Generate sidecar whenever they don't match the asset name."""
    file_json = f"{file}.json".lower()
    if any(str(json_file).lower() == file_json for json_file in json_files):
        return

    file_base = file.absolute().with_suffix("")

    str_compare = str(file_base) + "."

    # We must truncate here.
    # Google Takeout truncates long filenames so filenames over 47 chars fail to get a matching .json.
    if len(file_base.name) > 46:
        str_compare = str(file_base.parent) + "/" + file_base.name[:46] + "."

    sidecar_found = [f for f in json_files if str(f.absolute()).startswith(str_compare)]
    
    if len(sidecar_found) > 1:
        raise ValueError(
            f"Cannot determine a single JSON sidecar file for {file}."
            f"Found {sidecar_found}."
            f"str_compare used: {str_compare}"
        )
    elif len(sidecar_found) == 1:
        src = str(sidecar_found[0].resolve())
        dest = str(file.resolve()) + ".json"
        logger.info(f"Copy {src} --> {dest}")
        if not dry_run:
            shutil.copy(src, dest)
    else:
        logger.info(f"No JSON sidecar file found for {file}.")
        logger.debug(f"String used to find JSON sidecar: {str_compare}")

init_logger()

base_path = sys.argv[1]

asset_files, json_files = get_files(base_path)

for file in asset_files:
    resolve_sidecar(file, DRY_RUN)
    lower_ext(file, DRY_RUN)
