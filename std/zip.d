// Written in the D programming language.

/**
Read and write data in the
$(LINK2 https://en.wikipedia.org/wiki/Zip_%28file_format%29, zip archive)
format.

Standards:

The current implementation mostly conforms to
$(LINK2 https://www.iso.org/standard/60101.html, ISO/IEC 21320-1:2015),
which means,
$(UL
$(LI that files can only be stored uncompressed or using the deflate mechanism,)
$(LI that encryption features are not used,)
$(LI that digital signature features are not used,)
$(LI that patched data features are not used, and)
$(LI that archives may not span multiple volumes.)
)

Additionally, archives are checked for malware attacks and rejected if detected.
This includes
$(UL
$(LI $(LINK2 https://news.ycombinator.com/item?id=20352439, zip bombs) which
     generate gigantic amounts of unpacked data)
$(LI zip archives that contain overlapping records)
$(LI chameleon zip archives which generate different unpacked data, depending
     on the implementation of the unpack algorithm)
)

The current implementation makes use of the zlib compression library.

Usage:

There are two main ways of usage: Extracting files from a zip archive
and storing files into a zip archive. These can be mixed though (e.g.
read an archive, remove some files, add others and write the new
archive).

Examples:

Example for reading an existing zip archive:
---
import std.stdio : writeln, writefln;
import std.file : read;
import std.zip;

void main(string[] args)
{
    // read a zip file into memory
    auto zip = new ZipArchive(read(args[1]));

    // iterate over all zip members
    writefln("%-10s  %-8s  Name", "Length", "CRC-32");
    foreach (name, am; zip.directory)
    {
        // print some data about each member
        writefln("%10s  %08x  %s", am.expandedSize, am.crc32, name);
        assert(am.expandedData.length == 0);

        // decompress the archive member
        zip.expand(am);
        assert(am.expandedData.length == am.expandedSize);
    }
}
---

Example for writing files into a zip archive:
---
import std.file : write;
import std.string : representation;
import std.zip;

void main()
{
    // Create an ArchiveMembers for each file.
    ArchiveMember file1 = new ArchiveMember();
    file1.name = "test1.txt";
    file1.expandedData("Test data.\n".dup.representation);
    file1.compressionMethod = CompressionMethod.none; // don't compress

    ArchiveMember file2 = new ArchiveMember();
    file2.name = "test2.txt";
    file2.expandedData("More test data.\n".dup.representation);
    file2.compressionMethod = CompressionMethod.deflate; // compress

    // Create an archive and add the member.
    ZipArchive zip = new ZipArchive();

    // add ArchiveMembers
    zip.addMember(file1);
    zip.addMember(file2);

    // Build the archive
    void[] compressed_data = zip.build();

    // Write to a file
    write("test.zip", compressed_data);
}
---

 * Copyright: Copyright The D Language Foundation 2000 - 2009.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(HTTP digitalmars.com, Walter Bright)
 * Source:    $(PHOBOSSRC std/zip.d)
 */

/*          Copyright The D Language Foundation 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.zip;

import std.exception : enforce;

//debug=print;

/// Thrown on error.
class ZipException : Exception
{
    import std.exception : basicExceptionCtors;
    ///
    mixin basicExceptionCtors;
}

/// Compression method used by `ArchiveMember`.
enum CompressionMethod : ushort
{
    none = 0,   /// No compression, just archiving.
    deflate = 8 /// Deflate algorithm. Use zlib library to compress.
}

/// A single file or directory inside the archive.
final class ArchiveMember
{
    import std.conv : to, octal;
    import std.datetime.systime : DosFileTime, SysTime, SysTimeToDosFileTime;

    /**
     * The name of the archive member; it is used to index the
     * archive directory for the member. Each member must have a
     * unique name. Do not change without removing member from the
     * directory first.
     */
    string name;

    /**
     * The content of the extra data field for this member. See
     * $(LINK2 https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT,
     *         original documentation)
     * for a description of the general format of this data. May contain
     * undocumented 3rd-party data.
     */
    ubyte[] extra;

    string comment; /// Comment associated with this member.

    private ubyte[] _compressedData;
    private ubyte[] _expandedData;
    private ulong offset;
    private uint _crc32;
    private ulong _compressedSize;
    private ulong _expandedSize;
    private CompressionMethod _compressionMethod;
    private ushort _madeVersion = 20;
    private ushort _extractVersion = 20;
    private uint _externalAttributes;
    private DosFileTime _time;
    // by default, no explicit order goes after explicit order
    private ulong _index = ulong.max;

    /**
     * Contains some information on how to extract this archive. See
     * $(LINK2 https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT,
     *         original documentation)
     * for details.
     */
    ushort flags;

    /**
     * Internal attributes. Bit 1 is set, if the member is apparently in binary format
     * and bit 2 is set, if each record is preceded by the length of the record.
     */
    ushort internalAttributes;

    /**
     * The zip file format version needed to extract this member.
     *
     * Returns: Format version needed to extract this member.
     */
    @property @safe pure nothrow @nogc ushort extractVersion() const { return _extractVersion; }

    /**
     * Cyclic redundancy check (CRC) value.
     *
     * Returns: CRC32 value.
     */
    @property @safe pure nothrow @nogc uint crc32() const { return _crc32; }

    /**
     * Size of data of member in compressed form.
     *
     * Returns: Size of the compressed archive.
     */
    @property @safe pure nothrow @nogc ulong compressedSize() const { return _compressedSize; }

    /**
     * Size of data of member in uncompressed form.
     *
     * Returns: Size of uncompressed archive.
     */
    @property @safe pure nothrow @nogc ulong expandedSize() const { return _expandedSize; }

    /**
     * Should be 0.
     *
     * Returns: The number of the disk where this member can be found.
     */
    deprecated("Multidisk not supported; will be removed in 2.099.0")
    @property @safe pure nothrow @nogc ushort diskNumber() const { return 0; }

    /**
     * Data of member in compressed form.
     *
     * Returns: The file data in compressed form.
     */
    @property @safe pure nothrow @nogc ubyte[] compressedData() { return _compressedData; }

    /**
     * Get or set data of member in uncompressed form. When an existing archive is
     * read `ZipArchive.expand` needs to be called before this can be accessed.
     *
     * Params:
     *     ed = Expanded Data.
     *
     * Returns: The file data.
     */
    @property @safe pure nothrow @nogc ubyte[] expandedData() { return _expandedData; }

    /// ditto
    @property @safe void expandedData(ubyte[] ed)
    {
        _expandedData = ed;
        _expandedSize  = to!ulong(_expandedData.length);

        // Clean old compressed data, if any
        _compressedData.length = 0;
        _compressedSize = 0;
    }

    /**
     * Get or set the OS specific file attributes for this archive member.
     *
     * Params:
     *     attr = Attributes as obtained by $(REF getAttributes, std,file) or
     *            $(REF DirEntry.attributes, std,file).
     *
     * Returns: The file attributes or 0 if the file attributes were
     * encoded for an incompatible OS (Windows vs. POSIX).
     */
    @property @safe void fileAttributes(uint attr)
    {
        version (Posix)
        {
            _externalAttributes = (attr & 0xFFFF) << 16;
            _madeVersion &= 0x00FF;
            _madeVersion |= 0x0300; // attributes are in UNIX format
        }
        else version (Windows)
        {
            _externalAttributes = attr;
            _madeVersion &= 0x00FF; // attributes are in MS-DOS and OS/2 format
        }
        else
        {
            static assert(0, "Unimplemented platform");
        }
    }

    version (Posix) @safe unittest
    {
        auto am = new ArchiveMember();
        am.fileAttributes = octal!100644;
        assert(am._externalAttributes == octal!100644 << 16);
        assert((am._madeVersion & 0xFF00) == 0x0300);
    }

    /// ditto
    @property @nogc nothrow uint fileAttributes() const
    {
        version (Posix)
        {
            if ((_madeVersion & 0xFF00) == 0x0300)
                return _externalAttributes >> 16;
            return 0;
        }
        else version (Windows)
        {
            if ((_madeVersion & 0xFF00) == 0x0000)
                return _externalAttributes;
            return 0;
        }
        else
        {
            static assert(0, "Unimplemented platform");
        }
    }

    /**
     * Get or set the last modification time for this member.
     *
     * Params:
     *     time = Time to set (will be saved as DosFileTime, which is less accurate).
     *
     * Returns:
     *     The last modification time in DosFileFormat.
     */
    @property DosFileTime time() const @safe pure nothrow @nogc
    {
        return _time;
    }

    /// ditto
    @property void time(SysTime time)
    {
        _time = SysTimeToDosFileTime(time);
    }

    /// ditto
    @property void time(DosFileTime time) @safe pure nothrow @nogc
    {
        _time = time;
    }

    /**
     * Get or set compression method used for this member.
     *
     * Params:
     *     cm = Compression method.
     *
     * Returns: Compression method.
     *
     * See_Also:
     *     $(LREF CompressionMethod)
     **/
    @property @safe @nogc pure nothrow CompressionMethod compressionMethod() const { return _compressionMethod; }

    /// ditto
    @property @safe pure void compressionMethod(CompressionMethod cm)
    {
        if (cm == _compressionMethod) return;

        enforce!ZipException(_compressedSize == 0, "Can't change compression method for a compressed element");

        _compressionMethod = cm;
    }

    /**
     * The index of this archive member within the archive. Set this to a
     * different value for reordering the members of an archive.
     *
     * Params:
     *     value = Index value to set.
     *
     * Returns: The index.
     */
    @property ulong index(uint value) @safe pure nothrow @nogc { return _index = value; }
    @property ulong index() const @safe pure nothrow @nogc { return _index; } /// ditto

    debug(print)
    {
    void print()
    {
        printf("name = '%.*s'\n", name.length, name.ptr);
        printf("\tcomment = '%.*s'\n", comment.length, comment.ptr);
        printf("\tmadeVersion = x%04x\n", _madeVersion);
        printf("\textractVersion = x%04x\n", extractVersion);
        printf("\tflags = x%04x\n", flags);
        printf("\tcompressionMethod = %d\n", compressionMethod);
        printf("\ttime = %d\n", time);
        printf("\tcrc32 = x%08x\n", crc32);
        printf("\texpandedSize = %d\n", expandedSize);
        printf("\tcompressedSize = %d\n", compressedSize);
        printf("\tinternalAttributes = x%04x\n", internalAttributes);
        printf("\texternalAttributes = x%08x\n", externalAttributes);
        printf("\tindex = x%08x\n", index);
    }
    }
}

