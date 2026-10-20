import Lean.Data.Json

/-!
# Python helper processes

Several primitives (signature recovery, the trie root, and most cryptographic
precompiles) are computed by the Python scripts in `Ethereum/EllipticCurvesPy`.
Starting a Python process per call dominates the cost of running the
conformance tests, so the scripts are instead run by long-lived helper
processes (`Ethereum/EllipticCurvesPy/helper_server.py`), one request and one
response per line.

A pool holds the idle helpers. A call takes an idle helper, or starts a new
one when there is none, and returns it to the pool afterwards. Each thread
therefore has a helper of its own while it runs, and a single-threaded process
starts Python only once.
-/

namespace Ethereum.PythonHelper

/-- A running helper: the pipes to its stdin and from its stdout. -/
structure Helper where
  requests  : IO.FS.Handle
  responses : IO.FS.Handle

/-- The idle helpers. -/
initialize pool : IO.Ref (Array Helper) ← IO.mkRef #[]

def serverScript : String := "Ethereum/EllipticCurvesPy/helper_server.py"

def spawn : IO Helper := do
  let child ← IO.Process.spawn {
    cmd := "python3"
    args := #[serverScript]
    stdin := .piped
    stdout := .piped
    stderr := .inherit
  }
  let (requests, child) ← child.takeStdin
  pure { requests, responses := child.stdout }

def acquire : IO Helper := do
  match ← pool.modifyGet fun helpers => (helpers.back?, helpers.pop) with
  | some helper => pure helper
  | none => spawn

def release (helper : Helper) : IO Unit :=
  pool.modify (·.push helper)

/--
Run the helper script `script` with command-line arguments `args` and input
`stdin`, returning what it prints, without surrounding whitespace. Fails, as a
failing process would, when the script raises an exception or exits with a
nonzero status.
-/
def run (script : String) (args : Array String) (stdin : String := "") : IO String := do
  let helper ← acquire
  let request := Lean.Json.mkObj
    [ ("script", .str script)
    , ("args", .arr (args.map .str))
    , ("stdin", .str stdin) ]
  helper.requests.putStrLn request.compress
  helper.requests.flush
  let line ← helper.responses.getLine
  if line.isEmpty then
    -- The helper died; do not return it to the pool.
    throw <| IO.userError s!"Python helper exited while running {script}"
  release helper
  let response ← IO.ofExcept (Lean.Json.parse line)
  match response.getObjValAs? Bool "ok" with
  | .ok true => return (← IO.ofExcept (response.getObjValAs? String "out")).trimAscii.toString
  | _ =>
    let err := (response.getObjValAs? String "err").toOption.getD line
    throw <| IO.userError s!"Python helper {script} failed:\n{err}"

end Ethereum.PythonHelper
