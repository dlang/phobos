/* zlib.d
 * A D interface to the zlib library, www.gzip.org/zlib
 */


module std.zlib;

//debug=zlib;		// uncomment to turn on debugging printf's

private import etc.c.zlib;

// Values for 'mode'

enum
{
	Z_NO_FLUSH      = 0,
	Z_SYNC_FLUSH    = 2,
	Z_FULL_FLUSH    = 3,
	Z_FINISH        = 4,
}

/*************************************
 * Errors throw a ZlibException.
 */

class ZlibException : Exception
{
    this(int errnum)
    {	char[] msg;

	switch (errnum)
	{
	    case Z_STREAM_END:		msg = "stream end"; break;
	    case Z_NEED_DICT:		msg = "need dict"; break;
	    case Z_ERRNO:		msg = "errno"; break;
	    case Z_STREAM_ERROR:	msg = "stream error"; break;
	    case Z_DATA_ERROR:		msg = "data error"; break;
	    case Z_MEM_ERROR:		msg = "mem error"; break;
	    case Z_BUF_ERROR:		msg = "buf error"; break;
	    case Z_VERSION_ERROR:	msg = "version error"; break;
	    default:			msg = "unknown error";	break;
	}
	super(msg);
    }
}

/**************************************************
 */

uint adler32(uint adler, void[] buf)
{
    return etc.c.zlib.adler32(adler, (ubyte *)buf, buf.length);
}

unittest
{
    static ubyte[] data = [1,2,3,4,5,6,7,8,9,10];

    uint adler;

    debug(zlib) printf("D.zlib.adler32.unittest\n");
    adler = adler32(0u, (void[])data);
    debug(zlib) printf("adler = %x\n", adler);
    assert(adler == 0xdc0037);
}

/*********************************
 */

uint crc32(uint crc, void[] buf)
{
    return etc.c.zlib.crc32(crc, (ubyte *)buf, buf.length);
}

unittest
{
    static ubyte[] data = [1,2,3,4,5,6,7,8,9,10];

    uint crc;

    debug(zlib) printf("D.zlib.crc32.unittest\n");
    crc = crc32(0u, (void[])data);
    debug(zlib) printf("crc = %x\n", crc);
    assert(crc == 0x2520577b);
}

/*********************************************
 */

void[] compress(void[] srcbuf, int level)
in
{
    assert(-1 <= level && level <= 9);
}
body
{
    int err;
    void[] destbuf;
    uint destlen;

    destlen = srcbuf.length + ((srcbuf.length + 1023) / 1024) + 12;
    destbuf = new void[destlen];
    err = etc.c.zlib.compress2((ubyte *)destbuf, &destlen, (ubyte *)srcbuf, srcbuf.length, level);
    if (err)
    {	delete destbuf;
	throw new ZlibException(err);
    }

    destbuf.length = destlen;
    return destbuf;
}

/*********************************************
 */

void[] compress(void[] buf)
{
    return compress(buf, Z_DEFAULT_COMPRESSION);
}

/*********************************************
 */

void[] uncompress(void[] srcbuf)
{
    return uncompress(srcbuf, 0, 15);
}

void[] uncompress(void[] srcbuf, uint destlen)
{
    return uncompress(srcbuf, destlen, 15);
}

void[] uncompress(void[] srcbuf, uint destlen, int winbits)
{
    int err;
    void[] destbuf;

    if (!destlen)
	destlen = srcbuf.length * 2 + 1;

    while (1)
    {
	etc.c.zlib.z_stream zs;

	destbuf = new void[destlen];

	zs.next_in = (ubyte*) srcbuf;
	zs.avail_in = srcbuf.length;

	zs.next_out = (ubyte*)destbuf;
	zs.avail_out = destlen;

	err = etc.c.zlib.inflateInit2(&zs, winbits);
	if (err)
	{   delete destbuf;
	    throw new ZlibException(err);
	}
	err = etc.c.zlib.inflate(&zs, Z_FINISH);
	switch (err)
	{
	    case Z_OK:
		etc.c.zlib.inflateEnd(&zs);
		destlen = destbuf.length * 2;
		continue;

	    case Z_STREAM_END:
		destbuf.length = zs.total_out;
		err = etc.c.zlib.inflateEnd(&zs);
		if (err != Z_OK)
		    goto Lerr;
		return destbuf;

	    default:
		etc.c.zlib.inflateEnd(&zs);
	    Lerr:
		delete destbuf;
		throw new ZlibException(err);
	}
    }
}

unittest
{
    ubyte[] src = cast(ubyte[])
"the quick brown fox jumps over the lazy dog\r
the quick brown fox jumps over the lazy dog\r
";
    ubyte[] dst;
    ubyte[] result;

    //arrayPrint(src);
    dst = cast(ubyte[])compress(cast(void[])src);
    //arrayPrint(dst);
    result = cast(ubyte[])uncompress(cast(void[])dst);
    //arrayPrint(result);
    assert(result == src);
}

/+
void arrayPrint(ubyte[] array)
{
    //printf("array %p,%d\n", (void*)array, array.length);
    for (int i = 0; i < array.length; i++)
    {
	printf("%02x ", array[i]);
	if (((i + 1) & 15) == 0)
	    printf("\n");
    }
    printf("\n\n");
}
+/