@safe pure unittest
{
    import std.exception : assertThrown, assertNotThrown;

    auto am = new ArchiveMember();

    assertNotThrown(am.compressionMethod(CompressionMethod.deflate));
    assertNotThrown(am.compressionMethod(CompressionMethod.none));

    am._compressedData = [0x65]; // not strictly necessary, but for consistency
    am._compressedSize = 1;

    assertThrown!ZipException(am.compressionMethod(CompressionMethod.deflate));
}

/**
 * Object representing the entire archive.
 * ZipArchives are collections of ArchiveMembers.
 */
final class ZipArchive
{
    import std.algorithm.comparison : max;
    import std.bitmanip : littleEndianToNative, nativeToLittleEndian;
    import std.conv : to;
    import std.datetime.systime : DosFileTime;

    alias fromLE = littleEndianToNative;

private:
    // names are taken directly from the specification
    // https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
    static immutable ubyte[] centralFileHeaderSignature = [ 0x50, 0x4b, 0x01, 0x02 ];
    static immutable ubyte[] localFileHeaderSignature = [ 0x50, 0x4b, 0x03, 0x04 ];
    static immutable ubyte[] endOfCentralDirSignature = [ 0x50, 0x4b, 0x05, 0x06 ];
    static immutable ubyte[] archiveExtraDataSignature = [ 0x50, 0x4b, 0x06, 0x08 ];
    static immutable ubyte[] digitalSignatureSignature = [ 0x50, 0x4b, 0x05, 0x05 ];
    static immutable ubyte[] zip64EndOfCentralDirSignature = [ 0x50, 0x4b, 0x06, 0x06 ];
    static immutable ubyte[] zip64EndOfCentralDirLocatorSignature = [ 0x50, 0x4b, 0x06, 0x07 ];

    struct EndOfCentralDirRecord
    {
        align (1): // just to make sure there are no gaps
        ubyte[4] signature;
        ubyte[2] numberOfThisDisk;
        ubyte[2] numberOfCDDisk;
        ubyte[2] entriesOnThisDisk;
        ubyte[2] entries;
        ubyte[4] size;
        ubyte[4] offset;
        ubyte[2] commentLength;
    }

    struct Zip64EndOfCentralDirLocatorRecord
    {
        align (1): // just to make sure there are no gaps
        ubyte[4] signature;
        ubyte[4] numberOfThisDisk;
        ubyte[8] offset;
        ubyte[4] numberOfDisks;
    }

    struct Zip64EndOfCentralDirRecord
    {
        align (1): // just to make sure there are no gaps
        ubyte[4] signature;
        ubyte[8] thisSize;
        ubyte[2] versionMade;
        ubyte[2] versionExtract;
        ubyte[4] numberOfThisDisk;
        ubyte[4] numberOfCDDisk;
        ubyte[8] entriesOnThisDisk;
        ubyte[8] entries;
        ubyte[8] size;
        ubyte[8] offset;
    }

    struct CentralFileHeader
    {
        align (1): // just to make sure there are no gaps
        ubyte[4] signature;
        ubyte[2] versionMade;
        ubyte[2] versionExtract;
        ubyte[2] flags;
        ubyte[2] compressionMethod;
        ubyte[4] time;
        ubyte[4] crc32;
        ubyte[4] compressedSize;
        ubyte[4] expandedSize;
        ubyte[2] nameLength;
        ubyte[2] extraFieldLength;
        ubyte[2] commentLength;
        ubyte[2] startDisk;
        ubyte[2] internalAttributes;
        ubyte[4] externalAttributes;
        ubyte[4] offset;
    }

    struct LocalFileHeader
    {
        align (1): // just to make sure there are no gaps
        ubyte[4] signature;
        ubyte[2] versionExtract;
        ubyte[2] flags;
        ubyte[2] compressionMethod;
        ubyte[4] time;
        ubyte[4] crc32;
        ubyte[4] compressedSize;
        ubyte[4] expandedSize;
        ubyte[2] nameLength;
        ubyte[2] extraFieldLength;
    }

public:
    string comment; /// The archive comment. Must be less than 65536 bytes in length.

    private ubyte[] _data;

    private bool _isZip64;
    static const ushort zip64ExtractVersion = 45;

    deprecated("Use digitalSignatureLength instead; will be removed in 2.098.0")
    static const int digiSignLength = 6;
    deprecated("Use zip64EndOfCentralDirLocatorLength instead; will be removed in 2.098.0")
    static const int eocd64LocLength = 20;
    deprecated("Use zip64EndOfCentralDirLength instead; will be removed in 2.098.0")
    static const int eocd64Length = 56;

    private Segment[] _segs;

    /**
     * Array representing the entire contents of the archive.
     *
     * Returns: Data of the entire contents of the archive.
     */
    @property @safe @nogc pure nothrow ubyte[] data() { return _data; }

    /**
     * 0 since multi-disk zip archives are not supported.
     *
     * Returns: Number of this disk.
     */
    deprecated("Multidisk not supported; will be removed in 2.099.0")
    @property @safe @nogc pure nothrow uint diskNumber() const { return 0; }

    /**
     * 0 since multi-disk zip archives are not supported.
     *
     * Returns: Number of the disk, where the central directory starts.
     */
    deprecated("Multidisk not supported; will be removed in 2.099.0")
    @property @safe @nogc pure nothrow uint diskStartDir() const { return 0; }

    /**
     * Number of ArchiveMembers in the directory.
     *
     * Returns: The number of files in this archive.
     */
    deprecated("Use totalEntries instead; will be removed in 2.099.0")
    @property @safe @nogc pure nothrow uint numEntries() const { return cast(uint) _directory.length; }
    @property @safe @nogc pure nothrow uint totalEntries() const { return cast(uint) _directory.length; }    /// ditto

    /**
     * True when the archive is in Zip64 format. Set this to true to force building a Zip64 archive.
     *
     * Params:
     *     value = True, when the archive is forced to be build in Zip64 format.
     *
     * Returns: True, when the archive is in Zip64 format.
     */
    @property @safe @nogc pure nothrow bool isZip64() const { return _isZip64; }

    /// ditto
    @property @safe @nogc pure nothrow void isZip64(bool value) { _isZip64 = value; }

    /**
     * Associative array indexed by the name of each member of the archive.
     *
     * All the members of the archive can be accessed with a foreach loop:
     *
     * Example:
     * --------------------
     * ZipArchive archive = new ZipArchive(data);
     * foreach (ArchiveMember am; archive.directory)
     * {
     *     writefln("member name is '%s'", am.name);
     * }
     * --------------------
     *
     * Returns: Associative array with all archive members.
     */
    @property @safe @nogc pure nothrow ArchiveMember[string] directory() { return _directory; }

    private ArchiveMember[string] _directory;

