// This Makefile snippet detects the OS and the architecture MODEL
// Keep this file in sync between druntime, phobos, and dmd repositories!

import reggae;
import std.process;
import std.string;
import std.algorithm;
import std.array;
import std.path;
import std.range;


string OS, uname_S, uname_M, MODEL, MODEL_FLAG;

static this() {
    if(userVars.get("OS", "") == "") {
        auto uname_S = executeShell("uname -s").output.chomp;
        switch(uname_S) {
        case "Darwin":
            OS = "osx"; break;
        case "Linux":
            OS = "linux"; break;
        case "FreeBSD":
            OS = "freebsd"; break;
        case "OpenBSD":
            OS = "openbsd"; break;
        case "Solaris":
            OS = "solaris"; break;
        case "SunOS":
            OS = "solaris"; break;
        default:
            throw new Exception("Unrecognized or unsupported OS for uname: " ~ uname_S);
        }
    }

    if(userVars.get("OS", "") == "MACOS") {
        // When running make from XCode it may set environment var OS=MACOS.
        // Adjust it here:
        OS = "osx";
    }

    if(userVars.get("MODEL", "") == "") {
        if(OS == "solaris")
            uname_M = executeShell("isainfo -n").output.chomp;
        else
            uname_M = executeShell("uname -m").output.chomp;

        if(["x86_64", "amd64"].canFind(uname_M))
            MODEL = "64";

        if(["i386", "i586", "i686"].canFind(uname_M))
            MODEL = "32";

        if(MODEL == "")
            throw new Exception("Cannot figure 32/64 model from uname -m: " ~ uname_M);
    }

    MODEL_FLAG = "-m" ~ MODEL;
}



import reggae;
//import osmodel;
import std.algorithm;


