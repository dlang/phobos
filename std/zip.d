// Written in the D programming language.

/**
 * Read/write data in the $(LINK2 https://en.wikipedia.org/wiki/Zip_%28file_format%29, zip archive) format.
 * Makes use of the etc.c.zlib compression library.
 *
 * Limitations:
 *      $(UL
 *      $(LI Multi-disk zips not supported.)
 *      $(LI Only Zip version 20 formats are supported.)
 *      $(LI Only supports compression modes 0 (no compression) and 8 (deflate).)
 *      $(LI Does not support encryption.)
 *      )
 *
 * Example:
 * ---
// Read existing zip file.
import std.digest.crc, std.file, std.stdio, std.zip;

void main(string[] args)
{
    // read a zip file into memory
    auto zip = new ZipArchive(read(args[1]));
    writeln("Archive: ", args[1]);
    writefln("%-10s  %-8s  Name", "Length", "CRC-32");
    // iterate over all zip members
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

// Create and write new zip file.
import std.file : write;
import std.string : representation;

void main()
{
    char[] data = "Test data.\n".dup;
    // Create an ArchiveMember for the test file.
    ArchiveMember am = new ArchiveMember();
    am.name = "test.txt";
    am.expandedData(data.representation);
    // Create an archive and add the member.
    ZipArchive zip = new ZipArchive();
    zip.addMember(am);
    // Build the archive
    void[] compressed_data = zip.build();
    // Write to a file
    write("test.zip", compressed_data);
}
 * ---
 *
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

//debug=print;

/** Thrown on error.
 */
class ZipException : Exception
{
    import std.exception : basicExceptionCtors;
    ///
    mixin basicExceptionCtors;
}

/**
 * Compression method used by ArchiveMember
 */
enum CompressionMethod : ushort
{
    none = 0,   /// No compression, just archiving
    deflate = 8 /// Deflate algorithm. Use zlib library to compress
}

/**
 * A member of the ZipArchive.
 */
final class ArchiveMember
{
    import std.conv : to, octal;
    import std.datetime.systime : DosFileTime, SysTime, SysTimeToDosFileTime;

    /**
     * Read/Write: Usually the file name of the archive member; it is used to
     * index the archive directory for the member. Each member must have a unique
     * name[]. Do not change without removing member from the directory first.
     */
    string name;

    ubyte[] extra;              /// Read/Write: extra data for this member.
    string comment;             /// Read/Write: comment associated with this member.

    private ubyte[] _compressedData;
    private ubyte[] _expandedData;
    private uint offset;
    private uint _crc32;
    private uint _compressedSize;
    private uint _expandedSize;
    private CompressionMethod _compressionMethod;
    private ushort _madeVersion = 20;
    private ushort _extractVersion = 20;
    private ushort _diskNumber;
    private uint _externalAttributes;
    private DosFileTime _time;
    // by default, no explicit order goes after explicit order
    private uint _index = uint.max;

    ushort flags;                  /// Read/Write: normally set to 0
    ushort internalAttributes;     /// Read/Write

    /// Read Only
    @property @safe pure nothrow @nogc ushort extractVersion() const { return _extractVersion; }
    /// Read Only: cyclic redundancy check (CRC) value
    @property @safe pure nothrow @nogc uint crc32() const { return _crc32; }

    /// Read Only: size of data of member in compressed form.
    @property @safe pure nothrow @nogc uint compressedSize() const { return _compressedSize; }

    /// Read Only: size of data of member in expanded form.
    @property @safe pure nothrow @nogc uint expandedSize() const { return _expandedSize; }
    /// Read Only: should be 0.
    @property @safe pure nothrow @nogc ushort diskNumber() const { return _diskNumber; }

    /// Read Only: data of member in compressed form.
    @property @safe pure nothrow @nogc ubyte[] compressedData() { return _compressedData; }