    debug (print)
    {
    @safe void print()
    {
        printf("\tdiskNumber = %u\n", diskNumber);
        printf("\tdiskStartDir = %u\n", diskStartDir);
        printf("\tnumEntries = %u\n", numEntries);
        printf("\ttotalEntries = %u\n", totalEntries);
        printf("\tcomment = '%.*s'\n", comment.length, comment.ptr);
    }
    }

    /* ============ Creating a new archive =================== */

    /**
     * Constructor to use when creating a new archive.
     */
    this() @safe @nogc pure nothrow
    {
    }

    /**
     * Add a member to the archive. The file is compressed on the fly.
     *
     * Params:
     *     de = Member to be added.
     *
     * Throws: ZipException when an unsupported compression method is used or when
     *         compression failed.
     */
    @safe void addMember(ArchiveMember de)
    {
        _directory[de.name] = de;
        if (!de._compressedData.length)
        {
            switch (de.compressionMethod)
            {
                case CompressionMethod.none:
                    de._compressedData = de._expandedData;
                    break;

                case CompressionMethod.deflate:
                    import std.zlib : compress;
                    () @trusted
                    {
                        de._compressedData = cast(ubyte[]) compress(cast(void[]) de._expandedData);
                    }();
                        de._compressedData = de._compressedData[2 .. de._compressedData.length - 4];
                    break;

                default:
                    throw new ZipException("unsupported compression method");
            }

            de._compressedSize = to!ulong(de._compressedData.length);
            import std.zlib : crc32;
            () @trusted { de._crc32 = crc32(0, cast(void[]) de._expandedData); }();
        }
        assert(de._compressedData.length == de._compressedSize, "Archive member compressed failed.");
    }

    @safe unittest
    {
        import std.exception : assertThrown;

        ArchiveMember am = new ArchiveMember();
        am.compressionMethod = cast(CompressionMethod) 3;

        ZipArchive zip = new ZipArchive();

        assertThrown!ZipException(zip.addMember(am));
    }

    /**
     * Delete member `de` from the archive. Uses the name of the member
     * to detect which element to delete.
     *
     * Params:
     *     de = Member to be deleted.
     */
    @safe void deleteMember(ArchiveMember de)
    {
        _directory.remove(de.name);
    }

    // issue 20398
    @safe unittest
    {
        import std.string : representation;

        ArchiveMember file1 = new ArchiveMember();
        file1.name = "test1.txt";
        file1.expandedData("Test data.\n".dup.representation);

        ZipArchive zip = new ZipArchive();

        zip.addMember(file1);
        assert(zip.totalEntries == 1);

        zip.deleteMember(file1);
        assert(zip.totalEntries == 0);
    }

    /**
     * Construct the entire contents of the current members of the archive.
     *
     * Fills in the properties data[], totalEntries, and directory[].
     * For each ArchiveMember, fills in properties crc32, compressedSize,
     * compressedData[].
     *
     * Returns: Array representing the entire archive.
     *
     * Throws: ZipException when the archive could not be build.
     */
    void[] build() @safe pure
    {
        import std.array : array, uninitializedArray;
        import std.algorithm.sorting : sort;
        import std.string : representation;

        size_t i;
        size_t directoryOffset;

        enforce!ZipException(comment.length <= 0xFFFF, "archive comment longer than 65535");

        // Compress each member; compute size
        ulong archiveSize = 0;
        ulong directorySize = 0;
        auto directory = _directory.byValue.array.sort!((x, y) => x.index < y.index).release;
        foreach (ArchiveMember de; directory)
        {
            enforce!ZipException(archiveSize + LocalFileHeader.sizeof + de.name.length
                                 + de.extra.length + de.compressedSize + directorySize
                                 + CentralFileHeader.sizeof + de.name.length + de.extra.length
                                 + de.comment.length + EndOfCentralDirRecord.sizeof + comment.length
                                 + Zip64EndOfCentralDirLocatorRecord.sizeof
                                 + Zip64EndOfCentralDirRecord.sizeof <= uint.max,
                                 "zip files bigger than 4 GB are unsupported");

            archiveSize += LocalFileHeader.sizeof + de.name.length +
                                de.extra.length +
                                de.compressedSize;
            directorySize += CentralFileHeader.sizeof + de.name.length +
                                de.extra.length +
                                de.comment.length;
        }

        if (!isZip64 && _directory.length > ushort.max)
            _isZip64 = true;
        ulong dataSize = archiveSize + directorySize + EndOfCentralDirRecord.sizeof + cast(uint) comment.length;
        if (isZip64)
            dataSize += Zip64EndOfCentralDirLocatorRecord.sizeof + Zip64EndOfCentralDirRecord.sizeof;

        static if (size_t.sizeof < ulong.sizeof)
        {
            enforce(dataSize <= size_t.max, "cannot handle zip archives larger than 4 GB on 32bit computers");
            _data = uninitializedArray!(ubyte[])(cast(size_t) dataSize);
        }
        else
        {
            _data = uninitializedArray!(ubyte[])(dataSize);
        }

        // Populate the data[]

        // Store each archive member
        i = 0;
        foreach (ArchiveMember de; directory)
        {
            de.offset = i;
            _data[i .. i + 4] = localFileHeaderSignature;
            putUshort(i + 4,  de.extractVersion);
            putUshort(i + 6,  de.flags);
            putUshort(i + 8,  de._compressionMethod);
            putUint  (i + 10, cast(uint) de.time);
            putUint  (i + 14, de.crc32);
            putUint  (i + 18, to!uint(de.compressedSize));
            putUint  (i + 22, to!uint(de.expandedSize));
            putUshort(i + 26, cast(ushort) de.name.length);
            putUshort(i + 28, cast(ushort) de.extra.length);
            i += LocalFileHeader.sizeof;

            _data[i .. i + de.name.length] = (de.name.representation)[];
            i += de.name.length;
            _data[i .. i + de.extra.length] = (cast(ubyte[]) de.extra)[];
            i += de.extra.length;

            static if (size_t.sizeof < ulong.sizeof)
            {
                enforce(i + de.compressedSize <= size_t.max,
                        "cannot handle zip archives larger than 4 GB on 32bit computers");
                _data[i .. i + cast(size_t) de.compressedSize] = de.compressedData[];
            }
            else
            {
                _data[i .. i + de.compressedSize] = de.compressedData[];
            }

            i += de.compressedSize;
        }

        // Write directory
        directoryOffset = i;
        foreach (ArchiveMember de; directory)
        {
            _data[i .. i + 4] = centralFileHeaderSignature;
            putUshort(i + 4,  de._madeVersion);
            putUshort(i + 6,  de.extractVersion);
            putUshort(i + 8,  de.flags);
            putUshort(i + 10, de._compressionMethod);
            putUint  (i + 12, cast(uint) de.time);
            putUint  (i + 16, de.crc32);
            putUint  (i + 20, to!uint(de.compressedSize));
            putUint  (i + 24, to!uint(de.expandedSize));
            putUshort(i + 28, cast(ushort) de.name.length);
            putUshort(i + 30, cast(ushort) de.extra.length);
            putUshort(i + 32, cast(ushort) de.comment.length);
            putUshort(i + 34, cast(ushort) 0);
            putUshort(i + 36, de.internalAttributes);
            putUint  (i + 38, de._externalAttributes);
            putUint  (i + 42, to!uint(de.offset));
            i += CentralFileHeader.sizeof;

            _data[i .. i + de.name.length] = (de.name.representation)[];
            i += de.name.length;
            _data[i .. i + de.extra.length] = (cast(ubyte[]) de.extra)[];
            i += de.extra.length;
            _data[i .. i + de.comment.length] = (de.comment.representation)[];
            i += de.comment.length;
        }

        if (isZip64)
        {
            // Write zip64 end of central directory record
            ulong eocd64Offset = i;
            _data[i .. i + 4] = zip64EndOfCentralDirSignature;
            putUlong (i + 4,  Zip64EndOfCentralDirRecord.sizeof - 12);
            putUshort(i + 12, zip64ExtractVersion);
            putUshort(i + 14, zip64ExtractVersion);
            putUint  (i + 16, cast(ushort) 0);
            putUint  (i + 20, cast(ushort) 0);
            putUlong (i + 24, directory.length);
            putUlong (i + 32, directory.length);
            putUlong (i + 40, directorySize);
            putUlong (i + 48, directoryOffset);
            i += Zip64EndOfCentralDirRecord.sizeof;

            // Write zip64 end of central directory record locator
            _data[i .. i + 4] = zip64EndOfCentralDirLocatorSignature;
            putUint  (i + 4,  cast(ushort) 0);
            putUlong (i + 8,  eocd64Offset);
            putUint  (i + 16, 1);
            i += Zip64EndOfCentralDirLocatorRecord.sizeof;
        }

        // Write end record
        _data[i .. i + 4] = endOfCentralDirSignature;
        putUshort(i + 4,  cast(ushort) 0);
        putUshort(i + 6,  cast(ushort) 0);
        putUshort(i + 8,  (totalEntries > ushort.max ? ushort.max : cast(ushort) totalEntries));
        putUshort(i + 10, (totalEntries > ushort.max ? ushort.max : cast(ushort) totalEntries));
        putUint  (i + 12, to!uint(directorySize));
        putUint  (i + 16, to!uint(directoryOffset));
        putUshort(i + 20, cast(ushort) comment.length);
        i += EndOfCentralDirRecord.sizeof;

        // Write archive comment
        assert(i + comment.length == data.length, "Writing the archive comment failed.");
        _data[i .. data.length] = (comment.representation)[];

        return cast(void[]) data;
    }

