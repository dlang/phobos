
module std.zip;

private import std.zlib;
private import std.date;
private import std.intrinsic;

//debug=print;

/* Throw this on errors.
 */

class ZipException : Exception
{
    this(char[] msg)
    {
	super("ZipException: " ~ msg);
    }
}

class ArchiveMember
{
    ushort madeVersion = 20;
    ushort extractVersion = 20;
    ushort flags;
    ushort compressionMethod;
    std.date.DosFileTime time;
    uint crc32;
    uint compressedSize;
    uint expandedSize;
    ushort diskNumber;
    ushort internalAttributes;
    uint externalAttributes;

    private uint offset;

    char[] name;
    ubyte[] extra;
    char[] comment;
    ubyte[] compressedData;
    ubyte[] expandedData;

    debug(print)
    {
    void print()
    {
	printf("name = '%.*s'\n", name);
	printf("\tcomment = '%.*s'\n", comment);
	printf("\tmadeVersion = x%04x\n", madeVersion);
	printf("\textractVersion = x%04x\n", extractVersion);
	printf("\tflags = x%04x\n", flags);
	printf("\tcompressionMethod = %d\n", compressionMethod);
	printf("\ttime = %d\n", time);
	printf("\tcrc32 = x%08x\n", crc32);
	printf("\texpandedSize = %d\n", expandedSize);
	printf("\tcompressedSize = %d\n", compressedSize);
	printf("\tinternalAttributes = x%04x\n", internalAttributes);
	printf("\texternalAttributes = x%08x\n", externalAttributes);
    }
    }
}

class ZipArchive
{
    ubyte[] data;	// representing the entire Zip contents
    uint endrecOffset;

    uint diskNumber;
    uint diskStartDir;
    uint numEntries;
    uint totalEntries;
    char[] comment;
    ArchiveMember[char[]] directory;

    debug (print)
    {
    void print()
    {
	printf("\tdiskNumber = %u\n", diskNumber);
	printf("\tdiskStartDir = %u\n", diskStartDir);
	printf("\tnumEntries = %u\n", numEntries);
	printf("\ttotalEntries = %u\n", totalEntries);
	printf("\tcomment = '%.*s'\n", comment);
    }
    }

    /* ============ Creating a new archive =================== */

    /* Constructor to use when creating a new archive.
     */

    this()
    {
    }

    void addMember(ArchiveMember de)
    {
	directory[de.name] = de;
    }

    void deleteMember(ArchiveMember de)
    {
	delete directory[de.name];
    }

