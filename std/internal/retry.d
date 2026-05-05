/**
Internal helpers for retrying interrupted system calls.

These helpers are $(D package(std)) — visible to every Phobos module but
not part of the documented public API.

See $(LINK https://man7.org/linux/man-pages/man7/signal.7.html).

Copyright: The D Language Foundation
License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).
*/
module std.internal.retry;

import core.stdc.errno : errno, EINTR;

/**
Repeatedly invokes $(D syscall) while it returns $(D errorSentinel) and
$(D errno == EINTR). Returns the final result — the caller remains
responsible for diagnosing any non-$(D EINTR) error.

Use for one-shot calls whose failure indicator is a sentinel value
($(D -1), $(D EOF), $(D WEOF), $(D null), …). For partial-progress I/O
loops, prefer $(D retryShortIO).
*/
package(std) auto retryOnEINTR(T)(scope T delegate() syscall, T errorSentinel) @system
{
    auto r = syscall();
    while (r == errorSentinel && .errno == EINTR)
        r = syscall();
    return r;
}

/// Convenience overload for the common $(D errorSentinel = -1) case.
package(std) auto retryOnEINTR(T)(scope T delegate() syscall) @system
if (is(T : long))
{
    return retryOnEINTR!T(syscall, cast(T) -1);
}

/**
Drives $(D attempt(offset)) until it has consumed all $(D total) items or
hit a non-$(D EINTR) error/EOF. $(D attempt) receives the current write
offset and must return the number of items transferred on that call
(matching $(D fwrite)'s and $(D posix.write)'s semantics).

Returns the cumulative number of items transferred. The caller compares
the return with $(D total) to decide whether to throw or accept a short
result.

$(D onEINTR) runs after every $(D EINTR)-induced retry decision. Pass
$(D () { clearerr(handle); }) for stdio call sites to prevent the
stream's sticky error flag from lying to subsequent code; pass $(D null)
for raw-syscall sites that have no error flag to clear.
*/
package(std) size_t retryShortIO(
    scope size_t delegate(size_t startOffset) attempt,
    size_t total,
    scope void delegate() onEINTR = null) @system
{
    size_t done = 0;
    while (done < total)
    {
        immutable n = attempt(done);
        if (n > 0)
        {
            done += n;
            continue;
        }
        if (.errno == EINTR)
        {
            if (onEINTR !is null) onEINTR();
            continue;
        }
        break; // permanent error or EOF — caller decides
    }
    return done;
}

// ---------------------------------------------------------------------------
// Unit tests — all use stubs; no real I/O needed.
// ---------------------------------------------------------------------------

@system unittest
{
    import core.stdc.errno : EIO;

    // retryOnEINTR returns immediately on success.
    {
        int calls = 0;
        int r = retryOnEINTR(() { ++calls; return 0; }, -1);
        assert(r == 0 && calls == 1);
    }

    // retryOnEINTR retries while sentinel + EINTR, stops when errno != EINTR,
    // and propagates the final return value.
    {
        int attempts = 0;
        int r = retryOnEINTR(() @system {
            ++attempts;
            if (attempts < 3)
            {
                .errno = EINTR;
                return -1;
            }
            return 42;
        }, -1);
        assert(r == 42 && attempts == 3);
    }

    // retryOnEINTR does NOT retry on a non-EINTR errno.
    {
        int calls = 0;
        int r = retryOnEINTR(() @system {
            ++calls;
            .errno = EIO;
            return -1;
        }, -1);
        assert(r == -1 && calls == 1);
    }

    // retryShortIO advances `done` by each chunk's report and passes the
    // correct offset to each successive call.
    {
        size_t[] offsets;
        size_t r = retryShortIO(
            (size_t off) { offsets ~= off; return cast(size_t) 2; },
            6);
        assert(r == 6);
        assert(offsets == [0, 2, 4]);
    }

    // retryShortIO retries on (0, EINTR) and breaks on (0, non-EINTR).
    {
        int calls = 0;
        size_t r = retryShortIO(
            (size_t off) @system {
                ++calls;
                if (calls == 1) { .errno = EINTR; return cast(size_t) 0; }
                return cast(size_t) 1;
            },
            1);
        assert(r == 1 && calls == 2);

        calls = 0;
        r = retryShortIO(
            (size_t off) @system {
                ++calls;
                .errno = EIO;
                return cast(size_t) 0;
            },
            4);
        assert(r == 0 && calls == 1);
    }

    // retryShortIO invokes onEINTR exactly once per EINTR retry decision.
    {
        int eintrCallbacks = 0, calls = 0;
        size_t r = retryShortIO(
            (size_t off) @system {
                ++calls;
                if (calls <= 2) { .errno = EINTR; return cast(size_t) 0; }
                return cast(size_t) 3;
            },
            3,
            () { ++eintrCallbacks; });
        assert(r == 3 && eintrCallbacks == 2);
    }
}
