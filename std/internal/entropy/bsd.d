// Written in the D programming language.

/+
    BSD entropy providers.

    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Elias Batek
    Source:    $(PHOBOSSRC std/internal/entropy/bsd.d)
 +/
module std.internal.entropy.bsd;

@nogc nothrow:

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version (Darwin)
    version = SecureARC4Random;
version (DragonFlyBSD)
    version = UseGetentropy;
version (FreeBSD)
    version = UseGetentropy;
version (NetBSD)
    version = SecureARC4Random;
version (OpenBSD)
    version = SecureARC4Random;

package(std.internal.entropy):

version (SecureARC4Random)
{
    import std.internal.entropy.common;

    EntropyResult getEntropyViaARC4Random(scope void[] buffer) @trusted
    {
        arc4random_buf(buffer.ptr, buffer.length);
        return EntropyResult(EntropyStatus.ok, EntropySource.arc4random);
    }

    private extern(C) void arc4random_buf(scope void* buf, size_t nbytes) @system;
}

version (UseGetentropy)
{
    import std.internal.entropy.common;

    EntropyResult getEntropyViaGetentropy(scope void[] buffer) @trusted
    {
        const status = callGetentropy(buffer);
        return EntropyResult(status, EntropySource.getentropy);
    }

    private EntropyStatus callGetentropy(scope void[] buffer) @system
    {
        /+
            genentropy(3):
            The maximum buflen permitted is 256 bytes.
        +/
        foreach (chunk; VoidChunks(buffer, 256))
        {
            const status = getentropy(buffer.ptr, buffer.length);
            if (status != 0)
                return EntropyStatus.readError;
        }

        return EntropyStatus.ok;
    }

    private extern(C) int getentropy(scope void* buf, size_t buflen) @system;
}