    void[] build()
    {	uint i;
	uint directoryOffset;

	if (comment.length > 0xFFFF)
	    throw new ZipException("archive comment longer than 65535");

	// Compress each member; compute size
	uint archiveSize = 0;
	uint directorySize = 0;
	foreach (ArchiveMember de; directory)
	{
	    de.expandedSize = de.expandedData.length;
	    switch (de.compressionMethod)
	    {
		case 0:
		    de.compressedData = de.expandedData;
		    break;

		case 8:
		    de.compressedData = cast(ubyte[])std.zlib.compress(cast(void[])de.expandedData);
		    de.compressedData = de.compressedData[2 .. de.compressedData.length - 4];
		    break;

		default:
		    throw new ZipException("unsupported compression method");
	    }
	    de.compressedSize = de.compressedData.length;
	    de.crc32 = std.zlib.crc32(0, cast(void[])de.expandedData);

	    archiveSize += 30 + de.name.length +
				de.extra.length +
				de.compressedSize;
	    directorySize += 46 + de.name.length +
				de.extra.length +
				de.comment.length;
	}

	data = new ubyte[archiveSize + directorySize + 22 + comment.length];

	// Populate the data[]

	// Store each archive member
	i = 0;
	foreach (ArchiveMember de; directory)
	{
	    de.offset = i;
	    data[i .. i + 4] = cast(ubyte[])"PK\x03\x04";
	    putUshort(i + 4,  de.extractVersion);
	    putUshort(i + 6,  de.flags);
	    putUshort(i + 8,  de.compressionMethod);
	    putUint  (i + 10, cast(uint)de.time);
	    putUint  (i + 14, de.crc32);
	    putUint  (i + 18, de.compressedSize);
	    putUint  (i + 22, de.expandedData.length);
	    putUshort(i + 26, de.name.length);
	    putUshort(i + 28, de.extra.length);
	    i += 30;

	    data[i .. i + de.name.length] = cast(ubyte[])de.name[];
	    i += de.name.length;
	    data[i .. i + de.extra.length] = cast(ubyte[])de.extra[];
	    i += de.extra.length;
	    data[i .. i + de.compressedSize] = de.compressedData[];
	    i += de.compressedSize;
	}

	// Write directory
	directoryOffset = i;
	numEntries = 0;
	foreach (ArchiveMember de; directory)
	{
	    data[i .. i + 4] = cast(ubyte[])"PK\x01\x02";
	    putUshort(i + 4,  de.madeVersion);
	    putUshort(i + 6,  de.extractVersion);
	    putUshort(i + 8,  de.flags);
	    putUshort(i + 10, de.compressionMethod);
	    putUint  (i + 12, cast(uint)de.time);
	    putUint  (i + 16, de.crc32);
	    putUint  (i + 20, de.compressedSize);
	    putUint  (i + 24, de.expandedSize);
	    putUshort(i + 28, de.name.length);
	    putUshort(i + 30, de.extra.length);
	    putUshort(i + 32, de.comment.length);
	    putUshort(i + 34, de.diskNumber);
	    putUshort(i + 36, de.internalAttributes);
	    putUint  (i + 38, de.externalAttributes);
	    putUint  (i + 42, de.offset);
	    i += 46;

	    data[i .. i + de.name.length] = cast(ubyte[])de.name[];
	    i += de.name.length;
	    data[i .. i + de.extra.length] = cast(ubyte[])de.extra[];
	    i += de.extra.length;
	    data[i .. i + de.comment.length] = cast(ubyte[])de.comment[];
	    i += de.comment.length;
	    numEntries++;
	}
	totalEntries = numEntries;

	// Write end record
	endrecOffset = i;
	data[i .. i + 4] = cast(ubyte[])"PK\x05\x06";
	putUshort(i + 4,  diskNumber);
	putUshort(i + 6,  diskStartDir);
	putUshort(i + 8,  numEntries);
	putUshort(i + 10, totalEntries);
	putUint  (i + 12, directorySize);
	putUint  (i + 16, directoryOffset);
	putUshort(i + 20, comment.length);
	i += 22;

	// Write archive comment
	assert(i + comment.length == data.length);
	data[i .. data.length] = cast(ubyte[])comment[];

	return cast(void[])data;
    }

    /* ============ Reading an existing archive =================== */

    /* Constructor to use when reading an existing archive.
     */

    this(void[] buffer)
    {	int iend;
	int i;
	int endcommentlength;
	uint directorySize;
	uint directoryOffset;

	this.data = cast(ubyte[]) buffer;

	// Find 'end record index' by searching backwards for signature
	iend = data.length - 66000;
	if (iend < 0)
	    iend = 0;
	for (i = data.length - 22; 1; i--)
	{
	    if (i < iend)
		throw new ZipException("no end record");

	    if (data[i .. i + 4] == cast(ubyte[])"PK\x05\x06")
	    {
		endcommentlength = getUshort(i + 20);
		if (i + 22 + endcommentlength > data.length)
		    continue;
		comment = cast(char[])data[i + 22 .. i + 22 + endcommentlength];
		endrecOffset = i;
		break;
	    }
	}

	// Read end record data
	diskNumber = getUshort(i + 4);
	diskStartDir = getUshort(i + 6);

	numEntries = getUshort(i + 8);
	totalEntries = getUshort(i + 10);

	if (numEntries != totalEntries)
	    throw new ZipException("multiple disk zips not supported");

	directorySize = getUint(i + 12);
	directoryOffset = getUint(i + 16);

	if (directoryOffset + directorySize > i)
	    throw new ZipException("corrupted directory");

	i = directoryOffset;
	for (int n = 0; n < numEntries; n++)
	{
	    /* The format of an entry is:
	     *	'PK' 1, 2
	     *	directory info
	     *	path
	     *	extra data
	     *	comment
	     */

	    uint offset;
	    uint namelen;
	    uint extralen;
	    uint commentlen;

	    if (data[i .. i + 4] != cast(ubyte[])"PK\x01\x02")
		throw new ZipException("invalid directory entry 1");
	    ArchiveMember de = new ArchiveMember();
	    de.madeVersion = getUshort(i + 4);
	    de.extractVersion = getUshort(i + 6);
	    de.flags = getUshort(i + 8);
	    de.compressionMethod = getUshort(i + 10);
	    de.time = cast(DosFileTime)getUint(i + 12);
	    de.crc32 = getUint(i + 16);
	    de.compressedSize = getUint(i + 20);
	    de.expandedSize = getUint(i + 24);
	    namelen = getUshort(i + 28);
	    extralen = getUshort(i + 30);
	    commentlen = getUshort(i + 32);
	    de.diskNumber = getUshort(i + 34);
	    de.internalAttributes = getUshort(i + 36);
	    de.externalAttributes = getUint(i + 38);
	    de.offset = getUint(i + 42);
	    i += 46;

	    if (i + namelen + extralen + commentlen > directoryOffset + directorySize)
		throw new ZipException("invalid directory entry 2");

	    de.name = cast(char[])data[i .. i + namelen];
	    i += namelen;
	    de.extra = data[i .. i + extralen];
	    i += extralen;
	    de.comment = cast(char[])data[i .. i + commentlen];
	    i += commentlen;

	    directory[de.name] = de;
	}
	if (i != directoryOffset + directorySize)
	    throw new ZipException("invalid directory entry 3");
    }

