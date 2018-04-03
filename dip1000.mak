# Module-specific compiler switches (needed for the -dip1000 transition)
# This file can be removed once the -dip1000 transition is complete
#etc/
aa[etc.c.curl]=-dip1000
aa[etc.c.sqlite3]=-dip1000
aa[etc.c.zlib]=-dip1000

aa[etc.c.odbc.sql]=-dip1000
aa[etc.c.odbc.sqlext]=-dip1000
aa[etc.c.odbc.sqltypes]=-dip1000
aa[etc.c.odbc.sqlucode]=-dip1000

#std/
aa[std.array]=-dip1000
aa[std.ascii]=-dip1000
aa[std.base64]=-dip1000
aa[std.bigint]=-dip1000
aa[std.bitmanip]=-dip1000 # merged https://github.com/dlang/phobos/pull/6174
aa[std.compiler]=-dip1000
aa[std.complex]=-dip1000
aa[std.concurrency]=-dip1000
aa[std.conv]=-dip1000
aa[std.csv]=-dip1000
aa[std.demangle]=-dip1000
aa[std.encoding]=-dip1000
aa[std.exception]=-dip1000 # merged https://github.com/dlang/phobos/pull/6323; a workaround for https://issues.dlang.org/show_bug.cgi?id=18637
aa[std.file]=-dip25 # probably already fixed (std.uni); currently: undefined symbol  pure nothrow @nogc return @safe std.uni.SliceOverIndexed!(std.uni.Grapheme).SliceOverIndexed std.uni.SliceOverIndexed!(std.uni.Grapheme).SliceOverIndexed.opSlice()
aa[std.format]=-dip25 # @system function std.range.primitives.put
aa[std.functional]=-dip1000 # merged https://github.com/dlang/phobos/pull/6351
aa[std.getopt]=-dip1000
aa[std.json]=-dip1000
aa[std.math]=-dip1000
aa[std.mathspecial]=-dip1000
aa[std.meta]=-dip1000
aa[std.mmfile]=-dip1000
aa[std.numeric]=-dip1000
aa[std.outbuffer]=-dip25 # DROP: cannot call @system function std.outbuffer.OutBuffer.writef!(char, int).writef
aa[std.parallelism]=-dip1000
aa[std.path]=-dip25 #    TODO
aa[std.process]=-dip1000
aa[std.random]=-dip1000
aa[std.signals]=-dip1000
aa[std.socket]=-dip1000
aa[std.stdint]=-dip1000
aa[std.stdio]=-dip25 #    TODO
aa[std.string]=-dip1000
aa[std.system]=-dip1000
aa[std.traits]=-dip1000
aa[std.typecons]=-dip1000 -version=DIP1000 # merged https://github.com/dlang/phobos/pull/6338; COMPROMISE: check the reason for non-dip1000: static struct S. mixin Proxy!foo;
aa[std.typetuple]=-dip1000
aa[std.uni]=-dip1000 # merged https://github.com/dlang/phobos/pull/6294, https://github.com/dlang/phobos/pull/6041 (see also TODO-list there); supersedes/includes https://github.com/dlang/phobos/pull/5045; see also https://github.com/dlang/phobos/pull/6104 for improvements proposed by Seb
aa[std.uri]=-dip1000
aa[std.utf]=-dip1000 # for me (carblue) std.utf is -dip1000 compilable even without applying https://github.com/dlang/phobos/pull/5915, i.e. I don't observe a depends on (?); after applying PR 5915 it's still dip1000
aa[std.uuid]=-dip1000
aa[std.variant]=-dip1000
aa[std.xml]=-dip1000
aa[std.zip]=-dip1000
aa[std.zlib]=-dip1000

aa[std.algorithm.comparison]=-dip1000
aa[std.algorithm.internal]=-dip1000
aa[std.algorithm.iteration]=-dip25 # depends on std.container.slist (to be updated https://github.com/dlang/phobos/pull/6295)
aa[std.algorithm.mutation]=-dip25 #  depends on std.container.slist (to be updated https://github.com/dlang/phobos/pull/6295)
aa[std.algorithm.package]=-dip1000
aa[std.algorithm.searching]=-dip25 # depends on https://github.com/dlang/phobos/pull/6246 merged and std.algorithm.comparison fixed
aa[std.algorithm.setops]=-dip1000
aa[std.algorithm.sorting]=-dip25 # i.a. depends on std.algorithm.searching? and a fix for writefln

aa[std.c.fenv]=-dip1000
aa[std.c.locale]=-dip1000
aa[std.c.math]=-dip1000
aa[std.c.process]=-dip1000
aa[std.c.stdarg]=-dip1000
aa[std.c.stddef]=-dip1000
aa[std.c.stdio]=-dip1000
aa[std.c.stdlib]=-dip1000
aa[std.c.string]=-dip1000
aa[std.c.time]=-dip1000
aa[std.c.wcharh]=-dip1000
aa[std.c.freebsd.socket]=-dip1000
aa[std.c.linux.linux]=-dip1000
aa[std.c.linux.linuxextern]=-dip1000
aa[std.c.linux.pthread]=-dip1000
aa[std.c.linux.socket]=-dip1000
aa[std.c.linux.termios]=-dip1000
aa[std.c.linux.tipc]=-dip1000
aa[std.c.osx.socket]=-dip1000
aa[std.c.windows.com]=-dip1000
aa[std.c.windows.stat]=-dip1000
aa[std.c.windows.windows]=-dip1000
aa[std.c.windows.winsock]=-dip1000

