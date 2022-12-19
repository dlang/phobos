//Written in the D programming language
/**
    gen_uni is a tool to automatically generate source code for unicode data structures.

    To generate the tables use:
    ```
    $ rdmd -m32 unicode_table_generator.d
    $ rdmd -m64 unicode_table_generator.d --min
    ```

    See the global ``UnicodeDatabaseDirectory`` for the latest version of the Unicode database that was used to generate the tables.

    TODO: Support emitting of Turkic casefolding mappings

    Authors: Dmitry Olshansky

    License: Boost
*/
module std.unicode_table_generator;
// this shouldn't be in std package, but stuff is package'd as that in std.uni.

import std.uni, std.stdio, std.traits, std.typetuple,
     std.exception, std.format, std.algorithm, std.typecons,
     std.regex, std.range, std.conv, std.getopt;

import std.file : exists;
static import std.ascii, std.string;

//common binary property sets and their aliases
struct PropertyTable
{
    CodepointSet[string] table;
    string[string] aliases;
}

PropertyTable general;
PropertyTable blocks;
PropertyTable scripts;
PropertyTable hangul;

//quick NO/MAYBE charaсter sets
CodepointSet[string] normalization;

//axuilary sets for case mapping
CodepointSet lowerCaseSet, upperCaseSet;
//CodepointSet titleCaseSet; //no sensible version found for isTitlecase

// sets for toLower/toUpper/toTitle
uint[] toLowerTab;
ushort toLowerTabSimpleLen; //start of long mappings
ushort[dchar] toLowerSimpleIndex, toLowerIndex;
uint[] toUpperTab;
ushort toUpperTabSimpleLen; //ditto for Upper
ushort[dchar] toUpperSimpleIndex, toUpperIndex;
uint[] toTitleTab;
ushort toTitleTabSimpleLen; //ditto for Title
ushort[dchar] toTitleSimpleIndex, toTitleIndex;

mixin(mixedCCEntry);

//case folding mapping
SimpleCaseEntry[] simpleTable;
FullCaseEntry[] fullTable;

///canonical combining class
CodepointSet[256] combiningClass;
//same but packaged per dchar
ubyte[dchar] combiningMapping;

//unrolled decompositions
dstring[dchar] canonDecomp;
dstring[dchar] compatDecomp;

//canonical composition tables
dchar[] canonicalyComposableLeft;
dchar[] canonicalyComposableRight;


//canonical composition exclusions
CodepointSet compExclusions;

//property names to discard
string[] blacklist = [];

enum mixedCCEntry = `
struct SimpleCaseEntry
{
    uint ch;
    ubyte n, bucket;// n - number in bucket

pure nothrow @nogc:

    @property ubyte size() const
    {
        return bucket & 0x3F;
    }
    @property auto isLower() const
    {
        return bucket & 0x40;
    }
    @property auto isUpper() const
    {
        return bucket & 0x80;
    }
}

struct FullCaseEntry
{
    dchar[3] seq;
    ubyte n, size;// n number in batch, size - size of batch
    ubyte entry_len;

    @property auto value() const @trusted pure nothrow @nogc return
    {
        return seq[0 .. entry_len];
    }
}

struct CompEntry
{
    dchar rhs, composed;
}

struct UnicodeProperty
{
    string name;
    ubyte[] compressed;
}

struct TrieEntry(T...)
{
    size_t[] offsets;
    size_t[] sizes;
    size_t[] data;
}

`;

auto fullCaseEntry(dstring value, ubyte num, ubyte batch_size)
{
    dchar[3] val;
    val[0 .. value.length] = value[];
    return FullCaseEntry(val, num, batch_size, cast(ubyte) value.length);
}

enum {
    UnicodeDatabaseDirectory = "ucd-15/",
    caseFoldingSrc = UnicodeDatabaseDirectory ~ "CaseFolding.txt",
    blocksSrc = UnicodeDatabaseDirectory ~ "Blocks.txt",
    propListSrc = UnicodeDatabaseDirectory ~ "PropList.txt",
    propertyValueAliases = UnicodeDatabaseDirectory ~ "PropertyValueAliases.txt",
    corePropSrc = UnicodeDatabaseDirectory ~ "DerivedCoreProperties.txt",
    normalizationPropSrc = UnicodeDatabaseDirectory ~ "DerivedNormalizationProps.txt",
    scriptsSrc = UnicodeDatabaseDirectory ~ "Scripts.txt",
    hangulSyllableSrc = UnicodeDatabaseDirectory ~ "HangulSyllableType.txt",
    unicodeDataSrc = UnicodeDatabaseDirectory ~ "UnicodeData.txt",
    compositionExclusionsSrc = UnicodeDatabaseDirectory ~ "CompositionExclusions.txt",
    specialCasingSrc = UnicodeDatabaseDirectory ~ "SpecialCasing.txt"
}

enum HeaderComment = `//Written in the D programming language
/**
 * License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).
 *
 * Authors: Dmitry Olshansky
 *
 */
// !!! DO NOT EDIT !!!
// !!! Did you even read the comment? !!!
// This module is automatically generated from Unicode Character Database files
// https://github.com/dlang/phobos/blob/master/tools/unicode_table_generator.d
//dfmt off`;

auto toPairs(K, V)(V[K] aa)
{
    return aa.values.zip(aa.keys).array;
}