    ubyte[] expand(ArchiveMember de)
    {	uint namelen;
	uint extralen;

	if (data[de.offset .. de.offset + 4] != cast(ubyte[])"PK\x03\x04")
	    throw new ZipException("invalid directory entry 4");

	// These values should match what is in the main zip archive directory
	de.extractVersion = getUshort(de.offset + 4);
	de.flags = getUshort(de.offset + 6);
	de.compressionMethod = getUshort(de.offset + 8);
	de.time = cast(DosFileTime)getUint(de.offset + 10);
	de.crc32 = getUint(de.offset + 14);
	de.compressedSize = getUint(de.offset + 18);
	de.expandedSize = getUint(de.offset + 22);
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

	int i;
	i = de.offset + 30 + namelen + extralen;
	if (i + de.compressedSize > endrecOffset)
	    throw new ZipException("invalid directory entry 5");

	de.compressedData = data[i .. i + de.compressedSize];
	debug(print) arrayPrint(de.compressedData);

	switch (de.compressionMethod)
	{
	    case 0:
		de.expandedData = de.compressedData;
		return de.expandedData;

	    case 8:
		// -15 is a magic value used to decompress zip files.
		// It has the effect of not requiring the 2 byte header
		// and 4 byte trailer.
		de.expandedData = cast(ubyte[])std.zlib.uncompress(cast(void[])de.compressedData, de.expandedSize, -15);
		return de.expandedData;

	    default:
		throw new ZipException("unsupported compression method");
	}
    }

    /* ============ Utility =================== */

    ushort getUshort(int i)
    {
	version (LittleEndian)
	{
	    return *cast(ushort *)&data[i];
	}
	else
	{
	    ubyte b0 = data[i];
	    ubyte b1 = data[i + 1];
	    return (b1 << 8) | b0;
	}
    }

    uint getUint(int i)
    {
	version (LittleEndian)
	{
	    return *cast(uint *)&data[i];
	}
	else
	{
	    return bswap(*cast(uint *)&data[i]);
	}
    }

    void putUshort(int i, ushort us)
    {
	version (LittleEndian)
	{
	    *cast(ushort *)&data[i] = us;
	}
	else
	{
	    data[0] = cast(ubyte)us;
	    data[1] = cast(ubyte)(us >> 8);
	}
    }

    void putUint(int i, uint ui)
    {
	version (BigEndian)
	{
	    ui = bswap(ui);
	}
	*cast(uint *)&data[i] = ui;
    }
}

debug(print)
{
    void arrayPrint(ubyte[] array)
    {
	printf("array %p,%d\n", cast(void*)array, array.length);
	for (int i = 0; i < array.length; i++)
	{
	    printf("%02x ", array[i]);
	    if (((i + 1) & 15) == 0)
		printf("\n");
	}
	printf("\n");
    }
}