    /// Read data of member in uncompressed form.
    @property @safe pure nothrow @nogc ubyte[] expandedData() { return _expandedData; }

    /// Write data of member in uncompressed form.
    @property @safe void expandedData(ubyte[] ed)
    {
        _expandedData = ed;
        _expandedSize  = to!uint(_expandedData.length);

        // Clean old compressed data, if any
        _compressedData.length = 0;
        _compressedSize = 0;
    }

    /**
     * Set the OS specific file attributes, as obtained by
     * $(REF getAttributes, std,file) or $(REF DirEntry.attributes, std,file), for this archive member.
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

    /**
     * Get the OS specific file attributes for the archive member.
     *
     * Returns: The file attributes or 0 if the file attributes were
     * encoded for an incompatible OS (Windows vs. Posix).
     *
     */
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

    /// Set the last modification time for this member.
    @property void time(SysTime time)
    {
        _time = SysTimeToDosFileTime(time);
    }

    /// ditto
    @property void time(DosFileTime time) @safe pure nothrow @nogc
    {
        _time = time;
    }

    /// Get the last modification time for this member.
    @property DosFileTime time() const @safe pure nothrow @nogc
    {
        return _time;
    }

    /**
     * Read compression method used for this member
     * See_Also:
     *     CompressionMethod
     **/
    @property @safe @nogc pure nothrow CompressionMethod compressionMethod() const { return _compressionMethod; }

    /**
     * Write compression method used for this member
     * See_Also:
     *     CompressionMethod
     **/
    @property @safe pure void compressionMethod(CompressionMethod cm)
    {
        if (cm == _compressionMethod) return;

        if (_compressedSize > 0)
            throw new ZipException("Can't change compression method for a compressed element");

        _compressionMethod = cm;
    }

    /**
      * The index of this archive member within the archive.
      */
    @property uint index() const @safe pure nothrow @nogc { return _index; }
    @property uint index(uint value) @safe pure nothrow @nogc { return _index = value; }

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

    enum centralFileHeaderLength = 46;
    enum localFileHeaderLength = 30;
    enum endOfCentralDirLength = 22;
    enum archiveExtraDataLength = 8;
    enum digitalSignatureLength = 6;
    enum zip64EndOfCentralDirLength = 56;
    enum zip64EndOfCentralDirLocatorLength = 20;
    enum dataDescriptorLength = 12;

public:
    string comment;     /// Read/Write: the archive comment. Must be less than 65536 bytes in length.

    private ubyte[] _data;
    private uint endrecOffset;

    private uint _diskNumber;
    private uint _diskStartDir;
    private uint _numEntries;
    private uint _totalEntries;
    private bool _isZip64;
    static const ushort zip64ExtractVersion = 45;

    deprecated("Use digitalSignatureLength instead; will be removed in 2.098.0")
    static const int digiSignLength = 6;
    deprecated("Use zip64EndOfCentralDirLocatorLength instead; will be removed in 2.098.0")
    static const int eocd64LocLength = 20;
    deprecated("Use zip64EndOfCentralDirLength instead; will be removed in 2.098.0")
    static const int eocd64Length = 56;

    private Segment[] _segs;

    /// Read Only: array representing the entire contents of the archive.
    @property @safe @nogc pure nothrow ubyte[] data() { return _data; }

    /// Read Only: 0 since multi-disk zip archives are not supported.
    @property @safe @nogc pure nothrow uint diskNumber() const { return _diskNumber; }

    /// Read Only: 0 since multi-disk zip archives are not supported
    @property @safe @nogc pure nothrow uint diskStartDir() const { return _diskStartDir; }

    /// Read Only: number of ArchiveMembers in the directory.
    @property @safe @nogc pure nothrow uint numEntries() const { return _numEntries; }
    @property @safe @nogc pure nothrow uint totalEntries() const { return _totalEntries; }    /// ditto

    /// True when the archive is in Zip64 format.
    @property @safe @nogc pure nothrow bool isZip64() const { return _isZip64; }

