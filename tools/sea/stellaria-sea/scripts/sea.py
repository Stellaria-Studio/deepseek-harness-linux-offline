#!/usr/bin/env python3
"""Project adapter; shared runtime is maintained only in Stellaria-SEA."""
import os
from pathlib import Path
import runpy
import subprocess
import sys

root = Path(subprocess.check_output(['git', '-C', str(Path(__file__).parent), 'rev-parse', '--show-toplevel'], text=True).strip())
candidates = [Path(os.environ['STELLARIA_SEA_CORE'])] if os.environ.get('STELLARIA_SEA_CORE') else [root.parent / 'Stellaria-SEA', Path.home() / '.stellaria/sea/core']
for core in candidates:
    script = core / 'stellaria-sea/scripts/sea.py'
    if script.is_file():
        sys.path.insert(0, str(script.parent))
        if '--repo' not in sys.argv:
            sys.argv[1:1] = ['--repo', str(root)]
        runpy.run_path(str(script), run_name='__main__')
        break
else:
    raise SystemExit('SEA 2 core not found. Clone the authorized private Stellaria-Studio/Stellaria-SEA repository next to this project, or set STELLARIA_SEA_CORE. Repository build/test remains available without SEA.')
