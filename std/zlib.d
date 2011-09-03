// Written in the D programming language.

/**
 * Compress/decompress data using the $(LINK2 http://www._zlib.net, zlib library).
 *
 * References:
 *  $(LINK2 http://en.wikipedia.org/wiki/Zlib, Wikipedia)
 *
 * Macros:
 *  WIKI = Phobos/StdZlib
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(PHOBOSSRC std/_zlib.d)
 */
/*          Copyright Digital Mars 2000 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.zlib;

//debug=zlib;       // uncomment to turn on debugging printf's

private import etc.c.zlib, std.conv;

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
    {   string msg;

        switch (errnum)
        {
            case Z_STREAM_END:      msg = "stream end"; break;
            case Z_NEED_DICT:       msg = "need dict"; break;
            case Z_ERRNO:           msg = "errno"; break;
            case Z_STREAM_ERROR:    msg = "stream error"; break;
            case Z_DATA_ERROR:      msg = "data error"; break;
            case Z_MEM_ERROR:       msg = "mem error"; break;
            case Z_BUF_ERROR:       msg = "buf error"; break;
            case Z_VERSION_ERROR:   msg = "version error"; break;
            default:                msg = "unknown error";  break;
        }
        super(msg);
    }
}

/**************************************************
 * Compute the Adler32 checksum of the data in buf[]. adler is the starting
 * value when computing a cumulative checksum.
 */

uint adler32(uint adler, const(void)[] buf)
{
    return etc.c.zlib.adler32(adler, cast(ubyte *)buf.ptr,
            to!uint(buf.length));
}

unittest
{
    static ubyte[] data = [1,2,3,4,5,6,7,8,9,10];

    uint adler;

    debug(zlib) printf("D.zlib.adler32.unittest\n");
    adler = adler32(0u, cast(void[])data);
    debug(zlib) printf("adler = %x\n", adler);
    assert(adler == 0xdc0037);
}

/*********************************
 * Compute the CRC32 checksum of the data in buf[]. crc is the starting value
 * when computing a cumulative checksum.
 */

uint crc32(uint crc, const(void)[] buf)
{
    return etc.c.zlib.crc32(crc, cast(ubyte *)buf.ptr, to!uint(buf.length));
}

unittest
{
    static ubyte[] data = [1,2,3,4,5,6,7,8,9,10];

    uint crc;

    debug(zlib) printf("D.zlib.crc32.unittest\n");
    crc = crc32(0u, cast(void[])data);
    debug(zlib) printf("crc = %x\n", crc);
    assert(crc == 0x2520577b);
}

/*********************************************
 * Compresses the data in srcbuf[] using compression _level level.
 * The default value
 * for level is 6, legal values are 1..9, with 1 being the least compression
 * and 9 being the most.
 * Returns the compressed data.
 */

const(void)[] compress(const(void)[] srcbuf, int level)
in
{
    assert(-1 <= level && level <= 9);
}
body
{
    auto destlen = srcbuf.length + ((srcbuf.length + 1023) / 1024) + 12;
    auto destbuf = new ubyte[destlen];
    auto err = etc.c.zlib.compress2(destbuf.ptr, &destlen, cast(ubyte *)srcbuf.ptr, srcbuf.length, level);
    if (err)
    {   delete destbuf;
        throw new ZlibException(err);
    }

    destbuf.length = destlen;
    return destbuf;
}

/*********************************************
 * ditto
 */

const(void)[] compress(const(void)[] buf)
{
    return compress(buf, Z_DEFAULT_COMPRESSION);
}

/*********************************************
 * Decompresses the data in srcbuf[].
 * Params: destlen = size of the uncompressed data.
 * It need not be accurate, but the decompression will be faster if the exact
 * size is supplied.
 * Returns: the decompressed data.
 */

