unsafe def unsafePerformIO {τ} [Inhabited τ] (io : IO τ) : τ :=
  match unsafeIO io with
    | Except.ok    a => a
    | Except.error e => panic! s!"unsafePerformIO was a not great idea after all: {e}"

/-- The result of an external computation (a Python precompile or the state-root script).
Compiled code runs `io` (`unsafePerformIO`). The kernel cannot reduce it: a proof sees no value,
so a proof that needs a result must state it as a named hypothesis (evm-proof-toolchain
`docs/plan.md` D1). As a `def` with body `Inhabited.default`, the kernel reduced every such
result to the default value, for example `""`, so in proofs BN_ADD, BN_MUL, SNARKV, PointEval,
RIPEMD-160 and ECRECOVER always failed, while the real precompiles succeed. -/
@[implemented_by unsafePerformIO]
opaque totallySafePerformIO {τ} [Inhabited τ] (io : IO τ) : τ