    /// Set this to true to force building a Zip64 archive.
    @property @safe @nogc pure nothrow void isZip64(bool value) { _isZip64 = value; }
    /**
     * Read Only: array indexed by the name of each member of the archive.
     *  All the members of the archive can be accessed with a foreach loop:
     * Example:
     * --------------------
     * ZipArchive archive = new ZipArchive(data);
     * foreach (ArchiveMember am; archive.directory)
     * {
     *     writefln("member name is '%s'", am.name);
     * }
     * --------------------
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

    /** Constructor to use when creating a new archive.
     */
    this() @safe @nogc pure nothrow
    {
    }

    /** Add de to the archive. The file is compressed on the fly.
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

            de._compressedSize = to!uint(de._compressedData.length);
            import std.zlib : crc32;
            () @trusted { de._crc32 = crc32(0, cast(void[]) de._expandedData); }();
        }
        assert(de._compressedData.length == de._compressedSize, "Archive member compressed failed.");
    }

    /** Delete de from the archive.
     */
    @safe void deleteMember(ArchiveMember de)
    {
        _directory.remove(de.name);
    }

    /**
     * Construct an archive out of the current members of the archive.
     *
     * Fills in the properties data[], diskNumber, diskStartDir, numEntries,
     * totalEntries, and directory[].
     * For each ArchiveMember, fills in properties crc32, compressedSize,
     * compressedData[].
     *
     * Returns: array representing the entire archive.
     */
    void[] build() @safe pure
    {
        import std.array : array, uninitializedArray;
        import std.algorithm.sorting : sort;
        import std.string : representation;

        uint i;
        uint directoryOffset;

        if (comment.length > 0xFFFF)
            throw new ZipException("archive comment longer than 65535");

        // Compress each member; compute size
        uint archiveSize = 0;
        uint directorySize = 0;
        auto directory = _directory.byValue.array.sort!((x, y) => x.index < y.index).release;
        foreach (ArchiveMember de; directory)
        {
            if (to!ulong(archiveSize) + localFileHeaderLength + de.name.length + de.extra.length + de.compressedSize
                    + directorySize + centralFileHeaderLength + de.name.length + de.extra.length + de.comment.length
                    + endOfCentralDirLength + comment.length + zip64EndOfCentralDirLocatorLength
                    + zip64EndOfCentralDirLength > uint.max)
                throw new ZipException("zip files bigger than 4 GB are unsupported");

            archiveSize += localFileHeaderLength + de.name.length +
                                de.extra.length +
                                de.compressedSize;
            directorySize += centralFileHeaderLength + de.name.length +
                                de.extra.length +
                                de.comment.length;
        }

        if (!isZip64 && _directory.length > ushort.max)
            _isZip64 = true;
        uint dataSize = archiveSize + directorySize + endOfCentralDirLength + cast(uint) comment.length;
        if (isZip64)
            dataSize += zip64EndOfCentralDirLocatorLength + zip64EndOfCentralDirLength;

        _data = uninitializedArray!(ubyte[])(dataSize);

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
            putUint  (i + 18, de.compressedSize);
            putUint  (i + 22, to!uint(de.expandedSize));
            putUshort(i + 26, cast(ushort) de.name.length);
            putUshort(i + 28, cast(ushort) de.extra.length);
            i += localFileHeaderLength;

            _data[i .. i + de.name.length] = (de.name.representation)[];
            i += de.name.length;
            _data[i .. i + de.extra.length] = (cast(ubyte[]) de.extra)[];
            i += de.extra.length;
            _data[i .. i + de.compressedSize] = de.compressedData[];
            i += de.compressedSize;
        }

