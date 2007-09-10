

/******************************************
 * Runtime helper to convert dynamic array of one
 * type to dynamic array of another.
 * Adjusts the length of the array.
 * Throws exception if new length is not aligned.
 */

extern (C)

void[] _d_arraycast(uint tsize, uint fsize, void[] a)
{
    uint length = a.length;
    uint nbytes;

    nbytes = length * fsize;
    if (nbytes % tsize != 0)
    {
	throw new Error("array cast misalignment");
    }
    length = nbytes / tsize;
    *cast(uint *)&a = length;	// jam new length
    return a;
}

unittest
{
    byte[int.sizeof * 3] b;
    int[] i;
    short[] s;

    i = cast(int[])b;
    assert(i.length == 3);

    s = cast(short[])b;
    assert(s.length == 6);

    s = cast(short[])i;
    assert(s.length == 6);
}

/******************************************
 * Runtime helper to convert dynamic array of bits
 * dynamic array of another.
 * Adjusts the length of the array.
 * Throws exception if new length is not aligned.
 */

extern (C)

void[] _d_arraycast_frombit(uint tsize, void[] a)
{
    uint length = a.length;

    if (length & 7)
    {
	throw new Error("bit[] array cast misalignment");
    }
    length /= 8 * tsize;
    *cast(uint *)&a = length;	// jam new length
    return a;
}

unittest
{
    bit[int.sizeof * 3 * 8] b;
    int[] i;
    short[] s;

    i = cast(int[])b;
    assert(i.length == 3);

    s = cast(short[])b;
    assert(s.length == 6);
}