void main(string[] argv)
{
    string mode = "w";

    bool minimal = false;
    getopt(argv, "min", &minimal);
    if (minimal)
        mode = "a";


    if (!exists(UnicodeDatabaseDirectory))
    {
        writeln("Did you forget to download the Unicode database tables?");
        writeln("Looking for them in: ", UnicodeDatabaseDirectory);
        return;
    }

    enum UnicodeTableDirectory = "../std/internal/";

    auto baseSink = File(UnicodeTableDirectory ~ "unicode_tables.d", mode);
    auto compSink = File(UnicodeTableDirectory ~ "unicode_comp.d", mode);
    auto decompSink = File(UnicodeTableDirectory ~ "unicode_decomp.d", mode);
    auto normSink = File(UnicodeTableDirectory ~ "unicode_norm.d", mode);
    auto graphSink = File(UnicodeTableDirectory ~ "unicode_grapheme.d", mode);
    if (!minimal)
    {
        baseSink.writeln(HeaderComment);
        baseSink.writeln("module std.internal.unicode_tables;");
        baseSink.writeln("\n@safe pure nothrow @nogc package(std):\n");

        compSink.writeln("module std.internal.unicode_comp;");
        compSink.writeln("import std.internal.unicode_tables;");
        compSink.writeln("\n@safe pure nothrow @nogc package(std):\n");

        decompSink.writeln(HeaderComment);
        decompSink.writeln("module std.internal.unicode_decomp;");
        decompSink.writeln("import std.internal.unicode_tables;");
        decompSink.writeln("\n@safe pure nothrow @nogc package(std):\n");

        normSink.writeln(HeaderComment);
        normSink.writeln("module std.internal.unicode_norm;");
        normSink.writeln("import std.internal.unicode_tables;");
        normSink.writeln("\npackage(std):\n");

        graphSink.writeln(HeaderComment);
        graphSink.writeln("module std.internal.unicode_grapheme;");
        graphSink.writeln("import std.internal.unicode_tables;");
        graphSink.writeln("\npackage(std):\n");
    }

    loadBlocks(blocksSrc, blocks);
    loadProperties(propListSrc, general);
    loadProperties(corePropSrc, general);
    loadProperties(scriptsSrc, scripts);
    loadProperties(hangulSyllableSrc, hangul);
    loadPropertyAliases(propertyValueAliases);

    loadUnicodeData(unicodeDataSrc);
    loadSpecialCasing(specialCasingSrc);
    loadExclusions(compositionExclusionsSrc);
    loadCaseFolding(caseFoldingSrc);
    loadNormalization(normalizationPropSrc);

    static void writeTableOfSets(File sink, string prefix, PropertyTable tab)
    {
        sink.writeln();
        writeAliasTable(sink, prefix, tab);
    }

    if (!minimal)
    {
        writeCaseFolding(baseSink);
        writeTableOfSets(baseSink, "uniProps", general);
        writeTableOfSets(baseSink, "blocks", blocks);
        writeTableOfSets(baseSink, "scripts", scripts);
        writeTableOfSets(baseSink, "hangul", hangul);
        writeFunctions(baseSink);
    }

    static void trieProlog(File file)
    {
        file.writefln("\nstatic if (size_t.sizeof == %d)\n{", size_t.sizeof);
    }

    static void trieEpilog(File file)
    {
        file.writeln("
}\n");
    }

    trieProlog(baseSink);
    trieProlog(compSink);
    trieProlog(decompSink);
    trieProlog(graphSink);
    trieProlog(normSink);

    writeTries(baseSink);
    writeNormalizationTries(normSink);
    writeGraphemeTries(graphSink);
    writeCaseCoversion(baseSink);
    writeCombining(compSink);
    writeDecomposition(decompSink);
    writeCompositionTable(compSink);

    trieEpilog(decompSink);
    trieEpilog(compSink);
    trieEpilog(baseSink);
    trieEpilog(graphSink);
    trieEpilog(normSink);
}

void scanUniData(alias Fn)(string name, Regex!char r)
{
    File f = File(name);
    foreach (line; f.byLine)
    {
        auto m = match(line, r);
        if (!m.empty)
            Fn(m);
    }
}

void loadCaseFolding(string f)
{
    dchar[dchar] simple;
    dstring[dchar] full;

    auto r = regex("([^;]*); ([CFST]);\\s*([^;]*);");
    scanUniData!((m){
            auto s1 = m.captures[1];
            auto code = m.captures[2].front;
            auto s2 = m.captures[3];
            auto left = parse!int(s1, 16);
            if (code == 'C')
            {
                auto right = parse!int(s2, 16);
                simple[left] = right;
                full[left] = [right];
            }
            else if (code == 'S')
            {
                auto right = parse!int(s2, 16);
                simple[left] = right;
            }
            else if (code == 'F')
            {
                dstring right;
                foreach (x; match(s2, regex("[0-9A-Fa-f]+", "g")))
                {
                    right ~= to!int(x[0], 16);
                }
                full[left] = right.idup;
            }
            else if (code == 'T')
            {
                // TODO: ignore Turkic languages for now.
            }
    })(f, r);

    //make some useful sets by hand

    lowerCaseSet = general.table["Lowercase"];
    upperCaseSet = general.table["Uppercase"];
    //titleCaseSet = general.table["Lt"];

    foreach (ch; simple.keys())
    {
        dchar[8] entry;
        int size=0;
        entry[size++] = ch;
        dchar x = simple[ch];
        entry[size++] = x;
        //simple is many:1 mapping
        foreach (key, v; simple)
        {
            if (v == x && !canFind(entry[], key))
            {
                entry[size++] = key;
            }
        }
        sort(entry[0 .. size]);
        foreach (i, value; entry[0 .. size])
        {
            auto withFlags = cast(ubyte) size | (value in lowerCaseSet ? 0x40 : 0)
                 | (value in upperCaseSet ? 0x80 : 0);
            simpleTable ~= SimpleCaseEntry(value, cast(ubyte) i,
                cast(ubyte) withFlags);
        }
    }

    foreach (ch; full.keys())
    {
        dstring[8] entry;
        int size=0;
        entry[size++] = [ch];
        auto x = full[ch];
        entry[size++] = x;

        //full is many:many mapping
        //sort single-char versions, and let them come first
        foreach (key, v; full)
        {
            if (v == x && !canFind(entry[], [key]))
            {
                entry[size++] = [key];
            }

        }
        auto right = partition!(a => a.length == 1)(entry[0 .. size]);
        sort(entry[0 .. size - right.length]);
        foreach (i, value; entry[0 .. size])
        {
            fullTable ~= fullCaseEntry(value, cast(ubyte) i, cast(ubyte) size);
        }
    }
}

