import sys

from Crypto.Hash import RIPEMD160

encoded = sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read().strip()
data = bytes.fromhex(encoded)
digest = RIPEMD160.new(data=data).digest()
print(digest.rjust(32, b"\x00").hex(), end="")
