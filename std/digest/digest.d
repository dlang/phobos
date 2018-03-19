module std.digest.digest;

import _newDigest = std.digest;

// @@@DEPRECATED_2.084@@@
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias isDigest = _newDigest.isDigest;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias DigestType = _newDigest.DigestType;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias hasPeek = _newDigest.hasPeek;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias hasBlockSize = _newDigest.hasBlockSize;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias digest = _newDigest.digest;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias hexDigest = _newDigest.hexDigest;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias makeDigest = _newDigest.makeDigest;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias Digest = _newDigest.Digest;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias Order = _newDigest.Order;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias toHexString = _newDigest.toHexString;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias asArray = _newDigest.asArray;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias digestLength = _newDigest.digestLength;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias WrapperDigest = _newDigest.WrapperDigest;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias secureEqual = _newDigest.secureEqual;
deprecated("import std.digest instead of std.digest.digest. std.digest.digest will be removed in 2.084")
alias LetterCase = _newDigest.LetterCase;