void loadBlocks(string f, ref PropertyTable target)
{
    auto r = regex(`^([0-9A-F]+)\.\.([0-9A-F]+);\s*(.*)\s*$`);
    scanUniData!((m){
            auto s1 = m.captures[1];
            auto s2 = m.captures[2];
            auto a1 = parse!uint(s1, 16);
            auto a2 = parse!uint(s2, 16);
            //@@@BUG 6178 memory corruption with
            //target[to!string(m.captures[3])] = CodepointSet(a1, a2+1);
            auto set = CodepointSet(a1, a2+1);
            target.table[to!string(m.captures[3])] = set;
    })(f, r);
}

void loadProperties(string inp, ref PropertyTable target)
{
    auto acceptProp = (string name) => countUntil(blacklist, name) < 0  && !name.startsWith("Changes");
    auto r = regex(`^(?:(?:([0-9A-F]+)\.\.([0-9A-F]+)|([0-9A-F]+))\s*;\s*([a-zA-Z_0-9]*)\s*#|# [a-zA-Z_0-9]+=([a-zA-Z_0-9]+))`);
    string aliasStr;
    auto set = CodepointSet.init;  //workaround @@@BUG 6178
    scanUniData!((m){
        auto name = to!string(m.captures[4]);
        if (!acceptProp(name))
            return;
        if (!m.captures[5].empty)
            aliasStr = to!string(m.captures[5]);
        else if (!m.captures[1].empty)
        {
            auto sa = m.captures[1];
            auto sb = m.captures[2];
            uint a = parse!uint(sa, 16);
            uint b = parse!uint(sb, 16);
            if (name !in target.table)
            {
                target.table[name] = set;
            }
            auto p = name in target.table;
            p.add(a,b+1); // unicode lists [a, b] we need [a,b)
            if (!aliasStr.empty)
            {
                target.aliases[name] = aliasStr;
                aliasStr = "";
            }
        }
        else if (!m.captures[3].empty)
        {
            auto sx = m.captures[3];
            uint x = parse!uint(sx, 16);
            if (name !in target.table)
            {
                target.table[name] = set;
            }
            auto p = name in target.table;
            *p |= x;
            if (!aliasStr.empty)
            {
                target.aliases[name] = aliasStr;
                aliasStr = "";
            }
        }
    })(inp, r);
}

void loadPropertyAliases(string inp)
{
    auto r = regex(`^([\w0-9_]+)\s*;\s*([\w0-9_]+)\s*;\s*([\w0-9_]+)`);
    scanUniData!((m){
        auto type = m.captures[1];
        auto target = m.captures[2].idup;
        auto label = m.captures[3].idup;
        if (target != label)
        {
            if (type == "blk")
                blocks.aliases[target] = label;
            else if (type == "gc")
                general.aliases[target] = label;
            else if (type == "sc")
                scripts.aliases[target] = label;
        }
    })(inp, r);
}

void loadNormalization(string inp)
{
    auto r = regex(`^(?:([0-9A-F]+)\.\.([0-9A-F]+)|([0-9A-F]+))\s*;\s*(NFK?[CD]_QC)\s*;\s*([NM])|#\s*[a-zA-Z_0-9]+=([a-zA-Z_0-9]+)`);
    CodepointSet set; //workaround @@@BUG 6178
    scanUniData!((m){
        auto name = to!string(m.captures[4]) ~ to!string(m.captures[5]);
        if (!m.captures[1].empty)
        {
            auto sa = m.captures[1];
            auto sb = m.captures[2];
            uint a = parse!uint(sa, 16);
            uint b = parse!uint(sb, 16);
            if (name !in normalization)
            {
                normalization[name] = set;
            }
            auto p = name in normalization;
            p.add(a,b+1);
        }
        else if (!m.captures[3].empty)
        {
            auto sx = m.captures[3];
            uint x = parse!uint(sx, 16);
            if (name !in normalization)
            {
                normalization[name] = set;
            }
            auto p = name in normalization;
            *p |= x;
        }
    })(inp, r);
}