void[] uncompress(void[] srcbuf, size_t destlen = 0u, int winbits = 15)
{
    int err;
    ubyte[] destbuf;

    if (!destlen)
        destlen = srcbuf.length * 2 + 1;

    while (1)
    {
        etc.c.zlib.z_stream zs;

        destbuf = new ubyte[destlen];

        zs.next_in = cast(ubyte*) srcbuf;
        zs.avail_in = to!uint(srcbuf.length);

        zs.next_out = destbuf.ptr;
        zs.avail_out = cast(typeof(zs.avail_out))destlen;

        err = etc.c.zlib.inflateInit2(&zs, winbits);
        if (err)
        {   delete destbuf;
            throw new ZlibException(err);
        }
        err = etc.c.zlib.inflate(&zs, Z_NO_FLUSH);
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
    assert(0);
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
    //printf("array %p,%d\n", cast(void*)array, array.length);
    for (size_t i = 0; i < array.length; i++)
    {
        printf("%02x ", array[i]);
        if (((i + 1) & 15) == 0)
            printf("\n");
    }
    printf("\n\n");
}
+/

/// the header format the compressed stream is wrapped in
enum HeaderFormat {
    deflate, /// a standard zlib header
    gzip, /// a gzip file format header
    determineFromData /// used when decompressing. Try to automatically detect the stream format by looking at the data
}

/*********************************************
 * Used when the data to be compressed is not all in one buffer.
 */

class Compress
{
  private:
    z_stream zs;
    int level = Z_DEFAULT_COMPRESSION;
    int inited;
    immutable bool gzip;

    void error(int err)
    {
        if (inited)
        {   deflateEnd(&zs);
            inited = 0;
        }
        throw new ZlibException(err);
    }

  public:

    /**
     * Construct. level is the same as for D.zlib.compress(). header can be used to make a gzip compatible stream.
     */
    this(int level, HeaderFormat header = HeaderFormat.deflate)
    in
    {
        assert(1 <= level && level <= 9);
    }
    body
    {
        this.level = level;
        this.gzip = header == HeaderFormat.gzip;
    }

    /// ditto
    this(HeaderFormat header = HeaderFormat.deflate)
    {
        this.gzip = header == HeaderFormat.gzip;
    }

    ~this()
    {   int err;

        if (inited)
        {
            inited = 0;
            err = deflateEnd(&zs);
            if (err)
                error(err);
        }
    }

    /**
     * Compress the data in buf and return the compressed data.
     * The buffers
     * returned from successive calls to this should be concatenated together.
     */
    const(void)[] compress(const(void)[] buf)
    {   int err;
        ubyte[] destbuf;

        if (buf.length == 0)
            return null;

        if (!inited)
        {
            err = deflateInit2(&zs, level, Z_DEFLATED, 15 + (gzip ? 16 : 0), 8, Z_DEFAULT_STRATEGY);
            if (err)
                error(err);
            inited = 1;
        }

        destbuf = new ubyte[zs.avail_in + buf.length];
        zs.next_out = destbuf.ptr;
        zs.avail_out = to!uint(destbuf.length);

        if (zs.avail_in)
            buf = zs.next_in[0 .. zs.avail_in] ~ cast(ubyte[]) buf;

        zs.next_in = cast(ubyte*) buf.ptr;
        zs.avail_in = to!uint(buf.length);

        err = deflate(&zs, Z_NO_FLUSH);
        if (err != Z_STREAM_END && err != Z_OK)
        {   delete destbuf;
            error(err);
        }
        destbuf.length = destbuf.length - zs.avail_out;
        return destbuf;
    }

    /***
     * Compress and return any remaining data.
     * The returned data should be appended to that returned by compress().
     * Params:
     *  mode = one of the following:
     *          $(DL
                    $(DT Z_SYNC_FLUSH )
                    $(DD Syncs up flushing to the next byte boundary.
                        Used when more data is to be compressed later on.)
                    $(DT Z_FULL_FLUSH )
                    $(DD Syncs up flushing to the next byte boundary.
                        Used when more data is to be compressed later on,
                        and the decompressor needs to be restartable at this
                        point.)
                    $(DT Z_FINISH)
                    $(DD (default) Used when finished compressing the data. )
                )
     */
    void[] flush(int mode = Z_FINISH)
    in
    {
        assert(mode == Z_FINISH || mode == Z_SYNC_FLUSH || mode == Z_FULL_FLUSH);
    }
    body
    {
        ubyte[] destbuf;
        ubyte[512] tmpbuf = void;
        int err;

        if (!inited)
            return null;

        /* may be  zs.avail_out+<some constant>
         * zs.avail_out is set nonzero by deflate in previous compress()
         */
        //tmpbuf = new void[zs.avail_out];
        zs.next_out = tmpbuf.ptr;
        zs.avail_out = tmpbuf.length;

        while( (err = deflate(&zs, mode)) != Z_STREAM_END)
        {
            if (err == Z_OK)
            {
                if (zs.avail_out != 0 && mode != Z_FINISH)
                    break;
                else if(zs.avail_out == 0)
                {
                    destbuf ~= tmpbuf;
                    zs.next_out = tmpbuf.ptr;
                    zs.avail_out = tmpbuf.length;
                    continue;
                }
                err = Z_BUF_ERROR;
            }
            delete destbuf;
            error(err);
        }
        destbuf ~= tmpbuf[0 .. (tmpbuf.length - zs.avail_out)];

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

/******
 * Used when the data to be decompressed is not all in one buffer.
 */

class UnCompress
{
  private:
    z_stream zs;
    int inited;
    int done;
    size_t destbufsize;

    HeaderFormat format;

    void error(int err)
    {
        if (inited)
        {   inflateEnd(&zs);
            inited = 0;
        }
        throw new ZlibException(err);
    }

  public:

    /**
     * Construct. destbufsize is the same as for D.zlib.uncompress().
     */
    this(uint destbufsize)
    {
        this.destbufsize = destbufsize;
    }

    /** ditto */
    this(HeaderFormat format = HeaderFormat.determineFromData)
    {
        this.format = format;
    }

    ~this()
    {   int err;

        if (inited)
        {
            inited = 0;
            err = inflateEnd(&zs);
            if (err)
                error(err);
        }
        done = 1;
    }

    /**
     * Decompress the data in buf and return the decompressed data.
     * The buffers returned from successive calls to this should be concatenated
     * together.
     */
    const(void)[] uncompress(const(void)[] buf)
    in
    {
        assert(!done);
    }
    body
    {   int err;
        ubyte[] destbuf;

        if (buf.length == 0)
            return null;

        if (!inited)
        {
	    int windowBits = 15;
	    if(format == HeaderFormat.gzip)
	        windowBits += 16;
            else if(format == HeaderFormat.determineFromData)
	        windowBits += 32;

            err = inflateInit2(&zs, windowBits);
            if (err)
                error(err);
            inited = 1;
        }

        if (!destbufsize)
            destbufsize = to!uint(buf.length) * 2;
        destbuf = new ubyte[zs.avail_in * 2 + destbufsize];
        zs.next_out = destbuf.ptr;
        zs.avail_out = to!uint(destbuf.length);

        if (zs.avail_in)
            buf = zs.next_in[0 .. zs.avail_in] ~ cast(ubyte[]) buf;

        zs.next_in = cast(ubyte*) buf;
        zs.avail_in = to!uint(buf.length);

        err = inflate(&zs, Z_NO_FLUSH);
        if (err != Z_STREAM_END && err != Z_OK)
        {   delete destbuf;
            error(err);
        }
        destbuf.length = destbuf.length - zs.avail_out;
        return destbuf;
    }

    /**
     * Decompress and return any remaining data.
     * The returned data should be appended to that returned by uncompress().
     * The UnCompress object cannot be used further.
     */
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
        ubyte[] extra;
        ubyte[] destbuf;
        int err;

        done = 1;
        if (!inited)
            return null;

      L1:
        destbuf = new ubyte[zs.avail_in * 2 + 100];
        zs.next_out = destbuf.ptr;
        zs.avail_out = to!uint(destbuf.length);

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
        destbuf = destbuf.ptr[0 .. zs.next_out - destbuf.ptr];
        err = etc.c.zlib.inflateEnd(&zs);
        inited = 0;
        if (err)
            error(err);
        if (extra.length)
            destbuf = extra ~ destbuf;
        return destbuf;
    }
}

/* ========================== unittest ========================= */

private import std.stdio;
private import std.random;

unittest // by Dave
{
    debug(zlib) printf("std.zlib.unittest\n");

    bool CompressThenUncompress (ubyte[] src)
    {
      try {
        ubyte[] dst = cast(ubyte[])std.zlib.compress(cast(void[])src);
        double ratio = (dst.length / cast(double)src.length);
        debug(zlib) writef("src.length:  ", src.length, ", dst: ", dst.length, ", Ratio = ", ratio);
        ubyte[] uncompressedBuf;
        uncompressedBuf = cast(ubyte[])std.zlib.uncompress(cast(void[])dst);
        assert(src.length == uncompressedBuf.length);
        assert(src == uncompressedBuf);
      }
      catch {
        debug(zlib) writefln(" ... Exception thrown when src.length = ", src.length, ".");
        return false;
      }
      return true;
    }


    // smallish buffers
    for(int idx = 0; idx < 25; idx++) {
        char[] buf = new char[uniform(0, 100)];

        // Alternate between more & less compressible
        foreach(ref char c; buf)
            c = cast(char) (' ' + (uniform(0, idx % 2 ? 91 : 2)));

        if(CompressThenUncompress(cast(ubyte[])buf)) {
            debug(zlib) printf("; Success.\n");
        } else {
            return;
        }
    }

    // larger buffers
    for(int idx = 0; idx < 25; idx++) {
        char[] buf = new char[uniform(0, 1000/*0000*/)];

        // Alternate between more & less compressible
        foreach(ref char c; buf)
            c = cast(char) (' ' + (uniform(0, idx % 2 ? 91 : 10)));

        if(CompressThenUncompress(cast(ubyte[])buf)) {
            debug(zlib) printf("; Success.\n");
        } else {
            return;
        }
    }

    debug(zlib) printf("PASSED std.zlib.unittest\n");
}


unittest // by Artem Rebrov
{
    Compress cmp = new Compress;
    UnCompress decmp = new UnCompress;

    const(void)[] input;
    input = "tesatdffadf";

    const(void)[] buf = cmp.compress(input);
    buf ~= cmp.flush();
    const(void)[] output = decmp.uncompress(buf);

    //writefln("input = '%s'", cast(char[])input);
    //writefln("output = '%s'", cast(char[])output);
    assert( output[] == input[] );
}