        // Write directory
        directoryOffset = i;
        _numEntries = 0;
        foreach (ArchiveMember de; directory)
        {
            _data[i .. i + 4] = centralFileHeaderSignature;
            putUshort(i + 4,  de._madeVersion);
            putUshort(i + 6,  de.extractVersion);
            putUshort(i + 8,  de.flags);
            putUshort(i + 10, de._compressionMethod);
            putUint  (i + 12, cast(uint) de.time);
            putUint  (i + 16, de.crc32);
            putUint  (i + 20, de.compressedSize);
            putUint  (i + 24, de.expandedSize);
            putUshort(i + 28, cast(ushort) de.name.length);
            putUshort(i + 30, cast(ushort) de.extra.length);
            putUshort(i + 32, cast(ushort) de.comment.length);
            putUshort(i + 34, de.diskNumber);
            putUshort(i + 36, de.internalAttributes);
            putUint  (i + 38, de._externalAttributes);
            putUint  (i + 42, de.offset);
            i += centralFileHeaderLength;

            _data[i .. i + de.name.length] = (de.name.representation)[];
            i += de.name.length;
            _data[i .. i + de.extra.length] = (cast(ubyte[]) de.extra)[];
            i += de.extra.length;
            _data[i .. i + de.comment.length] = (de.comment.representation)[];
            i += de.comment.length;
            _numEntries++;
        }
        _totalEntries = numEntries;

        if (isZip64)
        {
            // Write zip64 end of central directory record
            uint eocd64Offset = i;
            _data[i .. i + 4] = zip64EndOfCentralDirSignature;
            putUlong (i + 4,  zip64EndOfCentralDirLength - 12);
            putUshort(i + 12, zip64ExtractVersion);
            putUshort(i + 14, zip64ExtractVersion);
            putUint  (i + 16, diskNumber);
            putUint  (i + 20, diskStartDir);
            putUlong (i + 24, numEntries);
            putUlong (i + 32, totalEntries);
            putUlong (i + 40, directorySize);
            putUlong (i + 48, directoryOffset);
            i += zip64EndOfCentralDirLength;

            // Write zip64 end of central directory record locator
            _data[i .. i + 4] = zip64EndOfCentralDirLocatorSignature;
            putUint  (i + 4,  diskNumber);
            putUlong (i + 8,  eocd64Offset);
            putUint  (i + 16, 1);
            i += zip64EndOfCentralDirLocatorLength;
        }

        // Write end record
        endrecOffset = i;
        _data[i .. i + 4] = endOfCentralDirSignature;
        putUshort(i + 4,  cast(ushort) diskNumber);
        putUshort(i + 6,  cast(ushort) diskStartDir);
        putUshort(i + 8,  (numEntries > ushort.max ? ushort.max : cast(ushort) numEntries));
        putUshort(i + 10, (totalEntries > ushort.max ? ushort.max : cast(ushort) totalEntries));
        putUint  (i + 12, directorySize);
        putUint  (i + 16, directoryOffset);
        putUshort(i + 20, cast(ushort) comment.length);
        i += endOfCentralDirLength;

        // Write archive comment
        assert(i + comment.length == data.length, "Writing the archive comment failed.");
        _data[i .. data.length] = (comment.representation)[];