void loadUnicodeData(string inp)
{
    auto f = File(inp);

    dchar characterStart;
    bool haveRangeStart, haveRangeEnd;

    CodepointSet all;
    foreach (line; f.byLine)
    {
        auto fields = split(line, ";");
        //codepoint, name, General_Category, Canonical_Combining_Class, Bidi_Class,
        //Decomp_Type&Mapping, upper case mapping, lower case mapping, title case mapping
        auto codepoint = fields[0];
        auto decomp = fields[5];
        auto name = fields[1];

        dchar src = parse!uint(codepoint, 16);

        if (name.endsWith("First>"))
        {
            assert(!haveRangeStart);
            characterStart = src;
            haveRangeStart = true;
            continue;
        }
        else if (name.endsWith("Last>"))
        {
            haveRangeStart = false;
            haveRangeEnd = true;
        }
        else
        {
            assert(!haveRangeStart);
            haveRangeEnd = false;
            characterStart = src;
        }

        auto generalCategory = fields[2];
        auto ccc = parse!uint(fields[3]);
        auto upperCasePart = fields[12];
        auto lowerCasePart = fields[13];
        auto titleCasePart = fields[14];

        void appendCaseTab(ref ushort[dchar] index, ref uint[] chars, char[] casePart)
        {
            if (!casePart.empty)
            {
                // if you have a range, you shouldn't have any casing provided
                assert(!haveRangeEnd);

                uint ch = parse!uint(casePart, 16);
                chars ~= ch;
                assert(chars.length < ushort.max);
                index[src] = cast(ushort)(chars.length-1);
            }
        }

        if (generalCategory !in general.table)
            general.table[generalCategory.idup] = CodepointSet.init;

        all.add(characterStart, src+1);
        combiningClass[ccc].add(characterStart, src+1);
        general.table[generalCategory].add(characterStart, src+1);

        appendCaseTab(toLowerSimpleIndex, toLowerTab, lowerCasePart);
        appendCaseTab(toUpperSimpleIndex, toUpperTab, upperCasePart);
        appendCaseTab(toTitleSimpleIndex, toTitleTab, titleCasePart);

        if (!decomp.empty)
        {
            // none of the ranges in UnicodeData.txt have decompositions provided
            assert(!haveRangeEnd);

            //stderr.writeln(codepoint, " ---> ", decomp);

            dstring dest;
            bool compat = false;
            if (decomp.startsWith(" "))
                decomp = decomp[1..$];
            if (decomp.front == '<')
            {
                decomp = findSplitAfter(decomp, ">")[1];
                compat = true;
            }
            auto vals = split(decomp, " ");
            foreach (v; vals)
            {
                if (!v.empty)
                    dest ~= cast(dchar) parse!uint(v, 16);
            }
            if (!compat)
            {
                assert(dest.length <= 2, "cannonical decomposition has more then 2 codepoints?!");
                canonDecomp[src] = dest;
            }
            compatDecomp[src] = dest;
        }
    }
    // compute Cn as all dchar we have not found in UnicodeData.txt
    general.table["Cn"] = all.inverted;
    general.aliases["Cn"] = "Unassigned";
    auto arr = combiningClass[1 .. 255];
    foreach (i, clazz; arr)//0 is a default for all of 1M+ codepoints
    {
        auto y = clazz.byCodepoint;
        foreach (ch; y)
            combiningMapping[ch] = cast(ubyte)(i+1);
    }
}

void loadSpecialCasing(string f)
{
    {
        toLowerTabSimpleLen = cast(ushort) toLowerTab.length;
        toUpperTabSimpleLen = cast(ushort) toUpperTab.length;
        toTitleTabSimpleLen = cast(ushort) toTitleTab.length;

        // duplicate the simple indexes prior to adding our uncondtional rules also
        toLowerIndex = toLowerSimpleIndex.dup;
        toTitleIndex = toTitleSimpleIndex.dup;
        toUpperIndex = toUpperSimpleIndex.dup;
    }

    auto file = File(f);
    auto r = regex(`([0-9A-F]+(?:\s*[0-9A-F]+)+);`, "g");
    foreach (line; file.byLine)
    {
        if (!line.empty && line[0] == '#')
        {
            if (line.canFind("Conditional Mappings"))
            {
                // TODO: we kinda need the conditional mappings for languages like Turkish
                break;
            }
            else
                continue;
        }

        auto entries = line.match(r);
        if (entries.empty)
            continue;
        auto pieces = array(entries.map!"a[1]");
        dchar ch = parse!uint(pieces[0], 16);
        void processPiece(ref ushort[dchar] index, ref uint[] table, char[] piece)
        {
            uint[] mapped = piece.split
                .map!(x=>parse!uint(x, 16)).array;
            if (mapped.length == 1)
            {
                table ~= mapped[0];
                index[ch] = cast(ushort)(table.length - 1);
            }
            else
            {
                ushort idx = cast(ushort) table.length;
                table ~= mapped;
                table[idx] |= (mapped.length << 24); //upper 8bits - length of sequence
                index[ch] = idx;
            }
        }

        // lower, title, upper
        processPiece(toLowerIndex, toLowerTab, pieces[1]);
        processPiece(toTitleIndex, toTitleTab, pieces[2]);
        processPiece(toUpperIndex, toUpperTab, pieces[3]);
    }
}

auto recursivelyDecompose(dstring[dchar] decompTable)
{
    //apply recursively:
    dstring[dchar] full;
    foreach (k, v; decompTable)
    {
        dstring old, decomp=v;
        do
        {
            old = decomp;
            decomp = "";
            foreach (dchar ch; old)
            {
                if (ch in decompTable)
                    decomp ~= decompTable[ch];
                else
                    decomp ~= ch;
            }
        }
        while (old != decomp);
        full[k] = decomp;
    }
    return full;
}

void loadExclusions(string inp)
{
    auto r = regex(`^([0-9A-F]+)`);
    scanUniData!((m){
        auto piece = m.captures[1];
        uint a = parse!uint(piece, 16);
        compExclusions |= cast(dchar) a;
    })(inp, r);
}

