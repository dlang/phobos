
import object;
import std.string;
import std.c.stdio;

extern (C):

byte[] _d_arraycat(byte[] x, byte[] y, uint size)
{   byte[] a;
    uint length;

    if (!x.length)
	return y;
    if (!y.length)
	return x;

    length = x.length + y.length;
    a = new byte[length * size];
    memcpy(a, x, x.length * size);
    //a[0 .. x.length * size] = x[];
    memcpy(&a[x.length * size], y, y.length * size);
    *(int *)&a = length;	// jam length
    //a.length = length;
    return a;
}

byte[] _d_arraycatn(uint size, uint n, ...)
{   byte[] a;
    uint length;
    byte[]* p;
    uint i;
    byte[] b;

    p = cast(byte[]*)(&n + 1);

    for (i = 0; i < n; i++)
    {
	b = *p++;
	length += b.length;
    }
    if (!length)
	return null;

    a = new byte[length * size];
    p = cast(byte[]*)(&n + 1);

    uint j = 0;
    for (i = 0; i < n; i++)
    {
	b = *p++;
	if (b.length)
	{
	    memcpy(&a[j], b, b.length * size);
	    j += b.length * size;
	}
    }

    *(int *)&a = length;	// jam length
    //a.length = length;
    return a;
}

byte[] _d_arraycopy(uint size, byte[] from, byte[] to)
{
    //printf("f = %p,%d, t = %p,%d, size = %d\n", (void*)from, from.length, (void*)to, to.length, size);

    if (to.length != from.length)
    {
	throw new Error("lengths don't match for array copy");
    }
    else if ((byte *)to + to.length * size <= (byte *)from ||
	(byte *)from + from.length * size <= (byte *)to)
    {
	memcpy((byte *)to, (byte *)from, to.length * size);
    }
    else
    {
	throw new Error("overlapping array copy");
    }
    return to;
}

bit[] _d_arraycopybit(bit[] from, bit[] to)
{
    //printf("f = %p,%d, t = %p,%d\n", (void*)from, from.length, (void*)to, to.length);
    uint nbytes;

    if (to.length != from.length)
    {
	throw new Error("lengths don't match for array copy");
    }
    else
    {
	nbytes = (to.length + 7) / 8;
	if ((void *)to + nbytes <= (void *)from ||
	    (void *)from + nbytes <= (void *)to)
	{
	    memcpy((void *)to, (void *)from, nbytes);
	}
	else
	{
	    throw new Error("overlapping array copy");
	}
    }
    return to;
}

bit[] _d_arraysetbit(bit[] ba, uint lwr, uint upr, bit value)
in
{
    //printf("_d_arraysetbit(ba.length = %d, lwr = %u, upr = %u, value = %d)\n", ba.length, lwr, upr, value);
    assert(lwr <= upr);
    assert(upr <= ba.length);
}
body
{
    // Inefficient; lots of room for improvement here
    for (uint i = lwr; i < upr; i++)
	ba[i] = value;

    return ba;
}
