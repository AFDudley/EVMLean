import Ethereum.PerformIO
import Ethereum.PrecompileOutput
import Ethereum.Wheels
import Conform.Wheels

def blobBLS12_381 (operation : Nat) (data : String) : String :=
  totallySafePerformIO <|
    runProcessWithInput {
      cmd := "python3"
      args := #["Ethereum/EllipticCurvesPy/bls12_381.py", toString operation]
    } data

/-- The EIP-2537 BLS12-381 precompile at address `operation` (`0x0b`–`0x11`). -/
def BLS12_381 (operation expectedSize : Nat) (data : ByteArray) : Except String ByteArray :=
  Ethereum.checkedPrecompileOutput s!"BLS12_381_{operation}" expectedSize <|
    match blobBLS12_381 operation (toHex data) with
    | "error" => .error "BLS12-381 operation failed"
    | output => ByteArray.ofBlob output