string charsetString(CodepointSet set, string sep=";\n")
{
    auto app = appender!(char[])();
    ubyte[] data = compressIntervals(set.byInterval);
    assert(CodepointSet(decompressIntervals(data)) == set);
    formattedWrite(app, "[%(0x%x, %)];", data);
    return cast(string) app.data;
}

string identName(string s)
{
    auto app = appender!(char[])();
    foreach (c; s)
    {
        if (c == '-' || c == ' ')
            app.put('_');
        else
            app.put(c);
    }
    return cast(string) app.data;
}

string uniformName(string s)
{
    auto app = appender!(char[])();
    foreach (c; s)
    {
        if (c != '-' && c != ' ' && c != '_')
            app.put(std.ascii.toLower(c));
    }
    return cast(string) app.data;
}

void writeSets(File sink, PropertyTable src)
{
    with(sink)
    {
        writeln("private alias _T = ubyte[];");
        foreach (k, v; src.table)
        {
            writef("_T %s = ", identName(k));
            writeln(charsetString(v));
        }
    }
}

void writeAliasTable(File sink, string prefix, PropertyTable src)
{
    with(sink)
    {
        writeln("struct ", prefix);
        writeln("{");
        writeln("private alias _U = immutable(UnicodeProperty);");
        writeln("@property static _U[] tab() pure { return _tab; }");
        writeln("static immutable:");
        writeSets(sink, src);
        writeln("_U[] _tab = [");
    }
    string[] lines;
    string[] namesOnly;
    auto app = appender!(char[])();
    auto keys = src.table.keys;
    foreach (k; keys)
    {
        formattedWrite(app, "_U(\"%s\", %s),\n", k, identName(k));
        lines ~= app.data.idup;
        namesOnly ~= uniformName(k);
        app.shrinkTo(0);
        if (k in src.aliases)
        {
            formattedWrite(app, "_U(\"%s\", %s),\n", src.aliases[k], identName(k));
            lines ~= app.data.idup;
            namesOnly ~= uniformName(src.aliases[k]);
            app.shrinkTo(0);
        }
    }
    static bool ucmp(T)(T a, T b) { return propertyNameLess(a[0], b[0]); }
    sort!ucmp(zip(namesOnly, lines));

    with(sink)
    {
        foreach (i, v; lines)
        {
            write(lines[i]);
        }
        writeln("];");
        writeln("}");
    }
}

void writeCaseFolding(File sink)
{
    with(sink)
    {
        write(mixedCCEntry);

        writeln("@property immutable(SimpleCaseEntry[]) simpleCaseTable()");
        writeln("{");
        writeln("alias SCE = SimpleCaseEntry;");
        writeln("static immutable SCE[] t = [");
        foreach (i, v; simpleTable)
        {
            writef("SCE(0x%04x, %s, 0x%0x),", v.ch,  v.n, v.bucket);
            if (i % 4 == 0) writeln();
        }
        writeln("];");
        writeln("return t;");
        writeln("}");
        static uint maxLen = 0;
        writeln("@property immutable(FullCaseEntry[]) fullCaseTable()  nothrow @nogc @safe pure");
        writeln("{");
        writeln("alias FCE = FullCaseEntry;");
        writeln("static immutable FCE[] t = [");
        foreach (i, v; fullTable)
        {
                maxLen = max(maxLen, v.entry_len);
                if (v.entry_len > 1)
                {
                    assert(v.n >= 1); // meaning that start of bucket is always single char
                }
                writef("FCE(\"%s\", %s, %s, %s),", v.value, v.n, v.size, v.entry_len);
                if (i % 4 == 0) writeln();
        }
        writeln("];");
        writeln("return t;");
        writeln("}");
        stderr.writefln("MAX FCF len = %d", maxLen);
    }
}

void writeTries(File sink)
{
    ushort[dchar] simpleIndices;
    foreach (i, v; array(map!(x => x.ch)(simpleTable)))
        simpleIndices[v] = cast(ushort) i;

    ushort[dchar] fullIndices;
    foreach (i, v; fullTable)
    {
        if (v.entry_len == 1)
            fullIndices[v.seq[0]] = cast(ushort) i;
    }

    //these 2 only for verification of Trie code itself
    auto st = codepointTrie!(ushort, 12, 9)(
        zip(simpleIndices.values, simpleIndices.keys).array, ushort.max);
    auto ft = codepointTrie!(ushort, 12, 9)(
        zip(fullIndices.values, fullIndices.keys).array, ushort.max);

    foreach (k, v; simpleIndices)
    {
        assert(st[k] == simpleIndices[k]);
    }

    foreach (k, v; fullIndices)
    {
        assert(ft[k] == fullIndices[k]);
    }

    writeBest3Level(sink, "lowerCase", lowerCaseSet);
    writeBest3Level(sink, "upperCase", upperCaseSet);
    //writeBest3Level("titleCase", titleCaseSet);
    writeBest3Level(sink, "simpleCase", simpleIndices, ushort.max);
    writeBest3Level(sink, "fullCase", fullIndices, ushort.max);

    //common isXXX properties
    auto props = general.table;
    CodepointSet alpha = props["Alphabetic"]; //it includes some numbers, symbols & marks
    CodepointSet mark = props["Mn"] | props["Me"] | props["Mc"];
    CodepointSet number = props["Nd"] | props["Nl"] | props["No"];
    CodepointSet punctuation = props["Pd"] | props["Ps"] | props["Pe"]
         | props["Pc"] | props["Po"] | props["Pi"] | props["Pf"];
    CodepointSet symbol = props["Sm"] | props["Sc"] | props["Sk"] | props["So"];
    CodepointSet graphical = alpha | mark | number | punctuation | symbol | props["Zs"];
    CodepointSet nonCharacter = props["Cn"];


    writeBest3Level(sink, "alpha", alpha);
    writeBest3Level(sink, "mark", mark);
    writeBest3Level(sink, "number", number);
    writeBest3Level(sink, "punctuation", punctuation);
    writeBest3Level(sink, "symbol", symbol);
    writeBest3Level(sink, "graphical", graphical);
    writeBest4Level(sink, "nonCharacter", nonCharacter);

}

