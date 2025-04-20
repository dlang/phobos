// Written in the D programming language.

/+
    Entropy library prototype.

    This code has not been audited.
    Do not use for cryptographic purposes.

    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Elias Batek
    Source:    $(PHOBOSSRC std/internal/entropy.d)
 +/
module std.internal.entropy.entropy;

public import std.internal.entropy.common;

import std.internal.entropy.bsd;
import std.internal.entropy.linux;
import std.internal.entropy.posix;
import std.internal.entropy.windows;
import std.meta;

@safe unittest
{
    auto buffer = new ubyte[](32);
    forceEntropySource(defaultEntropySource);
    const result = getEntropy(buffer);

    assert(
        !result.isUnavailable,
        "The default entropy source for the target platform"
        ~ " is unavailable on this machine. Please consider"
        ~ " patching it to accommodate to your environment."
    );
    assert(result.isOK);
}

@nogc nothrow:

// Flagship function
EntropyResult getEntropy(scope void[] buffer) @safe
{
    return getEntropyImpl(buffer);
}

// Convenience overload
EntropyResult getEntropy(scope ubyte[] buffer) @safe
{
    return getEntropy(cast(void[]) buffer);
}

// Convenience wrapper
EntropyResult getEntropy(scope void* buffer, size_t length) @system
{
    return getEntropy(buffer[0 .. length]);
}

// Used to manually set the entropy source to use
void forceEntropySource(EntropySource source) @safe
{
    _entropySource = source;
}

/+
    (In-)Convenience wrapper.

    In general, it’s a bad idea to let users pick sources themselves.
    A sane option should be used by default instead.

    See_also:
        Use `forceEntropySource` instead.
 +/
EntropyResult getEntropy(scope void* buffer, size_t length, EntropySource source) @system
{
    const sourcePrevious = _entropySource;
    scope (exit) _entropySource = sourcePrevious;

    _entropySource = source;
    return getEntropy(buffer[0 .. length]);
}

package(std):

pragma(inline, true) void crashOnError(const EntropyResult value) pure @safe
{
    if (value.isOK)
        return;

    assert(false, value.toString());
}

private:

struct SrcFunPair(EntropySource source, alias func)
{
    enum  src = source;
    alias fun = func;
}

template isValidSupportedSource(SupportedSource)
{
    import std.traits;

    enum isValidSupportedSource = (
        is(SupportedSource == SrcFunPair!Args, Args...) &&
        SupportedSource.src != EntropySource.tryAll &&
        SupportedSource.src != EntropySource.none
    );
}

/++
    Params:
        defaultSource = Default entropy source of the platform
        SupportedSources = Sequence of `SrcFunPair`
                           representing the supported sources of the platform
 +/
mixin template entropyImpl(EntropySource defaultSource, SupportedSources...)
if (allSatisfy!(isValidSupportedSource, SupportedSources))
{
    enum defaultEntropySource = defaultSource;

    EntropyResult getEntropyImpl(scope void[] buffer) @safe
    {
        switch (_entropySource)
        {
            static foreach (source; SupportedSources)
            {
                case source.src:
                    return source.fun(buffer);
            }

        case EntropySource.tryAll:
            {
                const result = _tryEntropySources(buffer);
                result.saveSourceForNextUse();
                return result;
            }

        case EntropySource.none:
            return getEntropyViaNone(buffer);

        default:
            return EntropyResult(EntropyStatus.unavailablePlatform, _entropySource);
        }
    }

    EntropyResult _tryEntropySources(scope void[] buffer) @safe
    {
        EntropyResult result;

        static foreach (source; SupportedSources)
        {
            result = source.fun(buffer);
            if (!result.isUnavailable)
                return result;
        }

        result = EntropyResult(
            EntropyStatus.unavailable,
            EntropySource.none,
        );

        return result;
    }
}

version (Darwin) mixin entropyImpl!(
    EntropySource.arc4random,
    SrcFunPair!(EntropySource.arc4random, getEntropyViaARC4Random),
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (DragonFlyBSD) mixin entropyImpl!(
    EntropySource.getentropy,
    SrcFunPair!(EntropySource.getentropy, getEntropyViaGetentropy),
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (FreeBSD) mixin entropyImpl!(
    EntropySource.getentropy,
    SrcFunPair!(EntropySource.getentropy, getEntropyViaGetentropy),
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (linux) mixin entropyImpl!(
    EntropySource.getrandom,
    SrcFunPair!(EntropySource.getrandom, getEntropyViaGetrandom),
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (NetBSD) mixin entropyImpl!(
    EntropySource.arc4random,
    SrcFunPair!(EntropySource.arc4random, getEntropyViaARC4Random),
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (OpenBSD) mixin entropyImpl!(
    EntropySource.arc4random,
    SrcFunPair!(EntropySource.arc4random, getEntropyViaARC4Random),
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (Posix) mixin entropyImpl!(
    EntropySource.charDevURandom,
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (Windows) mixin entropyImpl!(
    EntropySource.bcryptGenRandom,
    SrcFunPair!(EntropySource.bcryptGenRandom, getEntropyViaBCryptGenRandom),
);
else mixin entropyImpl!(
    EntropySource.none,
);

static EntropySource _entropySource = defaultEntropySource;

void saveSourceForNextUse(const EntropyResult result) @safe
{
    if (!result.isOK)
        return;

    _entropySource = result.source;
}

EntropyResult getEntropyViaNone(scope void[]) @safe
{
    return EntropyResult(EntropyStatus.unavailable, EntropySource.none);
}
