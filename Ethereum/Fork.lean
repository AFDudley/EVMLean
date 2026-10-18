/-!
# Execution-layer forks

The semantics is parametric in the active execution-layer fork. A `Fork` is
carried in the execution environment (`ExecutionEnv.fork`) and passed
explicitly to the message-call (`Θ`), contract-creation (`Lambda`) and
transaction (`Υ`) functions. Every fork-dependent rule tests the fork with
`≥`, so a rule introduced at fork `f` stays active in all later forks.

Only the forks from Cancun onward are modelled.
-/

namespace Ethereum

/-- Execution-layer forks supported by the model, in activation order. -/
inductive Fork where
  | cancun
  | prague
  | osaka
  /-- Blob-parameter-only forks (EIP-7892). They differ from Osaka only in
      their blob schedule. -/
  | bpo1
  | bpo2
  | bpo3
  | bpo4
deriving BEq, DecidableEq, Inhabited, Repr

namespace Fork

/-- Position of the fork in activation order. -/
def rank : Fork → Nat
  | .cancun => 0
  | .prague => 1
  | .osaka => 2
  | .bpo1 => 3
  | .bpo2 => 4
  | .bpo3 => 5
  | .bpo4 => 6

instance : LE Fork := ⟨fun a b => a.rank ≤ b.rank⟩
instance : LT Fork := ⟨fun a b => a.rank < b.rank⟩

instance (a b : Fork) : Decidable (a ≤ b) := inferInstanceAs (Decidable (a.rank ≤ b.rank))
instance (a b : Fork) : Decidable (a < b) := inferInstanceAs (Decidable (a.rank < b.rank))

theorem le_def {a b : Fork} : a ≤ b ↔ a.rank ≤ b.rank := Iff.rfl

@[simp] theorem cancun_le (f : Fork) : Fork.cancun ≤ f := Nat.zero_le _

def all : List Fork := [.cancun, .prague, .osaka, .bpo1, .bpo2, .bpo3, .bpo4]

/-- The fork names used by the `ethereum/execution-spec-tests` fixtures. -/
def name : Fork → String
  | .cancun => "Cancun"
  | .prague => "Prague"
  | .osaka => "Osaka"
  | .bpo1 => "BPO1"
  | .bpo2 => "BPO2"
  | .bpo3 => "BPO3"
  | .bpo4 => "BPO4"

def parse? (s : String) : Option Fork := all.find? (·.name == s)

end Fork

/-- A fixed fork, or a network that switches fork at a block timestamp. -/
inductive ForkNetwork where
  | fixed (fork : Fork)
  | transition (before after : Fork) (timestamp : Nat)
deriving BEq, DecidableEq, Inhabited, Repr

namespace ForkNetwork

def activeFork : ForkNetwork → Nat → Fork
  | .fixed fork, _ => fork
  | .transition before after activation, timestamp =>
      if timestamp < activation then before else after

/-- Parses fixture network names such as `Prague` or `PragueToOsakaAtTime15k`. -/
def parse? (s : String) : Option ForkNetwork :=
  match Fork.parse? s with
  | some fork => some (.fixed fork)
  | none => Id.run do
    for before in Fork.all do
      for after in Fork.all do
        if s == before.name ++ "To" ++ after.name ++ "AtTime15k" then
          return some (.transition before after 15000)
    return none

end ForkNetwork

def GAS_PER_BLOB : Nat := 2 ^ 17

/-- Blob parameters of a fork (EIP-7840). -/
structure BlobSchedule where
  targetBlobs : Nat
  maxBlobs : Nat
  baseFeeUpdateFraction : Nat
deriving BEq, DecidableEq, Inhabited, Repr

namespace BlobSchedule

/-- The blob schedule of each fork. Cancun to BPO2 are the mainnet values.
    BPO3 and BPO4 are test-only forks, with the values used by the
    `execution-spec-tests` fixtures. -/
def forFork : Fork → BlobSchedule
  | .cancun => ⟨3, 6, 3338477⟩
  | .prague | .osaka => ⟨6, 9, 5007716⟩
  | .bpo1 => ⟨10, 15, 8346193⟩
  | .bpo2 => ⟨14, 21, 11684671⟩
  | .bpo3 => ⟨21, 32, 20609697⟩
  | .bpo4 => ⟨14, 21, 13739630⟩

def targetBlobGas (schedule : BlobSchedule) : Nat := schedule.targetBlobs * GAS_PER_BLOB
def maxBlobGas (schedule : BlobSchedule) : Nat := schedule.maxBlobs * GAS_PER_BLOB

end BlobSchedule

namespace Fork

/-- The blob schedule active at a fork. -/
def blobSchedule (fork : Fork) : BlobSchedule := BlobSchedule.forFork fork

end Fork

/-- Chain configuration: the fork schedule and the chain id. -/
structure ChainConfig where
  network : ForkNetwork
  chainId : Nat := 1
deriving BEq, Inhabited, Repr

namespace ChainConfig

def activeFork (config : ChainConfig) (timestamp : Nat) : Fork :=
  config.network.activeFork timestamp

end ChainConfig

end Ethereum
