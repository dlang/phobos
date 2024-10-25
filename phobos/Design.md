# Phobos 3 Design Goals

## Rationale

Phobos v2 is well over a decade old. As time goes by, best practices have evolved, mistakes have become apparent, needs have changed, and better ideas have appeared.

Phobos must also evolve.

## History

* Phobos v1 was for D1
* Phobos v2 was for D2

## Phobos 2

When Phobos v2 was developed, Phobos v1 was obsoleted. This broke a lot of existing code and was a wrenching change for the entire community. Old code needed to be rewritten to use Phobos v2. Some of the discarded v1 modules were restored in the unDead library for the convenience of older code, but the damage had been done.

The existing roots of `core` for the Runtime, `etc` for C Interfaces, and `std` for the v2 Standard Library are to remain reserved for the foreseeable future. Both v2 and v3 will share usage of the `core` and `etc` roots. The `std` root is to be maintained for compatibility but no new features will be added.

Therefore, v2 will continue to be supported following these rules moving forward:

- Will continue to be supported for compatibility purposes.
- Will receive bug fixes and enhancements to adapt to new operating systems and new D Compiler Editions.
- Will not add new functionality.
- Existing Phobos v2 roots remain reserved indefinitely.
- User code must be able to use v2 and v3 capabilities in the same project, however, there may be instances of incompatibility as v2 types are not support in v3 and vice versa.

## Phobos 3

This section is a list of design principles and goals that we have established for Phobos 3.

### Hybrid single-root/multi-trunk package design

Phobos v3 will use a single package root `phobos.` with multiple 'trunk' packages. This allows us to keep the old `std` package root while splitting up the new library into smaller, more manageable, components. Splitting the library into multiple packages provides the following benefits:

1. Only pay for what you use. Different roots can be compiled as separate static/shared libraries and linked as needed, reducing the overall weight of executables. This offers some relief to the long standing community request to break Phobos into individual packages. While we do not agree with atomizing Phobos to the extreme degree of one package per module, multiple package roots allow us to achieve some of that goal in a logical manner.
2. Multiple trunks allow for layering components. The core roots form a foundation upon which to build higher-level packages.
3. Multiple trunks allow for an expanded feature set without adding to package depth.
4. Not all trunks need to be implemented for a given platform to be considered "supported". If only the core roots are required for a platform to be considered supported it becomes significantly less complicated to port D to new platforms.
5. Rules can be applied differently to core vs. non-core roots/trunks. For example, a possible rule could be that core roots/trunks may not throw exceptions under any circumstance, but non-core roots/trunks can. This is not intended to imply that throwing exceptions is encouraged, merely made available to allow more implementation flexibility for more complex constructs.
6. The old `std` root can continue to be maintained and built independently of the new Phobos root.
7. Multiple trunk packages allows Phobos to expand normally without running into the 64k DLL symbol limit on Windows.

Currently the core roots/trunks for Phobos v3 are `core`, `etc`, and `phobos.sys`. As a rule, the `phobos.sys` trunk is not allowed to import from non-core trunks.

[Proposed Package Structure for Phobos 3](PackageMap.md)

### Strings

#### No Autodecoding

Autodecoding turned out to be a mistake because it is pervasive and impractical to disable. The user will need to specifically ask for decoding using a filter such as `utf.byDchar`.

#### No Support For wchar And dchar

Since v2 was designed, the programming world has more or less standardized on UTF-8. The internals of algorithms, ranges, and functions will only work with UTF-8. Support for `wchar` and `dchar` will come in the form of algorithms `utf.byChar`, `utf.byWchar` and `utf.byDchar`.

#### Invalid Unicode

v2 throws an Exception when encountering invalid Unicode. Throwing an Exception entails using the GC, meaning string code cannot be `@nogc` nor `nothrow`. Besides, common processing of strings means being tolerant of invalid Unicode rather than failing. For example, invalid Unicode is commonplace in web pages, and throwing an Exception when rendering such pages is unacceptable.