    @safe pure unittest
    {
        import std.exception : assertNotThrown;

        ZipArchive zip = new ZipArchive();
        zip.comment = "A";
        assertNotThrown(zip.build());
    }

    @safe pure unittest
    {
        import std.range : repeat, array;
        import std.exception : assertThrown;

        ZipArchive zip = new ZipArchive();
        zip.comment = 'A'.repeat(70_000).array;
        assertThrown!ZipException(zip.build());
    }

    /* ============ Reading an existing archive =================== */

    /**
     * Constructor to use when reading an existing archive.
     *
     * Fills in the properties data[], totalEntries, comment[], and directory[].
     * For each ArchiveMember, fills in
     * properties madeVersion, extractVersion, flags, compressionMethod, time,
     * crc32, compressedSize, expandedSize, compressedData[],
     * internalAttributes, externalAttributes, name[], extra[], comment[].
     * Use expand() to get the expanded data for each ArchiveMember.
     *
     * Params:
     *     buffer = The entire contents of the archive.
     *
     * Throws: ZipException when the archive was invalid or when malware was detected.
     */
    this(void[] buffer)
    {
        this._data = cast(ubyte[]) buffer;

        auto eocdrOffset = findEndOfCentralDirRecord();

        // init overlap checks
        _segs = [Segment(0, data.length)];

        auto eocdr = getRecord!EndOfCentralDirRecord(eocdrOffset);
        comment = cast(string) getSegment(eocdrOffset + EndOfCentralDirRecord.sizeof,
                                          fromLE!ushort(eocdr.commentLength));

        _isZip64 = checkForZip64(eocdrOffset);

        ulong count;
        ulong end;
        ulong next;

        if (isZip64)
        {
            auto z64eocdlr = getRecord!Zip64EndOfCentralDirLocatorRecord(eocdrOffset
                                                                         - Zip64EndOfCentralDirLocatorRecord.sizeof);
            auto z64eocdrOffset = fromLE!ulong(z64eocdlr.offset);
            auto z64eocdr = getRecord!Zip64EndOfCentralDirRecord(z64eocdrOffset);

            count = fromLE!ulong(z64eocdr.entries);
            next = fromLE!ulong(z64eocdr.offset);
            auto size = fromLE!ulong(z64eocdr.size);
            end = next + size;
            auto entriesOnThisDisk = fromLE!ulong(z64eocdr.entriesOnThisDisk);

            enforce!ZipException(z64eocdr.signature == zip64EndOfCentralDirSignature,
                                 "invalid Zip EOCD64 signature");
            enforce!ZipException(entriesOnThisDisk <= uint.max,
                                 "supposedly more than 4294967296 files in archive");
            enforce!ZipException(entriesOnThisDisk == count,
                                 "multiple disk zips not supported");
            enforce!ZipException(size <= z64eocdrOffset && next <= z64eocdrOffset && end <= z64eocdrOffset,
                                 "corrupted directory");

            // The extensible data segment is not yet used, but we need to query it to make sure
            // it doesn't overlap anything else. Might be provided to the user in the future.
            //
            // For whatever reasons, the designers of the zip format decided to reduce the size of this chunk by 12,
            // so we need to add this 12 again to get the whole segment.
            auto extensibleData = getSegment(fromLE!ulong(z64eocdlr.offset) + Zip64EndOfCentralDirRecord.sizeof,
                                             fromLE!ulong(z64eocdr.thisSize) - Zip64EndOfCentralDirRecord.sizeof + 12);

        }
        else
        {
            count = fromLE!ushort(eocdr.entries);
            next = fromLE!uint(eocdr.offset);
            end =  next + fromLE!uint(eocdr.size);
        }

        foreach (n; 0 .. count)
        {
            auto de = extractArchiveMember(n, next);
            _directory[de.name] = de;
        }

        enforce!ZipException(next == end, "invalid directory size");
    }

    @system unittest
    {
        import std.exception : assertThrown;

        // contains wrong directorySize (extra byte 0xff)
        auto file =
            "\x50\x4b\x03\x04\x0a\x00\x00\x00\x00\x00\x8f\x72\x4a\x4f\x86\xa6"~
            "\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04\x00\x1c\x00\x66\x69"~
            "\x6c\x65\x55\x54\x09\x00\x03\x0d\x22\x9f\x5d\x12\x22\x9f\x5d\x75"~
            "\x78\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x68\x65"~
            "\x6c\x6c\x6f\x50\x4b\x01\x02\x1e\x03\x0a\x00\x00\x00\x00\x00\x8f"~
            "\x72\x4a\x4f\x86\xa6\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04"~
            "\x00\x18\x00\x00\x00\x00\x00\x01\x00\x00\x00\xb0\x81\x00\x00\x00"~
            "\x00\x66\x69\x6c\x65\x55\x54\x05\x00\x03\x0d\x22\x9f\x5d\x75\x78"~
            "\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\xff\x50\x4b\x05"~
            "\x06\x00\x00\x00\x00\x01\x00\x01\x00\x4b\x00\x00\x00\x43\x00\x00"~
            "\x00\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));
    }

    @system unittest
    {
        import std.exception : assertThrown;

        // wrong eocdOffset
        auto file =
            "\x50\x4b\x06\x06\x2c\x00\x00\x00\x00\x00\x00\x00\x1e\x03\x2d\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4b\x06\x07\x00\x00\x00\x00"~
            "\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4B\x05\x06"~
            "\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff"~
            "\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));
    }

    @system unittest
    {
        import std.exception : assertThrown;

        // wrong signature of zip64 end of central directory
        auto file =
            "\x50\x4b\x06\x07\x2c\x00\x00\x00\x00\x00\x00\x00\x1e\x03\x2d\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4b\x06\x07\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4B\x05\x06"~
            "\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff"~
            "\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));
    }

    @system unittest
    {
        import std.exception : assertThrown;

        // wrong size of zip64 end of central directory
        auto file =
            "\x50\x4b\x06\x06\xff\x00\x00\x00\x00\x00\x00\x00\x1e\x03\x2d\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4b\x06\x07\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4B\x05\x06"~
            "\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff"~
            "\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));
    }

    @system unittest
    {
        import std.exception : assertThrown;

        // too many entries in zip64 end of central directory
        auto file =
            "\x50\x4b\x06\x06\x2c\x00\x00\x00\x00\x00\x00\x00\x1e\x03\x2d\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\xff\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4b\x06\x07\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4B\x05\x06"~
            "\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff"~
            "\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));
    }

    @system unittest
    {
        import std.exception : assertThrown;

        // zip64: numEntries and totalEntries differ
        auto file =
            "\x50\x4b\x06\x06\x2c\x00\x00\x00\x00\x00\x00\x00\x1e\x03\x2d\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4b\x06\x07\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4B\x05\x06"~
            "\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff"~
            "\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));
    }

    @system unittest
    {
        import std.exception : assertThrown;

        // zip64: directorySize too large
        auto file =
            "\x50\x4b\x06\x06\x2c\x00\x00\x00\x00\x00\x00\x00\x1e\x03\x2d\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\x00\x00\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4b\x06\x07\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4B\x05\x06"~
            "\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff"~
            "\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));

        // zip64: directoryOffset too large
        file =
            "\x50\x4b\x06\x06\x2c\x00\x00\x00\x00\x00\x00\x00\x1e\x03\x2d\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
            "\xff\xff\x00\x00\x00\x00\x00\x00\x50\x4b\x06\x07\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4B\x05\x06"~
            "\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff"~
            "\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));

        // zip64: directorySize + directoryOffset too large
        // we need to add a useless byte at the beginning to avoid that one of the other two checks allready fires
        file =
            "\x00\x50\x4b\x06\x06\x2c\x00\x00\x00\x00\x00\x00\x00\x1e\x03\x2d\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
            "\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00"~
            "\x01\x00\x00\x00\x00\x00\x00\x00\x50\x4b\x06\x07\x00\x00\x00\x00"~
            "\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4B\x05\x06"~
            "\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff"~
            "\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));
    }