void writeNormalizationTries(File sink)
{
    CodepointSet nfcQC = normalization["NFC_QCN"] | normalization["NFC_QCM"];
    CodepointSet nfdQC = normalization["NFD_QCN"];
    CodepointSet nfkcQC = normalization["NFKC_QCN"] | normalization["NFKC_QCM"];
    CodepointSet nfkdQC = normalization["NFKD_QCN"];
    writeBest3Level(sink, "nfcQC", nfcQC);
    writeBest3Level(sink, "nfdQC", nfdQC);
    writeBest3Level(sink, "nfkcQC", nfkcQC);
    writeBest3Level(sink, "nfkdQC", nfkdQC);
}

void writeGraphemeTries(File sink)
{
    //few specifics for grapheme cluster breaking algorithm
    //
    auto props = general.table;
    writeBest3Level(sink, "hangulLV", hangul.table["LV"]);
    writeBest3Level(sink, "hangulLVT", hangul.table["LVT"]);
    writeBest3Level(sink, "mc", props["Mc"]);
    writeBest3Level(sink, "graphemeExtend", props["Grapheme_Extend"]);
}

void writeCaseCoversion(File sink)
{
    {
        sink.writefln("enum MAX_SIMPLE_LOWER = %d;", toLowerTabSimpleLen);
        sink.writefln("enum MAX_SIMPLE_UPPER = %d;", toUpperTabSimpleLen);
        sink.writefln("enum MAX_SIMPLE_TITLE = %d;", toTitleTabSimpleLen);
    }

    {
        // these are case mappings that also utilize the unconditional SpecialCasing.txt rules
        writeBest3Level(sink, "toUpperIndex", toUpperIndex, ushort.max);
        writeBest3Level(sink, "toLowerIndex", toLowerIndex, ushort.max);
        writeBest3Level(sink, "toTitleIndex", toTitleIndex, ushort.max);
    }

    {
        // these are all case mapping tables that are 1:1 acquired from UnicodeData.txt
        writeBest3Level(sink, "toUpperSimpleIndex", toUpperSimpleIndex, ushort.max);
        writeBest3Level(sink, "toLowerSimpleIndex", toLowerSimpleIndex, ushort.max);
        writeBest3Level(sink, "toTitleSimpleIndex", toTitleSimpleIndex, ushort.max);
    }

    with(sink)
    {
        writeln("@property");
        writeln("{");
        writeln("private alias _IUA = immutable(uint[]);");
        writefln("_IUA toUpperTable() nothrow @nogc @safe pure { static _IUA t = [%( 0x%x, %)]; return t; }", toUpperTab);
        writefln("_IUA toLowerTable() nothrow @nogc @safe pure { static _IUA t = [%( 0x%x, %)]; return t; }", toLowerTab);
        writefln("_IUA toTitleTable() nothrow @nogc @safe pure { static _IUA t = [%( 0x%x, %)]; return t; }", toTitleTab);
        writeln("}");
    }
}

void writeDecomposition(File sink)
{
    auto fullCanon = recursivelyDecompose(canonDecomp);
    auto fullCompat = recursivelyDecompose(compatDecomp);
    dstring decompCanonFlat = "\0"~array(fullCanon.values).sort.uniq.join("\0")~"\0";
    dstring decompCompatFlat = "\0"~array(fullCompat.values).sort.uniq.join("\0")~"\0";
    stderr.writeln("Canon flattened: ", decompCanonFlat.length);
    stderr.writeln("Compat flattened: ", decompCompatFlat.length);

    ushort[dchar] mappingCanon;
    ushort[dchar] mappingCompat;
    //0 serves as doesn't decompose value
    foreach (k, v; fullCanon)
    {
        size_t idx = decompCanonFlat.countUntil(v~"\0");
        enforce(idx != 0);
        enforce(decompCanonFlat[idx .. idx+v.length] == v);
        mappingCanon[k] = cast(ushort) idx;
    }
    foreach (k, v; fullCompat)
    {
        size_t idx = decompCompatFlat.countUntil(v~"\0");
        enforce(idx != 0);
        enforce(decompCompatFlat[idx .. idx+v.length] == v);
        mappingCompat[k] = cast(ushort) idx;
    }
    enforce(decompCanonFlat.length < 2^^16);
    enforce(decompCompatFlat.length < 2^^16);

    //these 2 are just self-test for Trie template code
    auto compatRange = zip(mappingCompat.values, mappingCompat.keys).array;
    auto canonRange = zip(mappingCanon.values, mappingCanon.keys).array;
    auto compatTrie = codepointTrie!(ushort, 12, 9)(compatRange, 0);
    auto canonTrie =  codepointTrie!(ushort, 12, 9)(canonRange, 0);
    import std.string;
    foreach (k, v; fullCompat)
    {
        auto idx = compatTrie[k];
        enforce(idx == mappingCompat[k], "failed on compat");
        size_t len = decompCompatFlat[idx..$].countUntil(0);
        enforce(decompCompatFlat[idx .. idx+len] == v,
            format("failed on compat: '%( 0x0%5x %)' not found", v));
    }
    foreach (k, v; fullCanon)
    {
        auto idx = canonTrie[k];
        enforce(idx == mappingCanon[k], "failed on canon");
        size_t len = decompCanonFlat[idx..$].countUntil(0);
        enforce(decompCanonFlat[idx .. idx+len] == v,
            format("failed on canon: '%( 0x%5x %)' not found", v));
    }

    writeBest3Level(sink, "compatMapping", mappingCompat, cast(ushort) 0);
    writeBest3Level(sink, "canonMapping", mappingCanon, cast(ushort) 0);
    with(sink)
    {
        writeln("@property");
        writeln("{");
        writeln("private alias _IDCA = immutable(dchar[]);");
        writefln("_IDCA decompCanonTable() @safe pure nothrow { static _IDCA t = [%( 0x%x, %)]; return t; }", decompCanonFlat);
        writefln("_IDCA decompCompatTable() @safe pure nothrow { static _IDCA t = [%( 0x%x, %)]; return t; }", decompCompatFlat);
        writeln("}");
    }
}

