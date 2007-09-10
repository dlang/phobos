
import object;
import string;

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
    a.length = length;
    return a;
}

byte[] _d_arrayappend(byte[] *px, byte[] y, uint size)
{
    *px = _d_arraycat(*px, y, size);
    return *px;
}

byte[] _d_arraycopy(uint size, byte[] from, byte[] to)
{
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