    @system unittest
    {
        import std.exception : assertThrown;

        // wrong central file header signature
        auto file =
            "\x50\x4b\x03\x04\x0a\x00\x00\x00\x00\x00\x8f\x72\x4a\x4f\x86\xa6"~
            "\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04\x00\x1c\x00\x66\x69"~
            "\x6c\x65\x55\x54\x09\x00\x03\x0d\x22\x9f\x5d\x12\x22\x9f\x5d\x75"~
            "\x78\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x68\x65"~
            "\x6c\x6c\x6f\x50\x4b\x01\x03\x1e\x03\x0a\x00\x00\x00\x00\x00\x8f"~
            "\x72\x4a\x4f\x86\xa6\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04"~
            "\x00\x18\x00\x00\x00\x00\x00\x01\x00\x00\x00\xb0\x81\x00\x00\x00"~
            "\x00\x66\x69\x6c\x65\x55\x54\x05\x00\x03\x0d\x22\x9f\x5d\x75\x78"~
            "\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x50\x4b\x05"~
            "\x06\x00\x00\x00\x00\x01\x00\x01\x00\x4a\x00\x00\x00\x43\x00\x00"~
            "\x00\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));
    }

    @system unittest
    {
        import std.exception : assertThrown;

        // invalid field lengths in file header
        auto file =
            "\x50\x4b\x03\x04\x0a\x00\x00\x00\x00\x00\x8f\x72\x4a\x4f\x86\xa6"~
            "\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04\x00\x1c\x00\x66\x69"~
            "\x6c\x65\x55\x54\x09\x00\x03\x0d\x22\x9f\x5d\x12\x22\x9f\x5d\x75"~
            "\x78\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x68\x65"~
            "\x6c\x6c\x6f\x50\x4b\x01\x02\x1e\x03\x0a\x00\x00\x00\x00\x00\x8f"~
            "\x72\x4a\x4f\x86\xa6\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04"~
            "\x00\x18\x00\x01\x00\x00\x00\x01\x00\x00\x00\xb0\x81\x00\x00\x00"~
            "\x00\x66\x69\x6c\x65\x55\x54\x05\x00\x03\x0d\x22\x9f\x5d\x75\x78"~
            "\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\xff\x50\x4b\x05"~
            "\x06\x00\x00\x00\x00\x01\x00\x01\x00\x4a\x00\x00\x00\x43\x00\x00"~
            "\x00\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));
    }

    private ulong findEndOfCentralDirRecord()
    {
        // end of central dir record can be followed by a comment of up to 2^^16-1 bytes
        // therefore we have to scan 2^^16 positions

        ulong endrecOffset = to!uint(data.length);
        foreach (i; 0 .. 2 ^^ 16)
        {
            if (i + EndOfCentralDirRecord.sizeof > data.length) break;
            ulong start = data.length - EndOfCentralDirRecord.sizeof - i;

            // resetting the segments to avoid exceptions due to intentionally overlaps
            _segs = [Segment(0, data.length)];
            auto eocdr = getRecord!EndOfCentralDirRecord(start);
            if (eocdr.signature != endOfCentralDirSignature) continue;

            if (fromLE!ushort(eocdr.numberOfThisDisk) != 0) continue; // no support for multiple volumes yet
            if (fromLE!ushort(eocdr.numberOfCDDisk) != 0) continue; // dito

            ulong k = start - Zip64EndOfCentralDirLocatorRecord.sizeof;
            static if (size_t.sizeof < ulong.sizeof)
            {
                enforce(k >= start || k + 4 <= size_t.max,
                        "cannot handle zip archives larger than 4 GB on 32bit computers");
                auto maybeZip64 = k < start
                    && data[cast(size_t) k .. cast(size_t) (k + 4)] == zip64EndOfCentralDirLocatorSignature;
            }
            else
            {
                auto maybeZip64 = k < start && data[k .. k + 4] == zip64EndOfCentralDirLocatorSignature;
            }

            auto totalNumberOfEntriesOnThisDisk = fromLE!ushort(eocdr.entriesOnThisDisk);
            auto totalNumberOfEntriesInCentralDir = fromLE!ushort(eocdr.entries);

            if (totalNumberOfEntriesOnThisDisk > totalNumberOfEntriesInCentralDir &&
               (!maybeZip64 || totalNumberOfEntriesOnThisDisk < 0xffff)) continue;

            auto sizeOfCentralDirectory = fromLE!uint(eocdr.size);
            if (sizeOfCentralDirectory > start &&
               (!maybeZip64 || sizeOfCentralDirectory < 0xffff)) continue;

            auto offsetOfCentralDirectory = fromLE!uint(eocdr.offset);
            if (offsetOfCentralDirectory + sizeOfCentralDirectory > start &&
               (!maybeZip64 || offsetOfCentralDirectory < 0xffff)) continue;

            if (start + EndOfCentralDirRecord.sizeof + fromLE!ushort(eocdr.commentLength) != data.length) continue;

            enforce!ZipException(endrecOffset == data.length, "found more than one valid 'end of central dir record'");
            endrecOffset = start;
        }

        enforce!ZipException(endrecOffset != data.length,
                             "found no valid 'end of central dir record'");

        return endrecOffset;
    }

    private bool checkForZip64(ulong offset)
    {
        // if we find a zip64locator signature at the correct place before the end of central dir
        // record, we assume, that this archive is in zip64 format

        if (offset < Zip64EndOfCentralDirLocatorRecord.sizeof) return false;

        ulong z64offset = offset - Zip64EndOfCentralDirLocatorRecord.sizeof;

        static if (size_t.sizeof < ulong.sizeof)
        {
            enforce(z64offset + 4 <= size_t.max,
                    "cannot handle zip archives larger than 4 GB on 32bit computers");
            return _data[cast(size_t) z64offset .. cast(size_t) (z64offset + 4)]
                == zip64EndOfCentralDirLocatorSignature;
        }
        else
        {
            return _data[z64offset .. z64offset + 4] == zip64EndOfCentralDirLocatorSignature;
        }
    }

    private auto extractArchiveMember(ulong n, ref ulong next)
    {
        auto cfh = getRecord!CentralFileHeader(next);
        enforce!ZipException(cfh.signature == centralFileHeaderSignature, "invalid directory signature");

        ArchiveMember de = new ArchiveMember();
        de._index = n;
        de._madeVersion = fromLE!ushort(cfh.versionMade);
        de._extractVersion = fromLE!ushort(cfh.versionExtract);
        de.flags = fromLE!ushort(cfh.flags);
        de._compressionMethod = cast(CompressionMethod) fromLE!ushort(cfh.compressionMethod);
        de.time = cast(DosFileTime) fromLE!uint(cfh.time);
        de._crc32 = fromLE!uint(cfh.crc32);
        de._compressedSize = fromLE!uint(cfh.compressedSize);
        de._expandedSize = fromLE!uint(cfh.expandedSize);
        de.internalAttributes = fromLE!ushort(cfh.internalAttributes);
        de._externalAttributes = fromLE!uint(cfh.externalAttributes);
        de.offset = fromLE!uint(cfh.offset);

        ulong namelen = fromLE!ushort(cfh.nameLength);
        ulong extralen = fromLE!ushort(cfh.extraFieldLength);
        ulong commentlen = fromLE!ushort(cfh.commentLength);

        next += CentralFileHeader.sizeof;
        de.name = cast(string) getSegment(next, namelen);
        next += namelen;
        de.extra = getSegment(next, extralen);
        next += extralen;
        de.comment = cast(string) getSegment(next, commentlen);
        next += commentlen;

        extractAndVerifyArchiveMemberData(de);

        return de;
    }

    private void extractAndVerifyArchiveMemberData(ref ArchiveMember de)
    {
        auto lfh = getRecord!LocalFileHeader(de.offset);
        enforce!ZipException(lfh.signature == localFileHeaderSignature, "file header signature mismatch");
        enforce!ZipException(fromLE!ushort(lfh.versionExtract) == de._extractVersion, "version mismatch");
        enforce!ZipException(fromLE!ushort(lfh.flags) == de.flags, "flags mismatch");
        enforce!ZipException(cast(CompressionMethod) fromLE!ushort(lfh.compressionMethod) == de._compressionMethod,
                             "compression method mismatch");
        enforce!ZipException(cast(DosFileTime) fromLE!uint(lfh.time) == de.time, "time mismatch");
        enforce!ZipException(fromLE!uint(lfh.crc32) == de._crc32, "crc32 mismatch");
        enforce!ZipException(fromLE!uint(lfh.compressedSize) == de._compressedSize, "compressed size mismatch");
        enforce!ZipException(fromLE!uint(lfh.expandedSize) == de._expandedSize, "expanded size mismatch");

        auto leaderlen = LocalFileHeader.sizeof + fromLE!ushort(lfh.nameLength) + fromLE!ushort(lfh.extraFieldLength);
        auto leader = getSegment(de.offset + LocalFileHeader.sizeof, leaderlen - LocalFileHeader.sizeof);
        de._compressedData = getSegment(de.offset + leaderlen, de.compressedSize);
    }