Removal of autodecoding will in itself address most of the problem. When decoding code units into code points is needed, APIs should allow callers to specify the desired behavior, such as returning an "error" result, or replacing invalid sequences with the Unicode substitution character. Applications which need to handle untrusted data should be encouraged to use functions such as `std.utf.validate` (which return a `string` from `ubyte[]` only when it is valid UTF-8), or by-code-point decoding which reports errors for individual decoding operations.

### Memory Management

#### Minimize Memory Allocation

Enormous troubles and inefficiencies stem from general purpose library code allocating memory as the library sees fit. This makes the library code far less usable. Memory allocation strategies should be decided upon by the user of the library, not the library.

The easiest way to achieve this is to design the library to not use memory allocation at all. For example, std.path assembles paths from parts without doing allocations - it returns Voldemort ranges that the user can then use to emit the result into a buffer of the user's choosing.

Library routines may allocate memory internally, but not in a way that affects the user.

#### Minimize Exceptions

Exceptions are inefficient, use the GC, and they cannot be used in `nothrow` code. Examine each use of an Exception to see if it can be designed out of existence, like the Replacement Character method above. Design the return value such that an error is not necessary - for example, a string search function can return an empty string if not found rather than throw an Exception.

Investigate the use of Option/Sum types for error returns.

#### Split-Level Design

To achieve the twin goals of minimizing allocations and exceptions we will pursue a "split-level" design. The low-level function will take in a buffer instead of allocating and will return an error code instead of throwing exceptions. Then the high-level function can then call the low-level function with the appropriate buffers and can convert the error codes into exceptions. This allows us to maintain the simplicity of the high-level API while offering a low-level API those who need the additional performance.

### Additional Goals

#### Reduce Template Layering

Phobos 2 frequently over-uses templates resulting in situations such as `std.conv.to`, which has over 10 layers of templates before the actual implementation is reached. This makes the code virtually impossible to comprehend and significantly increases compile times. Templates in Phobos 2 were often used as a way to add in new functionality without breaking existing code or as premature optimizations, this led to haphazard and frequently unnecessary layering of templates. When porting code from Phobos 2 into Phobos 3, care should be taken to audit the usage of template and determine where reductions can be made.

#### Source Only

Currently, Phobos is distributed as a separately compiled library with "header" files that contain only the necessary Template implementations. The net result is that Phobos is primarily a source-only library in practice. By formalizing the library as a source only library, it becomes inured against variations in compiler flags. Whether it's a static or dynamic library becomes irrelevant, and there won't be impedance mismatches. DRuntime will remain a separately compiled library.

#### Single Script Builds

The current Phobos build process is convoluted and relies on old or niche tools. This makes the process of building Phobos tedious and discourages active community participation. Phobos 3 will use a single build script written in D. For example, running unittests would be accomplished with the command: `dmd -run build_v3.d unittests`.

### Versioning and Release Schedule

Phobos3 versions will be versioned and distributed on the same schedule as the corresponding Compiler Edition. This allows Phobos to adopt the latest features from the in-development edition during the development of that edition. However, while Phobos will follow the same release schedule as the compiler editions, Phobos itself will not use the 'edition' terminology and will instead retain the use of the term 'version'.

Phobos will use a slightly modified SemVer. The major version will increment with each Phobos release that is tied to a compiler edition, the minor version will increment with the monthly compiler releases, and the patch version will be incremented on any out-of-band bugfix releases that occur.

## Specific Issues

### std.stdio

This module merges file I/O with formatting. Those should be split apart. File I/O should be done with ranges, and the formatting should work with any ranges. `stdin`, `stdout`, and `stderr` match the `stdin`, `stdout` and `stderr` of `core.stdc.stdio`. This causes terrible confusion and will be renamed to `stdIn`, `stdOut`, and `stdErr`.

#### std.stdio.File

Does way, way too much. It's incomprehensible. Should be redesigned using building blocks.

### isXXXX templates

Are generally very hard to figure out what they do, such as `isSomeChar`. What the heck does that mean? The string ones are even worse.
