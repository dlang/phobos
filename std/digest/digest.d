module std.digest.digest;

static import std.digest;

// scheduled for deprecation in 2.077
// See also: https://github.com/dlang/phobos/pull/5013#issuecomment-313987845
alias isDigest = std.digest.isDigest;
alias DigestType = std.digest.DigestType;
alias hasPeek = std.digest.hasPeek;
alias hasBlockSize = std.digest.hasBlockSize;
alias digest = std.digest.digest;
alias hexDigest = std.digest.hexDigest;
alias makeDigest = std.digest.makeDigest;
alias Digest = std.digest.Digest;
alias Order = std.digest.Order;
alias toHexString = std.digest.toHexString;
alias asArray = std.digest.asArray;
alias digestLength = std.digest.digestLength;
alias WrapperDigest = std.digest.WrapperDigest;
alias secureEqual = std.digest.secureEqual;
alias LetterCase = std.digest.LetterCase;
