from pathlib import Path
import os
import sys

out = Path(sys.argv[1])
raw = Path(sys.argv[2])
wrapper = Path(sys.argv[3])
bash = Path(sys.argv[4])

visited = set()

def findExes(at: Path):
    if at in visited:
        return
    visited.add(at)
    if at.is_dir():
        for subdir in at.iterdir():
            findExes(subdir)
    elif os.access(at, os.X_OK) and at.stem != "ld": # Is it executable and not the linker
        # TODO random .so files are executable and shouldn't be wrapped.
        relative = at.relative_to(out)
        newLocation = raw.joinpath(relative)
        newLocation.parent.mkdir(parents = True, exist_ok = True)
        mode = at.stat().st_mode
        at.rename(newLocation)
        at.write_text(f'#!{bash}\n{wrapper} "{out}" "{newLocation}" "$@"')
        at.chmod(mode)

findExes(out)