void writeFunctions(File sink)
{
    auto format = general.table["Cf"];
    auto space = general.table["Zs"];
    auto control = general.table["Cc"];
    auto whitespace = general.table["White_Space"];

    //hangul L, V, T
    auto hangL = hangul.table["L"];
    auto hangV = hangul.table["V"];
    auto hangT = hangul.table["T"];
    with(sink)
    {
        writeln(format.toSourceCode("isFormatGen"));
        writeln(control.toSourceCode("isControlGen"));
        writeln(space.toSourceCode("isSpaceGen"));
        writeln(whitespace.toSourceCode("isWhiteGen"));
        writeln(hangL.toSourceCode("isHangL"));
        writeln(hangV.toSourceCode("isHangV"));
        writeln(hangT.toSourceCode("isHangT"));
    }
}


void writeCompositionTable(File sink)
{
    dchar[dstring] composeTab;
    //construct compositions table
    foreach (dchar k, dstring v; canonDecomp)
    {
        if (v.length != 2)//singleton
            continue;
        if (v[0] in combiningMapping) //non-starter
            continue;
        if (k in combiningMapping) //combines to non-starter
            continue;
        if (compExclusions[k]) // non-derivable exclusions
            continue;
        composeTab[v] = k;
    }

    Tuple!(dchar, dchar, dchar)[] triples;
    foreach (dstring key, dchar val; composeTab)
        triples ~= Tuple!(dchar, dchar, dchar)(key[0], key[1], val);
    multiSort!("a[0] < b[0]", "a[1] < b[1]")(triples);
    //map to the triplets array
    ushort[dchar] trimap;
    dchar old = triples[0][0];
    auto r = triples[];
    for (size_t idx = 0;;)
    {
        ptrdiff_t cnt = countUntil!(x => x[0] != old)(r);
        if (cnt == -1)//end of input
            cnt = r.length;
        assert(idx < 2048);
        assert(cnt < 32);
        trimap[old] = to!ushort(idx | (cnt << 11));
        idx += cnt;
        if (idx == triples.length)
            break;
        old = r[cnt][0];
        r = r[cnt..$];
    }

    auto triT = codepointTrie!(ushort, 12, 9)(trimap.toPairs, ushort.max);
    auto dupletes = triples.map!(x => tuple(x[1], x[2])).array;
    foreach (dstring key, dchar val; composeTab)
    {
        size_t pack = triT[key[0]];
        assert(pack != ushort.max);
        size_t idx = pack & ((1 << 11) - 1), cnt = pack >> 11;
        auto f = dupletes[idx .. idx+cnt].find!(x => x[0] == key[1]);
        assert(!f.empty);
        // & starts with the right value
        assert(f.front[1] == val);
    }
    with(sink)
    {
        writeln("enum composeIdxMask = (1 << 11) - 1, composeCntShift = 11;");
        write("enum compositionJumpTrieEntries = TrieEntry!(ushort, 12, 9)(");
        triT.store(sink.lockingTextWriter());
        writeln(");");
        writeln("@property immutable(CompEntry[]) compositionTable() nothrow pure @nogc @safe");
        writeln("{");
        writeln("alias CE = CompEntry;");
        write("static immutable CE[] t = [");
        foreach (pair; dupletes)
            writef("CE(0x%05x, 0x%05x),", pair[0], pair[1]);
        writeln("];");
        writeln("return t;");
        writeln("}");
    }
}

void writeCombining(File sink)
{
    auto ct = codepointTrie!(ubyte, 7, 5, 9)(combiningMapping.toPairs);
    foreach (i, clazz; combiningClass[1 .. 255])//0 is a default for all of 1M+ codepoints
    {
        foreach (ch; clazz.byCodepoint)
            assert(ct[ch] == i+1);
    }
    writeBest3Level(sink, "combiningClass", combiningMapping);
}

