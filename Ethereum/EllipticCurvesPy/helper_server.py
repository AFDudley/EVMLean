"""
A long-lived host for the helper scripts in this directory.

The Lean semantics calls these scripts for cryptographic primitives and trie
roots (see `Ethereum/PythonHelper.lean`). Starting a Python process per call
costs more than the calls themselves, so this server runs the scripts
in-process instead. It reads one JSON request per line on stdin,

    {"script": "recover.py", "args": ["...", ...], "stdin": "..."}

runs the script as `__main__` with those command-line arguments and stdin,
and writes one JSON response per line on stdout:

    {"ok": true, "out": "<what the script printed>"}
    {"ok": false, "err": "<why the script failed>"}

A script that exits with status 0 (as several do after printing `error`)
counts as a success, exactly as when it runs as its own process.
"""

import io
import json
import os
import runpy
import sys
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


def run(script, args, stdin):
    path = os.path.join(HERE, os.path.basename(script))
    saved = (sys.argv, sys.stdin, sys.stdout)
    out = io.StringIO()
    sys.argv = [path] + list(args)
    sys.stdin = io.StringIO(stdin)
    sys.stdout = out
    try:
        try:
            runpy.run_path(path, run_name="__main__")
        except SystemExit as e:
            if e.code not in (None, 0):
                raise RuntimeError(f"{script} exited with status {e.code}")
    finally:
        sys.argv, sys.stdin, sys.stdout = saved
    return out.getvalue()


def main():
    requests = sys.stdin
    responses = sys.stdout
    for line in requests:
        try:
            request = json.loads(line)
            out = run(request["script"], request.get("args", []), request.get("stdin", ""))
            response = {"ok": True, "out": out}
        except Exception:
            response = {"ok": False, "err": traceback.format_exc()}
        responses.write(json.dumps(response) + "\n")
        responses.flush()


if __name__ == "__main__":
    main()
