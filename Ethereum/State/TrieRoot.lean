import Ethereum.PerformIO
import Ethereum.Wheels

/-- The trie root of the hex-encoded key/value pairs `ws`, computed by the
    Python helper `trie_root.py`, which reads the pairs from its input. -/
def blobComputeTrieRoot (ws : Array (String × String)) : String :=
  let input := ws.foldl (fun acc (k, v) => acc ++ k ++ "\n" ++ v ++ "\n") ""
  totallySafePerformIO <|
    Ethereum.PythonHelper.run "trie_root.py" #["-", ws.size.repr] input