/*********************************************
 */

class Compress
{
  private:
    z_stream zs;
    int level = Z_DEFAULT_COMPRESSION;
    int inited;

    void error(int err)
    {
	if (inited)
	{   deflateEnd(&zs);
	    inited = 0;
	}
	throw new ZlibException(err);
    }

  public:
    this()
    {
    }

    this(int level)
    in
    {
	assert(1 <= level && level <= 9);
    }
    body
    {
	this.level = level;
    }

    ~this()
    {	int err;

	if (inited)
	{
	    inited = 0;
	    err = deflateEnd(&zs);
	    if (err)
		error(err);
	}
    }

    void[] compress(void[] buf)
    {	int err;
	void[] destbuf;

	if (buf.length == 0)
	    return null;

	if (!inited)
	{
	    err = deflateInit(&zs, level);
	    if (err)
		error(err);
	    inited = 1;
	}

	destbuf = new void[zs.avail_in + buf.length];
	zs.next_out = (ubyte*) destbuf;
	zs.avail_out = destbuf.length;

	if (zs.avail_in)
	    buf = cast(void[])zs.next_in[0 .. zs.avail_in] ~ buf;

	zs.next_in = (ubyte*) buf;
	zs.avail_in = buf.length;

	err = deflate(&zs, Z_NO_FLUSH);
	if (err != Z_STREAM_END && err != Z_OK)
	{   delete destbuf;
	    error(err);
	}
	destbuf.length = zs.total_out;
	return destbuf;
    }

    void[] flush()
    {
	return flush(Z_FINISH);
    }

    void[] flush(int mode)
    in
    {
	assert(mode == Z_FINISH || mode == Z_SYNC_FLUSH || mode == Z_FULL_FLUSH);
    }
    body
    {
	void[] destbuf;
	int err;

	if (!inited)
	    return null;

	destbuf = new void[zs.avail_in];
	zs.next_out = (ubyte*) destbuf;
	zs.avail_out = destbuf.length;

	err = deflate(&zs, mode);
	if (err != Z_STREAM_END)
	{
	    delete destbuf;
	    if (err == Z_OK)
		err = Z_BUF_ERROR;
	    error(err);
	}
	destbuf = (void[])(((ubyte *)destbuf)[0 .. zs.next_out - (ubyte*)destbuf]);
	if (mode == Z_FINISH)
	{
	    err = deflateEnd(&zs);
	    inited = 0;
	    if (err)
		error(err);
	}
	return destbuf;
    }
}

class UnCompress
{
  private:
    z_stream zs;
    int inited;
    int done;
    uint destbufsize;

    void error(int err)
    {
	if (inited)
	{   inflateEnd(&zs);
	    inited = 0;
	}
	throw new ZlibException(err);
    }

  public:
    this()
    {
    }

    this(uint destbufsize)
    {
	this.destbufsize = destbufsize;
    }

    ~this()
    {	int err;

	if (inited)
	{
	    inited = 0;
	    err = inflateEnd(&zs);
	    if (err)
		error(err);
	}
	done = 1;
    }

    void[] uncompress(void[] buf)
    in
    {
	assert(!done);
    }
    body
    {	int err;
	void[] destbuf;

	if (buf.length == 0)
	    return null;

	if (!inited)
	{
	    err = inflateInit(&zs);
	    if (err)
		error(err);
	    inited = 1;
	}

	if (!destbufsize)
	    destbufsize = buf.length * 2;
	destbuf = new void[zs.avail_in * 2 + destbufsize];
	zs.next_out = (ubyte*) destbuf;
	zs.avail_out = destbuf.length;

	if (zs.avail_in)
	    buf = cast(void[])zs.next_in[0 .. zs.avail_in] ~ buf;

	zs.next_in = (ubyte*) buf;
	zs.avail_in = buf.length;

	err = inflate(&zs, Z_NO_FLUSH);
	if (err != Z_STREAM_END && err != Z_OK)
	{   delete destbuf;
	    error(err);
	}
	destbuf.length = zs.total_out;
	return destbuf;
    }

    void[] flush()
    in
    {
	assert(!done);
    }
    out
    {
	assert(done);
    }
    body
    {
	void[] extra;
	void[] destbuf;
	int err;

	done = 1;
	if (!inited)
	    return null;

      L1:
	destbuf = new void[zs.avail_in * 2 + 100];
	zs.next_out = (ubyte*) destbuf;
	zs.avail_out = destbuf.length;

	err = etc.c.zlib.inflate(&zs, Z_NO_FLUSH);
	if (err == Z_OK && zs.avail_out == 0)
	{
	    extra ~= destbuf;
	    goto L1;
	}
	if (err != Z_STREAM_END)
	{
	    delete destbuf;
	    if (err == Z_OK)
		err = Z_BUF_ERROR;
	    error(err);
	}
	destbuf = (void[])(((ubyte*)destbuf)[0 .. zs.next_out - (ubyte*)destbuf]);
	err = etc.c.zlib.inflateEnd(&zs);
	inited = 0;
	if (err)
	    error(err);
	if (extra.length)
	    destbuf = extra ~ destbuf;
	return destbuf;
    }
}