    /**
     * Decompress the contents of a member.
     *
     * Fills in properties extractVersion, flags, compressionMethod, time,
     * crc32, compressedSize, expandedSize, expandedData[], name[], extra[].
     *
     * Params:
     *     de = Member to be decompressed.
     *
     * Returns: The expanded data.
     *
     * Throws: ZipException when the entry is invalid or the compression method is not supported.
     */
    ubyte[] expand(ArchiveMember de)
    {
        import std.string : representation;

        uint namelen;
        uint extralen;

        enforce(de.offset + 30 <= size_t.max,
                "cannot handle zip archives larger than 4 GB on 32bit computers");

        enforce!ZipException(_data[cast(size_t) de.offset .. cast(size_t) (de.offset + 4)] == localFileHeaderSignature,
                             "wrong local file header signature found");

        // These values should match what is in the main zip archive directory
        de._extractVersion = getUshort(cast(size_t) (de.offset + 4));
        de.flags = getUshort(cast(size_t) (de.offset + 6));
        de._compressionMethod = cast(CompressionMethod) getUshort(cast(size_t) (de.offset + 8));
        de.time = cast(DosFileTime) getUint(cast(size_t) (de.offset + 10));
        de._crc32 = getUint(cast(size_t) (de.offset + 14));
        de._compressedSize = max(getUint(cast(size_t) (de.offset + 18)), de.compressedSize);
        de._expandedSize = max(getUint(cast(size_t) (de.offset + 22)), de.expandedSize);
        namelen = getUshort(cast(size_t) (de.offset + 26));
        extralen = getUshort(cast(size_t) (de.offset + 28));

        debug(print)
        {
            printf("\t\texpandedSize = %d\n", de.expandedSize);
            printf("\t\tcompressedSize = %d\n", de.compressedSize);
            printf("\t\tnamelen = %d\n", namelen);
            printf("\t\textralen = %d\n", extralen);
        }

        enforce!ZipException((de.flags & 1) == 0, "encryption not supported");

        switch (de.compressionMethod)
        {
            case CompressionMethod.none:
                de._expandedData = de.compressedData;
                return de.expandedData;

            case CompressionMethod.deflate:
                // -15 is a magic value used to decompress zip files.
                // It has the effect of not requiring the 2 byte header
                // and 4 byte trailer.
                import std.zlib : uncompress;

                static if (size_t.sizeof < ulong.sizeof)
                {
                    enforce(de.expandedSize <= size_t.max,
                            "cannot handle zip archives larger than 4 GB on 32bit computers");
                    de._expandedData = cast(ubyte[]) uncompress(cast(void[]) de.compressedData,
                                                                cast(size_t) de.expandedSize, -15);
                }
                else
                {
                    de._expandedData = cast(ubyte[]) uncompress(cast(void[]) de.compressedData, de.expandedSize, -15);
                }

                return de.expandedData;

            default:
                throw new ZipException("unsupported compression method");
        }
    }

    @system unittest
    {
        import std.exception : assertThrown;

        // check for correct local file header signature
        auto file =
            "\x50\x4b\x04\x04\x0a\x00\x00\x00\x00\x00\x8f\x72\x4a\x4f\x86\xa6"~
            "\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04\x00\x1c\x00\x66\x69"~
            "\x6c\x65\x55\x54\x09\x00\x03\x0d\x22\x9f\x5d\x12\x22\x9f\x5d\x75"~
            "\x78\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x68\x65"~
            "\x6c\x6c\x6f\x50\x4b\x01\x02\x1e\x03\x0a\x00\x00\x00\x00\x00\x8f"~
            "\x72\x4a\x4f\x86\xa6\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04"~
            "\x00\x18\x00\x00\x00\x00\x00\x01\x00\x00\x00\xb0\x81\x00\x00\x00"~
            "\x00\x66\x69\x6c\x65\x55\x54\x05\x00\x03\x0d\x22\x9f\x5d\x75\x78"~
            "\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x50\x4b\x05"~
            "\x06\x00\x00\x00\x00\x01\x00\x01\x00\x4a\x00\x00\x00\x43\x00\x00"~
            "\x00\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));
    }

    @system unittest
    {
        import std.exception : assertThrown;

        // check for encryption flag
        auto file =
            "\x50\x4b\x03\x04\x0a\x00\x01\x00\x00\x00\x8f\x72\x4a\x4f\x86\xa6"~
            "\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04\x00\x1c\x00\x66\x69"~
            "\x6c\x65\x55\x54\x09\x00\x03\x0d\x22\x9f\x5d\x12\x22\x9f\x5d\x75"~
            "\x78\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x68\x65"~
            "\x6c\x6c\x6f\x50\x4b\x01\x02\x1e\x03\x0a\x00\x00\x00\x00\x00\x8f"~
            "\x72\x4a\x4f\x86\xa6\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04"~
            "\x00\x18\x00\x00\x00\x00\x00\x01\x00\x00\x00\xb0\x81\x00\x00\x00"~
            "\x00\x66\x69\x6c\x65\x55\x54\x05\x00\x03\x0d\x22\x9f\x5d\x75\x78"~
            "\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x50\x4b\x05"~
            "\x06\x00\x00\x00\x00\x01\x00\x01\x00\x4a\x00\x00\x00\x43\x00\x00"~
            "\x00\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));
    }

    @system unittest
    {
        import std.exception : assertThrown;

        // check for invalid compression method
        auto file =
            "\x50\x4b\x03\x04\x0a\x00\x00\x00\x03\x00\x8f\x72\x4a\x4f\x86\xa6"~
            "\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04\x00\x1c\x00\x66\x69"~
            "\x6c\x65\x55\x54\x09\x00\x03\x0d\x22\x9f\x5d\x12\x22\x9f\x5d\x75"~
            "\x78\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x68\x65"~
            "\x6c\x6c\x6f\x50\x4b\x01\x02\x1e\x03\x0a\x00\x00\x00\x00\x00\x8f"~
            "\x72\x4a\x4f\x86\xa6\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04"~
            "\x00\x18\x00\x00\x00\x00\x00\x01\x00\x00\x00\xb0\x81\x00\x00\x00"~
            "\x00\x66\x69\x6c\x65\x55\x54\x05\x00\x03\x0d\x22\x9f\x5d\x75\x78"~
            "\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x50\x4b\x05"~
            "\x06\x00\x00\x00\x00\x01\x00\x01\x00\x4a\x00\x00\x00\x43\x00\x00"~
            "\x00\x00\x00";

        assertThrown!ZipException(new ZipArchive(cast(void[]) file));
    }

    /* ============ Utility =================== */

    @safe @nogc pure nothrow ushort getUshort(size_t i)
    {
        ubyte[2] result = data[i .. i + 2];
        return littleEndianToNative!ushort(result);
    }

    @safe @nogc pure nothrow uint getUint(size_t i)
    {
        ubyte[4] result = data[i .. i + 4];
        return littleEndianToNative!uint(result);
    }

    @safe @nogc pure nothrow ulong getUlong(size_t i)
    {
        ubyte[8] result = data[i .. i + 8];
        return littleEndianToNative!ulong(result);
    }

    @safe @nogc pure nothrow void putUshort(size_t i, ushort us)
    {
        data[i .. i + 2] = nativeToLittleEndian(us);
    }

    @safe @nogc pure nothrow void putUint(size_t i, uint ui)
    {
        data[i .. i + 4] = nativeToLittleEndian(ui);
    }

    @safe @nogc pure nothrow void putUlong(size_t i, ulong ul)
    {
        data[i .. i + 8] = nativeToLittleEndian(ul);
    }

    /* ============== for detecting overlaps =============== */

private:

    // defines a segment of the zip file, including start, excluding end
    struct Segment
    {
        ulong start;
        ulong end;
    }