//fussy compare for unicode property names as per UTS-18
int comparePropertyName(Char)(const(Char)[] a, const(Char)[] b)
{
    for (;;)
    {
        while (!a.empty && (isWhite(a.front) || a.front == '-' || a.front =='_'))
        {
            a.popFront();
        }
        while (!b.empty && (isWhite(b.front) || b.front == '-' || b.front =='_'))
        {
            b.popFront();
        }
        if (a.empty)
            return b.empty ? 0 : -1;
        if (b.empty)
            return 1;
		// names are all in ASCII either way though whitespace might be unicode
        auto ca = std.ascii.toLower(a.front), cb = std.ascii.toLower(b.front);
        if (ca > cb)
            return 1;
        else if ( ca < cb)
            return -1;
        a.popFront();
        b.popFront();
    }
}

bool propertyNameLess(Char)(const(Char)[] a, const(Char)[] b)
{
    return comparePropertyName(a, b) < 0;
}

//meta helpers to generate and pick the best trie by size & levels

void writeBest2Level(Set)(File sink, string name, Set set)
    if (isCodepointSet!Set)
{
    alias List = TypeTuple!(5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
    size_t min = size_t.max;
    void delegate(File) write;
    foreach (lvl_1; List)
    {
        enum lvl_2 = 21-lvl_1;
        auto t = codepointSetTrie!(lvl_1, lvl_2)(set);
        if (t.bytes < min)
        {
            min = t.bytes;
            write = createPrinter!(lvl_1, lvl_2)(name, t);
        }
    }
    write(sink);
}

void writeBest2Level(V, K)(File sink, string name, V[K] map, V defValue=V.init)
{
    alias List = TypeTuple!(5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
    size_t min = size_t.max;
    void delegate(File) write;
    auto range = zip(map.values, map.keys).array;
    foreach (lvl_1; List)
    {
        enum lvl_2 = 21-lvl_1;
        alias codepointTrie!(V, lvl_1, lvl_2) CurTrie;
        CurTrie t = CurTrie(range, defValue);
        if (t.bytes < min)
        {
            min = t.bytes;
            write = createPrinter!(lvl_1, lvl_2)(name, t);
        }
    }
    write(sink);
}

alias List_1 = TypeTuple!(4, 5, 6, 7, 8);

auto writeBest3Level(Set)(File sink, string name, Set set)
    if (isCodepointSet!Set)
{
    // access speed trumps size, power of 2 is faster to access
    // e.g. 9, 5, 7 is far slower then 8, 5, 8 because of how bits breakdown:
    // 8-5-8: indexes are 21-8 = 13 bits, 13-5 = 8 bits, fits into a byte
    // 9-5-7: indexes are 21-7 = 14 bits, 14-5 = 9 bits, doesn't fit into a byte (!)

    // e.g. 8-5-8 is one of hand picked that is a very close match
    // to the best packing
    void delegate(File) write;

    alias List = TypeTuple!(4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
    size_t min = size_t.max;
    foreach (lvl_1; List_1)//to have the first stage index fit in byte
    {
        foreach (lvl_2; List)
        {
            static if (lvl_1 + lvl_2  <= 16)//so that 2nd stage fits in ushort
            {
                enum lvl_3 = 21-lvl_2-lvl_1;
                auto t = codepointSetTrie!(lvl_1, lvl_2, lvl_3)(set);
                if (t.bytes < min)
                {
                    min = t.bytes;
                    write = createPrinter!(lvl_1, lvl_2, lvl_3)(name, t);
                }
            }
        }
    }
    write(sink);
}

void writeBest3Level(V, K)(File sink, string name, V[K] map, V defValue=V.init)
{
    void delegate(File) write;
    alias List = TypeTuple!(4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
    size_t min = size_t.max;
    auto range = zip(map.values, map.keys).array;
    foreach (lvl_1; List_1)//to have the first stage index fit in byte
    {
        foreach (lvl_2; List)
        {
            static if (lvl_1 + lvl_2  <= 16)// into ushort
            {
                enum lvl_3 = 21-lvl_2-lvl_1;
                auto t = codepointTrie!(V, lvl_1, lvl_2, lvl_3) (range, defValue);
                if (t.bytes < min)
                {
                    min = t.bytes;
                    write = createPrinter!(lvl_1, lvl_2, lvl_3)(name, t);
                }
            }
        }
    }
    write(sink);
}

void writeBest4Level(Set)(File sink, string name, Set set)
{
    alias List = TypeTuple!(4, 5, 6, 7, 8, 9, 10, 11, 12, 13);
    size_t min = size_t.max;
    void delegate(File) write;
    foreach (lvl_1; List_1)//to have the first stage index fit in byte
    {
        foreach (lvl_2; List)
        {
            foreach (lvl_3; List)
            {
                static if (lvl_1 + lvl_2 + lvl_3  <= 16)
                {
                    enum lvl_4 = 21-lvl_3-lvl_2-lvl_1;
                    auto t = codepointSetTrie!(lvl_1, lvl_2, lvl_3, lvl_4)(set);
                    if (t.bytes < min)
                    {
                        min = t.bytes;
                        write = createPrinter!(lvl_1, lvl_2, lvl_3, lvl_4)(name, t);
                    }
                }
            }
        }
    }
    write(sink);
}

template createPrinter(Params...)
{
    void delegate(File) createPrinter(T)(string name, T trie)
    {
        return (File sink){
            sink.writef("//%d bytes\nenum %sTrieEntries = TrieEntry!(%s",
                trie.bytes, name, Unqual!(typeof(T.init[0])).stringof);
            foreach (lvl; Params[0..$])
                sink.writef(", %d", lvl);
            sink.write(")(");
            trie.store(sink.lockingTextWriter());
            sink.writeln(");");
        };
    }
}