Build _getBuild() {
    enum QUIET = userVars.get("QUIET", false);

    // Default to a release built, override with BUILD=debug
    static if("BUILD" in userVars) {
        enum BUILD = userVars["BUILD"];
    } else {
        enum BUILD = "release";
        enum BUILD_WAS_SPECIFIED = true;
    }

    enum PIC = "PIC" in userVars ? "-fPIC" : "";
    enum INSTALL_DIR = userVars.get("INSTALL_DIR", "../install");
    enum DRUNTIME_PATH = userVars.get("DRUNTIME_PATH", "../druntime");
    enum ZIPFILE = userVars.get("ZIPFILE", "phobos.zip");
    enum ROOT_OF_THEM_ALL = userVars.get("ROOT_OF_THEM_ALL", "generated");
    auto ROOT = userVars.get("ROOT", ROOT_OF_THEM_ALL ~ "/" ~ OS ~ "/" ~ BUILD ~ "/" ~ MODEL);
    // Documentation-related stuff
    enum DOCSRC = userVars.get("DOCSRC", "../dlang.org");
    enum WEBSITE_DIR = userVars.get("WEBSITE_DIR", "../web");
    enum DOC_OUTPUT_DIR = userVars.get("DOC_OUTPUT_DIR", WEBSITE_DIR ~ "/phobos-prerelease");
    enum BIGDOC_OUTPUT_DIR = userVars.get("BIGDOC_OUTPUT_DIR", "/tmp");
    string[] STD_MODULES, EXTRA_DOCUMENTABLES;
    auto SRC_DOCUMENTABLES = userVars.get("SRC_DOCUMENTABLES",
                                          ["index.d"] ~ STD_MODULES.map!(a => a ~ ".d").array ~ EXTRA_DOCUMENTABLES);
    enum STDDOC = ["html.ddoc", "dlang.org.ddoc", "std_navbar-prerelease.ddoc",
                   "std.ddoc", "macros.ddoc", ".generated/modlist-prerelease.ddoc"].
        map!(a => DOCSRC ~ "/" ~ a).array;
    enum BIGSTDDOC = ["std_consolidated.ddoc", "macros.ddoc"].map!(a => DOCSRC ~ "/" ~ a).array;
    string DMD, DMDEXTRAFLAGS;
    auto DDOC = DMD ~ " -conf= " ~ MODEL_FLAG ~ " -w -c -o- -version=StdDdoc -I" ~
        DRUNTIME_PATH ~ "/import " ~ DMDEXTRAFLAGS;

    string DRUNTIME, DRUNTIMESO;
    static if(userVars.get("DRUNTIME", "") != "") {
        enum CUSTOM_RUNTIME = true;
    }

    version(Windows)
        DRUNTIME = DRUNTIME_PATH ~ "/lib/druntime.lib";
    else {
        DRUNTIME = DRUNTIME_PATH ~ "/generated/" ~ OS ~ "/" ~ BUILD ~ "/" ~ MODEL ~ "/libdruntime.a";
        DRUNTIMESO = stripExtension(DRUNTIME ~ ".so.a");
    }

    string CC, RUN;
    if(OS == "win32wine") {
        CC = "wine dmc.exe";
        DMD = "wine dmd.exe";
        RUN = "wine";
    } else {
        DMD = "../dmd/src/dmd";
        if(OS == "win32") {
            CC = "dmc";
        } else {
            CC = "cc";
        }
    }

    auto CFLAGS = MODEL_FLAG ~ " -fPIC -DHAVE_UNISTD_H";
    CFLAGS ~= BUILD == "debug" ? " -g" : " -O3";

    auto DFLAGS = "-conf= -I" ~ DRUNTIME_PATH ~ "/import " ~ DMDEXTRAFLAGS ~ " -w -dip25 " ~ MODEL_FLAG ~ " " ~ PIC;
    DFLAGS ~= BUILD == "debug" ? " -g -debug" : " -O -release";

    version(Windows) {
        auto DOTOBJ = ".obj";
        auto DOTEXE = ".exe";
        auto PATHSEP = `\`;
    } else {
        auto DOTOBJ = ".o";
        auto PATHSEP = "/";
    }

    version(Linux)
        auto LINKDL = "-L-ldl";
    else
        auto LINKDL = "";

    auto TIMELIMIT = executeShell("which timelimit 2>/dev/null || true").output.chomp != "" ? "timelimit -t 60" : "";

    enum VERSION = "../dmd/VERSION";

    // Set LIB, the ultimate target
    version(Windows) {
        auto LIB = ROOT ~ "/phobos.lib";
    } else {
        auto LIB = ROOT ~ "/libphobos2.a";
        // 2.064.2 => libphobos2.so.0.64.2
        // 2.065 => libphobos2.so.0.65.0
        // MAJOR version is 0 for now, which means the ABI is still unstable
        enum MAJOR = "0";
        auto MINOR = executeShell("awk -F. '{ print int($2) }' " ~ VERSION).output.chomp;
        auto PATCH = executeShell("awk -F. '{ print int($3) }' " ~ VERSION).output.chomp;
        // SONAME doesn't use patch level (ABI compatible)
        auto SONAME = "libphobos2.so." ~ MAJOR ~ "." ~ MINOR;
        auto LIBSO = ROOT ~ "/" ~ SONAME ~ "." ~ PATCH;
    }

    auto MAIN = ROOT ~ "/emptymain.d";

    // unused
    // string[] P2LIB(string package_) {
    //     return package_.replace("/", "_").split.map!(a => a ~ DOTLIB).map!(a => ROOT ~ "/libphobos2_a" ~ a).array;
    // }

    string[] P2MODULES(string[] packages)() {
        import std.meta;

        string[] ret;
        foreach(p; aliasSeqOf!packages) {
            mixin(`ret ~= PACKAGE_` ~ p.replace("/", "_") ~ `.map!(a => "` ~ p ~ `/" ~ a).array;`);
        }
        return ret;
    }

    // Packages in std. Just mention the package name here. The contents of package
    // xy/zz is in variable PACKAGE_xy_zz. This allows automation in iterating
    // packages and their modules.
    enum STD_PACKAGES = ["algorithm", "container", "digest", "experimental/allocator",
                         "experimental/allocator/building_blocks", "experimental/logger",
                         "experimental/ndslice", "net", "experimental", "range", "regex"].
        map!(a => "std/" ~ a).array;

    // Modules broken down per package
    enum PACKAGE_std = ["array", "ascii", "base64", "bigint", "bitmanip",
                        "compiler", "complex", "concurrency"
                        "concurrencybase", "conv", "cstream", "csv",
                        "datetime", "demangle", "encoding", "exception",
                        "file", "format" "functional", "getopt", "json", "math",
                        "mathspecial", "meta", "mmfile", "numeric"
                        "outbuffer", "parallelism", "path", "process",
                        "random", "signals", "socket", "socketstream", "stdint"
                        "stdio", "stdiobase", "stream", "string", "system",
                        "traits", "typecons", "typetuple", "uni"
                        "uri", "utf", "uuid", "variant", "xml", "zip", "zlib"];

    enum PACKAGE_std_experimental = ["typecons"];
    enum PACKAGE_std_algorithm = ["comparison", "iteration", "mutation", "package", "searching", "setops", "sorting"];
    enum PACKAGE_std_container = ["array", "binaryheap", "dlist", "package", "rbtree", "slist", "util"];
    enum PACKAGE_std_digest = ["crc", "digest", "hmac", "md", "ripemd", "sha"];
    enum PACKAGE_std_experimental_logger = ["core", "filelogger", "nulllogger", "multilogger", "package"];
    enum PACKAGE_std_experimental_allocator = ["common", "gc_allocator", "mallocator",
                                               "mmap_allocator", "package", "showcase", "typed"];
    enum PACKAGE_std_experimental_allocator_building_blocks = ["affix_allocator", "allocator_list", "bucketizer",
        "fallback_allocator", "free_list", "free_tree", "bitmapped_block",
        "kernighan_ritchie", "null_allocator", "package", "quantizer",
        "region", "scoped_allocator", "segregator", "stats_collector"];
    enum PACKAGE_std_experimental_ndslice = ["package", "iteration", "selection", "slice"];
    enum PACKAGE_std_net = ["curl", "isemail"];
    enum PACKAGE_std_range = ["interfaces", "package", "primitives"];
    enum PACKAGE_std_regex = ["generator", "ir", "parser", "backtracking", "kickstart", "tests", "thompson"].
        map!(a => "internal/" ~ a).array;

    // Modules in std (including those in packages)
    STD_MODULES = P2MODULES!STD_PACKAGES;

    // OS-specific D modules
    enum EXTRA_MODULES_LINUX = ["linux", "socket"].map!(a => "std/c/linux/" ~ a).array;
    enum EXTRA_MODULES_OSX = ["std/c/osx/socket"];
    enum EXTRA_MODULES_FREEBSD = ["std/c/freebsd/socket"];
    enum EXTRA_MODULES_WIN32 = ["com", "stat", "windows", "winsock"].map!(a => "std/c/windows/" ~ a).array ~
        ["charset", "iunknown", "syserror"].map!(a => "std/windows/" ~ a).array;

    // Other D modules that aren't under std/
    enum EXTRA_MODULES_COMMON = ["curl", "odbc/sql", "odbc/sqlext", "odbc/sqltypes",
                                 "odbc/sqlucode", "sqlite3", "zlib"].map!(a => "etc/c/" ~ a).array ~
        ["fenv", "locale", "math", "process", "stdarg", "stddef",
         "stdio", "stdlib", "string", "time", "wcharh"].map!(a => "std/c/" ~ a).array;

    EXTRA_DOCUMENTABLES = EXTRA_MODULES_LINUX ~ EXTRA_MODULES_WIN32 ~ EXTRA_MODULES_COMMON;

    enum EXTRA_MODULES_INTERNAL = ["std/internal/digest/sha_SSSE3"] ~
        ["biguintcore", "biguintnoasm", "biguintx86", "gammafunction", "errorfunction"].map!(a => "std/internal/math/" ~ a).array ~
        ["cstring", "processinit", "unicode_tables", "scopebuffer", "unicode_comp", "unicode_decomp",
         "unicode_grapheme", "unicode_norm"].map!(a => "std/internal/" ~ a).array ~
        "std/internal/test/dummyrange" ~
        "std/experimental/ndslice/internal" ~
        "std/algorithm/internal";

    auto EXTRA_MODULES = EXTRA_DOCUMENTABLES ~ EXTRA_MODULES_INTERNAL;

    // Aggregate all D modules relevant to this build
    auto D_MODULES = STD_MODULES ~ EXTRA_MODULES;

    // Add the .d suffix to the module names
    auto D_FILES = D_MODULES.map!(a => a ~ ".d").array;
    // Aggregate all D modules over all OSs (this is for the zip file)
    auto ALL_D_FILES = chain(STD_MODULES, EXTRA_MODULES_COMMON, EXTRA_MODULES_LINUX,
                             EXTRA_MODULES_OSX, EXTRA_MODULES_FREEBSD,
                             EXTRA_MODULES_WIN32, EXTRA_MODULES_INTERNAL).map!(a => a ~ ".d").array ~
        ["std/internal/windows/advapi32.d", "std/windows/registry.d", "std/c/linux/pthread.d",
         "std/c/linux/termios.d", "std/c/linux/tipc.d"];

    // C files to be part of the build
    enum C_MODULES = ["adler32", "compress", "crc32", "deflate", "gzclose", "gzlib",
                      "gzread", "gzwrite", "infback", "inffast", "inflate", "inftrees", "trees",
                      "uncompr", "zutil"].map!(a => "etc/c/zlib/" ~ a);

    auto OBJS = C_MODULES.map!(a => ROOT ~ "/" ~ a ~ DOTOBJ).array;

    // build with shared library support (default to true on supported platforms)
    auto SHARED = userVars.get("SHARED", ["linux", "freebsd"].canFind(OS) ? true : false);

    // Rules begin here

    // C objects, a pattern rule in the original makefile
    auto target_OBJS = C_MODULES.
        map!(a => Target(ROOT ~ "/" ~ a ~ DOTOBJ,
                         CC ~ " -c " ~ CFLAGS ~ " $in -o $out",
                         Target(a ~ ".c"))).
        array;

    auto target_LIB = Target("$project/" ~ LIB,
                             DMD ~ " " ~ DFLAGS ~ " -lib -of$out " ~ DRUNTIME ~ " " ~ chain(D_FILES, OBJS).join(" "),
                             target_OBJS ~
                             chain(ALL_D_FILES, [DRUNTIME]).map!(a => Target(a)).array);
    auto target_DLL = Target("$project/" ~ ROOT ~ "/libphobos2.so",
                             "ln -sf " ~ baseName(LIBSO) ~ " $out",
                             Target(ROOT ~ "/" ~ SONAME));

    auto lib = Target.phony("lib", "", [target_LIB]);
    auto dll = Target.phony("dll", "", [target_DLL]);


    return SHARED ? Build(lib, dll) : Build(lib);
}