aa[std.container.array]=-dip1000
aa[std.container.binaryheap]=-dip1000
aa[std.container.dlist]=-dip1000
aa[std.container.package]=-dip1000
aa[std.container.rbtree]=-dip25 # DROP
aa[std.container.slist]=-dip25 # -dip1000 -version=DIP1000   depends on an update (no insertFront's code duplication in constructor) and merge of https://github.com/dlang/phobos/pull/6295
aa[std.container.util]=-dip25 # depends on rbtree and slist = -dip1000

aa[std.datetime.date]=-dip1000
aa[std.datetime.interval]=-dip1000
aa[std.datetime.package]=-dip1000
aa[std.datetime.stopwatch]=-dip1000
aa[std.datetime.systime]=-dip1000 # merged https://github.com/dlang/phobos/pull/6181
aa[std.datetime.timezone]=-dip1000 # merged https://github.com/dlang/phobos/pull/6183

aa[std.digest.crc]=-dip1000
aa[std.digest.digest]=-dip1000
aa[std.digest.hmac]=-dip1000
aa[std.digest.md]=-dip1000
aa[std.digest.murmurhash]=-dip1000
aa[std.digest.package]=-dip1000
aa[std.digest.ripemd]=-dip1000
aa[std.digest.sha]=-dip1000

aa[std.experimental.all]=-dip1000
aa[std.experimental.checkedint]=-dip1000
aa[std.experimental.typecons]=-dip1000
aa[std.experimental.allocator.common]=-dip1000
aa[std.experimental.allocator.gc_allocator]=-dip1000
aa[std.experimental.allocator.mallocator]=-dip1000
aa[std.experimental.allocator.mmap_allocator]=-dip1000
aa[std.experimental.allocator.package]=-dip25 #    Linker errors
aa[std.experimental.allocator.showcase]=-dip1000
aa[std.experimental.allocator.typed]=-dip1000
aa[std.experimental.allocator.building_blocks.affix_allocator]=-dip25 #    Linker errors
aa[std.experimental.allocator.building_blocks.allocator_list]=-dip1000
aa[std.experimental.allocator.building_blocks.ascending_page_allocator]=-dip1000
aa[std.experimental.allocator.building_blocks.bitmapped_block]=-dip25 #    Linker error
aa[std.experimental.allocator.building_blocks.bucketizer]=-dip25 #    Linker errors
aa[std.experimental.allocator.building_blocks.fallback_allocator]=-dip25 #    Linker errors
aa[std.experimental.allocator.building_blocks.free_list]=-dip1000
aa[std.experimental.allocator.building_blocks.free_tree]=-dip1000
aa[std.experimental.allocator.building_blocks.kernighan_ritchie]=-dip1000
aa[std.experimental.allocator.building_blocks.null_allocator]=-dip1000
aa[std.experimental.allocator.building_blocks.package]=-dip1000
aa[std.experimental.allocator.building_blocks.quantizer]=-dip1000
aa[std.experimental.allocator.building_blocks.region]=-dip25 #    Linker errors
aa[std.experimental.allocator.building_blocks.scoped_allocator]=-dip1000
aa[std.experimental.allocator.building_blocks.segregator]=-dip25 #    Linker errors
aa[std.experimental.allocator.building_blocks.stats_collector]=-dip1000
aa[std.experimental.logger.core]=-dip1000 # merged https://github.com/dlang/phobos/pull/6266
aa[std.experimental.logger.filelogger]=-dip25 # merged https://github.com/dlang/phobos/pull/6266; depends on https://github.com/dlang/phobos/pull/5915 ? and a fix for: std.format.formattedWrite
aa[std.experimental.logger.multilogger]=-dip1000
aa[std.experimental.logger.nulllogger]=-dip1000
aa[std.experimental.logger.package]=-dip1000

aa[std.internal.cstring]=-dip1000
aa[std.internal.scopebuffer]=-dip1000
aa[std.internal.unicode_comp]=-dip1000
aa[std.internal.unicode_decomp]=-dip1000
aa[std.internal.unicode_grapheme]=-dip1000
aa[std.internal.unicode_norm]=-dip1000
aa[std.internal.unicode_tables]=-dip1000
aa[std.internal.digest.sha_SSSE3]=-dip1000
aa[std.internal.math.biguintcore]=-dip1000
aa[std.internal.math.biguintnoasm]=-dip1000
aa[std.internal.math.biguintx86]=-dip1000
aa[std.internal.math.errorfunction]=-dip1000
aa[std.internal.math.gammafunction]=-dip1000
aa[std.internal.test.dummyrange]=-dip1000
aa[std.internal.test.range]=-dip1000
aa[std.internal.test.uda]=-dip1000
aa[std.internal.windows.advapi32]=-dip1000

aa[std.net.curl]=-dip1000 # TODO have a look into open https://github.com/dlang/phobos/pull/5052: std.net.curl: fix for -dip1000
aa[std.net.isemail]=-dip1000

aa[std.range.interfaces]=-dip1000
aa[std.range.package]=-dip25 # reference to local variable a / b assigned to non-scope parameter _param_1 / _param_2 calling std.range.chooseAmong!(RefAccessRange, RefAccessRange).chooseAmong
aa[std.range.primitives]=-dip1000

aa[std.regex.package]=-dip1000
aa[std.regex.internal.backtracking]=-dip1000
aa[std.regex.internal.generator]=-dip1000
aa[std.regex.internal.ir]=-dip1000
aa[std.regex.internal.kickstart]=-dip1000
aa[std.regex.internal.parser]=-dip1000
aa[std.regex.internal.tests2]=-dip1000
aa[std.regex.internal.tests]=-dip1000 # merged https://github.com/dlang/phobos/pull/6340; for -debug=std_regex_test (set nowhere in sources) still depends on a fix for writeln
aa[std.regex.internal.thompson]=-dip1000

aa[std.windows.charset]=-dip1000
aa[std.windows.registry]=-dip1000
aa[std.windows.syserror]=-dip1000