    // removes Segment start .. end from _segs
    // throws zipException if start .. end is not completely available in _segs;
    void removeSegment(ulong start, ulong end) pure @safe
    in (start <= end, "segment invalid")
    {
        if (start == end) return;

        auto found = false;
        size_t pos;
        foreach (i,seg;_segs)
            if (seg.start <= start && seg.end >= end
                && (!found || seg.start > _segs[pos].start))
            {
                found = true;
                pos = i;
            }

        enforce!ZipException(found, "overlapping data detected");

        if (start>_segs[pos].start)
            _segs ~= Segment(_segs[pos].start, start);
        if (end<_segs[pos].end)
            _segs ~= Segment(end, _segs[pos].end);
        _segs = _segs[0 .. pos] ~ _segs[pos + 1 .. $];
    }

    pure @safe unittest
    {
        with (new ZipArchive())
        {
            _segs = [Segment(0,100)];
            removeSegment(10,20);
            assert(_segs == [Segment(0,10),Segment(20,100)]);

            _segs = [Segment(0,100)];
            removeSegment(0,20);
            assert(_segs == [Segment(20,100)]);

            _segs = [Segment(0,100)];
            removeSegment(10,100);
            assert(_segs == [Segment(0,10)]);

            _segs = [Segment(0,100), Segment(200,300), Segment(400,500)];
            removeSegment(220,230);
            assert(_segs == [Segment(0,100),Segment(400,500),Segment(200,220),Segment(230,300)]);

            _segs = [Segment(200,300), Segment(0,100), Segment(400,500)];
            removeSegment(20,30);
            assert(_segs == [Segment(200,300),Segment(400,500),Segment(0,20),Segment(30,100)]);

            import std.exception : assertThrown;

            _segs = [Segment(0,100), Segment(200,300), Segment(400,500)];
            assertThrown(removeSegment(120,230));

            _segs = [Segment(0,100), Segment(200,300), Segment(400,500)];
            removeSegment(0,100);
            assertThrown(removeSegment(0,100));

            _segs = [Segment(0,100)];
            removeSegment(0,100);
            assertThrown(removeSegment(0,100));
        }
    }

    auto getSegment(ulong start, ulong length) pure @safe
    {
        removeSegment(start, start + length);

        static if (size_t.sizeof < ulong.sizeof)
        {
            enforce(start + length <= size_t.max,
                    "cannot handle zip archives larger than 4 GB on 32bit computers");
            return _data[cast(size_t) start .. cast(size_t) (start + length)];
        }
        else
        {
            return _data[start .. start + length];
        }
    }

    auto getRecord(T)(ulong offset)
    {
        union U
        {
            ubyte[T.sizeof] data;
            T result;
        }

        U tmp;
        tmp.data = getSegment(offset, T.sizeof);
        return tmp.result;
    }
}

debug(print)
{
    @safe void arrayPrint(ubyte[] array)
    {
        printf("array %p,%d\n", cast(void*) array, array.length);
        for (int i = 0; i < array.length; i++)
        {
            printf("%02x ", array[i]);
            if (((i + 1) & 15) == 0)
                printf("\n");
        }
        printf("\n");
    }
}

@system unittest
{
    // @system due to (at least) ZipArchive.build
    auto zip1 = new ZipArchive();
    auto zip2 = new ZipArchive();
    auto am1 = new ArchiveMember();
    am1.name = "foo";
    am1.expandedData = new ubyte[](1024);
    zip1.addMember(am1);
    auto data1 = zip1.build();
    zip2.addMember(zip1.directory["foo"]);
    zip2.build();
    auto am2 = zip2.directory["foo"];
    zip2.expand(am2);
    assert(am1.expandedData == am2.expandedData);
    auto zip3 = new ZipArchive(data1);
    zip3.build();
    assert(zip3.directory["foo"].compressedSize == am1.compressedSize);

    // Test if packing and unpacking produces the original data
    import std.conv, std.stdio;
    import std.random : uniform, MinstdRand0;
    MinstdRand0 gen;
    const uint itemCount = 20, minSize = 10, maxSize = 500;
    foreach (variant; 0 .. 2)
    {
        bool useZip64 = !!variant;
        zip1 = new ZipArchive();
        zip1.isZip64 = useZip64;
        ArchiveMember[itemCount] ams;
        foreach (i; 0 .. itemCount)
        {
            ams[i] = new ArchiveMember();
            ams[i].name = to!string(i);
            ams[i].expandedData = new ubyte[](uniform(minSize, maxSize));
            foreach (ref ubyte c; ams[i].expandedData)
                c = cast(ubyte)(uniform(0, 256));
            ams[i].compressionMethod = CompressionMethod.deflate;
            zip1.addMember(ams[i]);
        }
        auto zippedData = zip1.build();
        zip2 = new ZipArchive(zippedData);
        assert(zip2.isZip64 == useZip64);
        foreach (am; ams)
        {
            am2 = zip2.directory[am.name];
            zip2.expand(am2);
            assert(am.crc32 == am2.crc32);
            assert(am.expandedData == am2.expandedData);
        }
    }
}

@system unittest
{
    import std.conv : to;
    import std.random : Mt19937, randomShuffle;
    // Test if packing and unpacking preserves order.
    auto rand = Mt19937(15966);
    string[] names;
    int value = 0;
    // Generate a series of unique numbers as filenames.
    foreach (i; 0 .. 20)
    {
        value += 1 + rand.front & 0xFFFF;
        rand.popFront;
        names ~= value.to!string;
    }
    // Insert them in a random order.
    names.randomShuffle(rand);
    auto zip1 = new ZipArchive();
    foreach (i, name; names)
    {
        auto member = new ArchiveMember();
        member.name = name;
        member.expandedData = cast(ubyte[]) name;
        member.index = cast(int) i;
        zip1.addMember(member);
    }
    auto data = zip1.build();

    // Ensure that they appear in the same order.
    auto zip2 = new ZipArchive(data);
    foreach (i, name; names)
    {
        const member = zip2.directory[name];
        assert(member.index == i, "member " ~ name ~ " had index " ~
                member.index.to!string ~ " but we expected index " ~ i.to!string ~
                ". The input array was " ~ names.to!string);
    }
}

@system unittest
{
    import std.zlib;

    ubyte[] src = cast(ubyte[])
"the quick brown fox jumps over the lazy dog\r
the quick brown fox jumps over the lazy dog\r
";
    auto dst = cast(ubyte[]) compress(cast(void[]) src);
    auto after = cast(ubyte[]) uncompress(cast(void[]) dst);
    assert(src == after);
}

@system unittest
{
    // @system due to ZipArchive.build
    import std.datetime;
    ubyte[] buf = [1, 2, 3, 4, 5, 0, 7, 8, 9];

    auto ar = new ZipArchive;
    auto am = new ArchiveMember;  // 10
    am.name = "buf";
    am.expandedData = buf;
    am.compressionMethod = CompressionMethod.deflate;
    am.time = SysTimeToDosFileTime(Clock.currTime());
    ar.addMember(am);            // 15

    auto zip1 = ar.build();
    auto arAfter = new ZipArchive(zip1);
    assert(arAfter.directory.length == 1);
    auto amAfter = arAfter.directory["buf"];
    arAfter.expand(amAfter);
    assert(amAfter.name == am.name);
    assert(amAfter.expandedData == am.expandedData);
    assert(amAfter.time == am.time);
}

@system unittest
{
    // invalid format of end of central directory entry
    import std.exception : assertThrown;
    assertThrown!ZipException(new ZipArchive(cast(void[]) "\x50\x4B\x05\x06aaaaaaaaaaaaaaaaaaaa"));
}

@system unittest
{
    // minimum (empty) archive should pass
    auto za = new ZipArchive(cast(void[]) "\x50\x4B\x05\x06\x00\x00\x00\x00\x00\x00\x00"~
                                          "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00");
    assert(za.directory.length == 0);

    // one byte too short or too long should not pass
    import std.exception : assertThrown;
    assertThrown!ZipException(new ZipArchive(cast(void[]) "\x50\x4B\x05\x06\x00\x00\x00\x00\x00\x00\x00"~
                                                          "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"));
    assertThrown!ZipException(new ZipArchive(cast(void[]) "\x50\x4B\x05\x06\x00\x00\x00\x00\x00\x00\x00"~
                                                          "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"));
}