        return cast(void[]) data;
    }

    /* ============ Reading an existing archive =================== */

    /**
     * Constructor to use when reading an existing archive.
     *
     * Fills in the properties data[], diskNumber, diskStartDir, numEntries,
     * totalEntries, comment[], and directory[].
     * For each ArchiveMember, fills in
     * properties madeVersion, extractVersion, flags, compressionMethod, time,
     * crc32, compressedSize, expandedSize, compressedData[], diskNumber,
     * internalAttributes, externalAttributes, name[], extra[], comment[].
     * Use expand() to get the expanded data for each ArchiveMember.
     *
     * Params:
     *  buffer = the entire contents of the archive.
     */

    this(void[] buffer)
    {
        this._data = cast(ubyte[]) buffer;

        if (data.length > uint.max - 2)
            throw new ZipException("zip files bigger than 4 GB are unsupported");

        _segs = [Segment(0, cast(uint) data.length)];

        findEndOfCentralDirRecord();
        uint i = endrecOffset;

        int endCommentLength = getUshort(i + 20);
        comment = cast(string)(_data[i + 22 .. i + 22 + endCommentLength]);

        // end of central dir record
        removeSegment(endrecOffset, endrecOffset + endOfCentralDirLength + endCommentLength);

        uint k = i - zip64EndOfCentralDirLocatorLength;
        if (k < i && _data[k .. k + 4] == cast(ubyte[])"PK\x06\x07")
        {
            _isZip64 = true;
            i = k;

            // zip64 end of central dir record locator
            removeSegment(k, k + zip64EndOfCentralDirLocatorLength);
        }

        uint directorySize;
        uint directoryOffset;

        if (isZip64)
        {
            // Read Zip64 record data
            ulong eocdOffset = getUlong(i + 8);
            if (eocdOffset + zip64EndOfCentralDirLength > _data.length)
                throw new ZipException("corrupted directory");

            i = to!uint(eocdOffset);
            if (_data[i .. i + 4] != zip64EndOfCentralDirSignature)
                throw new ZipException("invalid Zip EOCD64 signature");

            ulong eocd64Size = getUlong(i + 4);
            if (eocd64Size + i - 12 > data.length)
                throw new ZipException("invalid Zip EOCD64 size");

            // zip64 end of central dir record
            removeSegment(i, cast(uint) (i + 12 + eocd64Size));

            _diskNumber = getUint(i + 16);
            _diskStartDir = getUint(i + 20);

            ulong numEntriesUlong = getUlong(i + 24);
            ulong totalEntriesUlong = getUlong(i + 32);
            ulong directorySizeUlong = getUlong(i + 40);
            ulong directoryOffsetUlong = getUlong(i + 48);

            if (numEntriesUlong > uint.max)
                throw new ZipException("supposedly more than 4294967296 files in archive");

            if (numEntriesUlong != totalEntriesUlong)
                throw new ZipException("multiple disk zips not supported");

            if (directorySizeUlong > i || directoryOffsetUlong > i
                    || directorySizeUlong + directoryOffsetUlong > i)
                throw new ZipException("corrupted directory");

            _numEntries = to!uint(numEntriesUlong);
            _totalEntries = to!uint(totalEntriesUlong);
            directorySize = to!uint(directorySizeUlong);
            directoryOffset = to!uint(directoryOffsetUlong);
        }
        else
        {
            // Read end record data
            _diskNumber = getUshort(i + 4);
            _diskStartDir = getUshort(i + 6);

            _numEntries = getUshort(i + 8);
            _totalEntries = getUshort(i + 10);

            if (numEntries != totalEntries)
                throw new ZipException("multiple disk zips not supported");

            directorySize = getUint(i + 12);
            directoryOffset = getUint(i + 16);

            if (directoryOffset + directorySize > i)
                throw new ZipException("corrupted directory");
        }

        i = directoryOffset;
        for (int n = 0; n < numEntries; n++)
        {
            /* The format of an entry is:
             *  'PK' 1, 2
             *  directory info
             *  path
             *  extra data
             *  comment
             */

            uint namelen;
            uint extralen;
            uint commentlen;

            if (_data[i .. i + 4] != centralFileHeaderSignature)
                throw new ZipException("invalid directory entry 1");
            ArchiveMember de = new ArchiveMember();
            de._index = n;
            de._madeVersion = getUshort(i + 4);
            de._extractVersion = getUshort(i + 6);
            de.flags = getUshort(i + 8);
            de._compressionMethod = cast(CompressionMethod) getUshort(i + 10);
            de.time = cast(DosFileTime) getUint(i + 12);
            de._crc32 = getUint(i + 16);
            de._compressedSize = getUint(i + 20);
            de._expandedSize = getUint(i + 24);
            namelen = getUshort(i + 28);
            extralen = getUshort(i + 30);
            commentlen = getUshort(i + 32);
            de._diskNumber = getUshort(i + 34);
            de.internalAttributes = getUshort(i + 36);
            de._externalAttributes = getUint(i + 38);
            de.offset = getUint(i + 42);

            // central directory header
            removeSegment(i, i + centralFileHeaderLength + namelen + extralen + commentlen);

            i += centralFileHeaderLength;

            if (i + namelen + extralen + commentlen > directoryOffset + directorySize)
                throw new ZipException("invalid directory entry 2");

            de.name = cast(string)(_data[i .. i + namelen]);
            i += namelen;
            de.extra = _data[i .. i + extralen];
            i += extralen;
            de.comment = cast(string)(_data[i .. i + commentlen]);
            i += commentlen;

            auto localFileHeaderNamelen = getUshort(de.offset + 26);
            auto localFileHeaderExtralen = getUshort(de.offset + 28);

            // file data
            removeSegment(de.offset, de.offset + localFileHeaderLength + localFileHeaderNamelen
                                     + localFileHeaderExtralen + de._compressedSize);

            immutable uint dataOffset = de.offset + localFileHeaderLength
                                        + localFileHeaderNamelen + localFileHeaderExtralen;
            if (dataOffset + de.compressedSize > endrecOffset)
                throw new ZipException("Invalid directory entry offset or size.");
            de._compressedData = _data[dataOffset .. dataOffset + de.compressedSize];

            _directory[de.name] = de;

        }
        if (i != directoryOffset + directorySize)
            throw new ZipException("invalid directory entry 3");
    }

    private void findEndOfCentralDirRecord()
    {
        // end of central dir record can be followed by a comment of up to 2^^16-1 bytes
        // therefore we have to scan 2^^16 positions

        endrecOffset = to!uint(data.length);
        foreach (i; 0 .. 2 ^^ 16)
        {
            if (endOfCentralDirLength + i > data.length) break;
            uint start = to!uint(data.length) - endOfCentralDirLength - i;

            if (data[start .. start + 4] != cast(ubyte[])"PK\x05\x06") continue;

            auto numberOfThisDisc = getUshort(start + 4);
            if (numberOfThisDisc != 0) continue; // no support for multiple volumes yet

            auto numberOfStartOfCentralDirectory = getUshort(start + 6);
            if (numberOfStartOfCentralDirectory != 0) continue; // dito

            if (numberOfThisDisc < numberOfStartOfCentralDirectory) continue;

            uint k = start - zip64EndOfCentralDirLocatorLength;
            auto maybeZip64 = k < start && _data[k .. k + 4] == cast(ubyte[])"PK\x06\x07";

            auto totalNumberOfEntriesOnThisDisk = getUshort(start + 8);
            auto totalNumberOfEntriesInCentralDir = getUshort(start + 10);

            if (totalNumberOfEntriesOnThisDisk > totalNumberOfEntriesInCentralDir &&
               (!maybeZip64 || totalNumberOfEntriesOnThisDisk < 0xffff)) continue;

            auto sizeOfCentralDirectory = getUint(start + 12);
            if (sizeOfCentralDirectory > start &&
               (!maybeZip64 || sizeOfCentralDirectory < 0xffff)) continue;

            auto offsetOfCentralDirectory = getUint(start + 16);
            if (offsetOfCentralDirectory > start - sizeOfCentralDirectory &&
               (!maybeZip64 || offsetOfCentralDirectory < 0xffff)) continue;

            auto zipfileCommentLength = getUshort(start + 20);
            if (start + zipfileCommentLength + endOfCentralDirLength != data.length) continue;

            if (endrecOffset != to!uint(data.length))
                throw new ZipException("found more than one valid 'end of central dir record'");

            endrecOffset = start;
        }

        if (endrecOffset == to!uint(data.length))
            throw new ZipException("found no valid 'end of central dir record'");
    }

    /*****
     * Decompress the contents of archive member de and return the expanded
     * data.
     *
     * Fills in properties extractVersion, flags, compressionMethod, time,
     * crc32, compressedSize, expandedSize, expandedData[], name[], extra[].
     */
    ubyte[] expand(ArchiveMember de)
    {
        import std.string : representation;

        uint namelen;
        uint extralen;

        if (_data[de.offset .. de.offset + 4] != localFileHeaderSignature)
            throw new ZipException("invalid directory entry 4");

        // These values should match what is in the main zip archive directory
        de._extractVersion = getUshort(de.offset + 4);
        de.flags = getUshort(de.offset + 6);
        de._compressionMethod = cast(CompressionMethod) getUshort(de.offset + 8);
        de.time = cast(DosFileTime) getUint(de.offset + 10);
        de._crc32 = getUint(de.offset + 14);
        de._compressedSize = max(getUint(de.offset + 18), de.compressedSize);
        de._expandedSize = max(getUint(de.offset + 22), de.expandedSize);
        namelen = getUshort(de.offset + 26);
        extralen = getUshort(de.offset + 28);

        debug(print)
        {
            printf("\t\texpandedSize = %d\n", de.expandedSize);
            printf("\t\tcompressedSize = %d\n", de.compressedSize);
            printf("\t\tnamelen = %d\n", namelen);
            printf("\t\textralen = %d\n", extralen);
        }

        if (de.flags & 1)
            throw new ZipException("encryption not supported");

        uint i;
        i = de.offset + localFileHeaderLength + namelen + extralen;
        if (i + de.compressedSize > endrecOffset)
            throw new ZipException("invalid directory entry 5");

        de._compressedData = _data[i .. i + de.compressedSize];
        debug(print) arrayPrint(de.compressedData);

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
                de._expandedData = cast(ubyte[]) uncompress(cast(void[]) de.compressedData, de.expandedSize, -15);
                return de.expandedData;

            default:
                throw new ZipException("unsupported compression method");
        }
    }

    /* ============ Utility =================== */

    @safe @nogc pure nothrow ushort getUshort(uint i)
    {
        ubyte[2] result = data[i .. i + 2];
        return littleEndianToNative!ushort(result);
    }

    @safe @nogc pure nothrow uint getUint(uint i)
    {
        ubyte[4] result = data[i .. i + 4];
        return littleEndianToNative!uint(result);
    }

    @safe @nogc pure nothrow ulong getUlong(uint i)
    {
        ubyte[8] result = data[i .. i + 8];
        return littleEndianToNative!ulong(result);
    }

    @safe @nogc pure nothrow void putUshort(uint i, ushort us)
    {
        data[i .. i + 2] = nativeToLittleEndian(us);
    }

    @safe @nogc pure nothrow void putUint(uint i, uint ui)
    {
        data[i .. i + 4] = nativeToLittleEndian(ui);
    }

    @safe @nogc pure nothrow void putUlong(uint i, ulong ul)
    {
        data[i .. i + 8] = nativeToLittleEndian(ul);
    }

    /* ============== for detecting overlaps =============== */

private:

    // defines a segment of the zip file, including start, excluding end
    struct Segment
    {
        uint start;
        uint end;
    }

    // removes Segment start .. end from _segs
    // throws zipException if start .. end is not completely available in _segs;
    void removeSegment(uint start, uint end) pure @safe
    in (start < end, "segment invalid")
    {
        auto found = false;
        size_t pos;
        foreach (i,seg;_segs)
            if (seg.start <= start && seg.end >= end
                && (!found || seg.start > _segs[pos].start))
            {
                found = true;
                pos = i;
            }

        if (!found)
            throw new ZipException("overlapping data detected");

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

// Non-Android Posix-only, because we can't rely on the unzip command being
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
