import Ethereum.PythonHelper

unsafe def unsafePerformIO {τ} [Inhabited τ] (io : IO τ) : τ :=
  match unsafeIO io with
    | Except.ok    a => a
    | Except.error e => panic! s!"unsafePerformIO was a not great idea after all: {e}"

@[implemented_by unsafePerformIO]
def totallySafePerformIO {τ} [Inhabited τ] (io : IO τ) : τ := Inhabited.default

/-- Run a helper process with its (possibly large) input on stdin. Linux limits
a single command-line argument to 128 KiB, which precompile inputs can exceed. -/
def runProcessWithInput (args : IO.Process.SpawnArgs) (input : String) : IO String := do
  let child ← IO.Process.spawn { args with stdin := .piped, stdout := .piped, stderr := .piped }
  let (stdin, child) ← child.takeStdin
  stdin.putStr input
  stdin.flush
  let stdout ← IO.asTask child.stdout.readToEnd .dedicated
  let stderr ← child.stderr.readToEnd
  let exitCode ← child.wait
  let stdout ← IO.ofExcept stdout.get
  if exitCode != 0 then
    throw <| IO.userError s!"process '{args.cmd}' exited with code {exitCode}\nstderr:\n{stderr}"
  pure stdout.trimAscii.toString