@system unittest
{
    // issue #20239: chameleon file, containing two valid end of central directory entries
    auto file =
        "\x50\x4B\x03\x04\x0A\x00\x00\x00\x00\x00\x89\x36\x39\x4F\x04\x6A\xB3\xA3\x01\x00"~
        "\x00\x00\x01\x00\x00\x00\x0D\x00\x1C\x00\x62\x65\x73\x74\x5F\x6C\x61\x6E\x67\x75"~
        "\x61\x67\x65\x55\x54\x09\x00\x03\x82\xF2\x8A\x5D\x82\xF2\x8A\x5D\x75\x78\x0B\x00"~
        "\x01\x04\xEB\x03\x00\x00\x04\xEB\x03\x00\x00\x44\x50\x4B\x01\x02\x1E\x03\x0A\x00"~
        "\x00\x00\x00\x00\x89\x36\x39\x4F\x04\x6A\xB3\xA3\x01\x00\x00\x00\x01\x00\x00\x00"~
        "\x0D\x00\x18\x00\x00\x00\x00\x00\x01\x00\x00\x00\xB0\x81\x00\x00\x00\x00\x62\x65"~
        "\x73\x74\x5F\x6C\x61\x6E\x67\x75\x61\x67\x65\x55\x54\x05\x00\x03\x82\xF2\x8A\x5D"~
        "\x75\x78\x0B\x00\x01\x04\xEB\x03\x00\x00\x04\xEB\x03\x00\x00\x50\x4B\x05\x06\x00"~
        "\x00\x00\x00\x01\x00\x01\x00\x53\x00\x00\x00\x48\x00\x00\x00\xB7\x00\x50\x4B\x03"~
        "\x04\x0A\x00\x00\x00\x00\x00\x94\x36\x39\x4F\xD7\xCB\x3B\x55\x07\x00\x00\x00\x07"~
        "\x00\x00\x00\x0D\x00\x1C\x00\x62\x65\x73\x74\x5F\x6C\x61\x6E\x67\x75\x61\x67\x65"~
        "\x55\x54\x09\x00\x03\x97\xF2\x8A\x5D\x8C\xF2\x8A\x5D\x75\x78\x0B\x00\x01\x04\xEB"~
        "\x03\x00\x00\x04\xEB\x03\x00\x00\x46\x4F\x52\x54\x52\x41\x4E\x50\x4B\x01\x02\x1E"~
        "\x03\x0A\x00\x00\x00\x00\x00\x94\x36\x39\x4F\xD7\xCB\x3B\x55\x07\x00\x00\x00\x07"~
        "\x00\x00\x00\x0D\x00\x18\x00\x00\x00\x00\x00\x01\x00\x00\x00\xB0\x81\xB1\x00\x00"~
        "\x00\x62\x65\x73\x74\x5F\x6C\x61\x6E\x67\x75\x61\x67\x65\x55\x54\x05\x00\x03\x97"~
        "\xF2\x8A\x5D\x75\x78\x0B\x00\x01\x04\xEB\x03\x00\x00\x04\xEB\x03\x00\x00\x50\x4B"~
        "\x05\x06\x00\x00\x00\x00\x01\x00\x01\x00\x53\x00\x00\x00\xFF\x00\x00\x00\x00\x00";

    import std.exception : assertThrown;
    assertThrown!ZipException(new ZipArchive(cast(void[]) file));
}

@system unittest
{
    // issue #20287: check for correct compressed data
    auto file =
        "\x50\x4b\x03\x04\x0a\x00\x00\x00\x00\x00\x8f\x72\x4a\x4f\x86\xa6"~
        "\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04\x00\x1c\x00\x66\x69"~
        "\x6c\x65\x55\x54\x09\x00\x03\x0d\x22\x9f\x5d\x12\x22\x9f\x5d\x75"~
        "\x78\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x68\x65"~
        "\x6c\x6c\x6f\x50\x4b\x01\x02\x1e\x03\x0a\x00\x00\x00\x00\x00\x8f"~
        "\x72\x4a\x4f\x86\xa6\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04"~
        "\x00\x18\x00\x00\x00\x00\x00\x01\x00\x00\x00\xb0\x81\x00\x00\x00"~
        "\x00\x66\x69\x6c\x65\x55\x54\x05\x00\x03\x0d\x22\x9f\x5d\x75\x78"~
        "\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x50\x4b\x05"~
        "\x06\x00\x00\x00\x00\x01\x00\x01\x00\x4a\x00\x00\x00\x43\x00\x00"~
        "\x00\x00\x00";

    auto za = new ZipArchive(cast(void[]) file);
    assert(za.directory["file"].compressedData == [104, 101, 108, 108, 111]);
}

// issue #20027
@system unittest
{
    // central file header overlaps end of central directory
    auto file =
        // lfh
        "\x50\x4b\x03\x04\x0a\x00\x00\x00\x00\x00\x8f\x72\x4a\x4f\x86\xa6"~
        "\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04\x00\x1c\x00\x66\x69"~
        "\x6c\x65\x55\x54\x09\x00\x03\x0d\x22\x9f\x5d\x12\x22\x9f\x5d\x75"~
        "\x78\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x68\x65"~
        "\x6c\x6c\x6f\x50\x4b\x01\x02\x1e\x03\x0a\x00\x00\x00\x00\x00\x8f"~
        "\x72\x4a\x4f\x86\xa6\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04"~
        "\x00\x18\x00\x04\x00\x00\x00\x01\x00\x00\x00\xb0\x81\x00\x00\x00"~
        "\x00\x66\x69\x6c\x65\x55\x54\x05\x00\x03\x0d\x22\x9f\x5d\x75\x78"~
        "\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x50\x4b\x05"~
        "\x06\x00\x00\x00\x00\x01\x00\x01\x00\x4a\x00\x00\x00\x43\x00\x00"~
        "\x00\x00\x00";

    import std.exception : assertThrown;
    assertThrown!ZipException(new ZipArchive(cast(void[]) file));

    // local file header and file data overlap second local file header and file data
    file =
        "\x50\x4b\x03\x04\x0a\x00\x00\x00\x00\x00\x8f\x72\x4a\x4f\x86\xa6"~
        "\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04\x00\x1e\x00\x66\x69"~
        "\x6c\x65\x55\x54\x09\x00\x03\x0d\x22\x9f\x5d\x12\x22\x9f\x5d\x75"~
        "\x78\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x68\x65"~
        "\x6c\x6c\x6f\x50\x4b\x01\x02\x1e\x03\x0a\x00\x00\x00\x00\x00\x8f"~
        "\x72\x4a\x4f\x86\xa6\x10\x36\x05\x00\x00\x00\x05\x00\x00\x00\x04"~
        "\x00\x18\x00\x04\x00\x00\x00\x01\x00\x00\x00\xb0\x81\x00\x00\x00"~
        "\x00\x66\x69\x6c\x65\x55\x54\x05\x00\x03\x0d\x22\x9f\x5d\x75\x78"~
        "\x0b\x00\x01\x04\xf0\x03\x00\x00\x04\xf0\x03\x00\x00\x50\x4b\x05"~
        "\x06\x00\x00\x00\x00\x01\x00\x01\x00\x4a\x00\x00\x00\x43\x00\x00"~
        "\x00\x00\x00";

    assertThrown!ZipException(new ZipArchive(cast(void[]) file));
}

@system unittest
{
    // issue #20295: zip64 with 0xff bytes in end of central dir record do not work
    // minimum (empty zip64) archive should pass
    auto file =
        "\x50\x4b\x06\x06\x2c\x00\x00\x00\x00\x00\x00\x00\x1e\x03\x2d\x00"~
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"~
        "\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4b\x06\x07\x00\x00\x00\x00"~
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4B\x05\x06"~
        "\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff"~
        "\x00\x00";

    auto za = new ZipArchive(cast(void[]) file);
    assert(za.directory.length == 0);
}

@system unittest
{
    import std.exception : assertThrown;

    // issue #20523: Invalid data yields RangeError in ZipArchive constructor
    auto file = "\x50\x4b\x01\x02\x50\x4b\x05\x06\x00\x00\x00\x00\xff\xff"~
        "\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";

    assertThrown!ZipException(new ZipArchive(cast(void[]) file));
}

// Non-Android POSIX-only, because we can't rely on the unzip command being
// available on Android or Windows
version (Android) {} else
version (Posix) @system unittest
{
    import std.datetime, std.file, std.format, std.path, std.process, std.stdio;

    if (executeShell("unzip").status != 0)
    {
        writeln("Can't run unzip, skipping unzip test");
        return;
    }

    auto zr = new ZipArchive();
    auto am = new ArchiveMember();
    am.compressionMethod = CompressionMethod.deflate;
    am.name = "foo.bar";
    am.time = SysTimeToDosFileTime(Clock.currTime());
    am.expandedData = cast(ubyte[])"We all live in a yellow submarine, a yellow submarine";
    zr.addMember(am);
    auto data2 = zr.build();

    mkdirRecurse(deleteme);
    scope(exit) rmdirRecurse(deleteme);
    string zipFile = buildPath(deleteme, "foo.zip");
    std.file.write(zipFile, cast(byte[]) data2);

    auto result = executeShell(format("unzip -l %s", zipFile));
    scope(failure) writeln(result.output);
    assert(result.status == 0);
}
