module std.bitmanip2;
import core.bitop;
version(unittest)
{
    import std.stdio;
}

struct BitArray
{
    size_t len;
    size_t* ptr;
    enum bitsPerSizeT = size_t.sizeof * 8;

    @property const size_t dim()
    {
        return (len + (bitsPerSizeT-1)) / bitsPerSizeT;
    }

    @property const size_t length()
    {
        return len;
    }

    @property size_t length(size_t newlen)
    {
        if (newlen != len)
        {
            size_t olddim = dim;
            size_t newdim = (newlen + (bitsPerSizeT-1)) / bitsPerSizeT;

            if (newdim != olddim)
            {
                // Create a fake array so we can use D's realloc machinery
                auto b = ptr[0 .. olddim];
                b.length = newdim;                // realloc
                ptr = b.ptr;
            }

            len = newlen;
        }
        return len;
    }

    void init(bool[] ba)
    {
        length = ba.length;
        foreach (i, b; ba)
        {
            this[i] = b;
        }
    }

    bool opIndexAssign(bool b, size_t i)
    in
    {
        assert(i < len);
    }
    body
    {
        if (b)
            bts(ptr, i);
        else
            btr(ptr, i);
        return b;
    }

    unittest
    {
        foreach (i; 1 .. 256)
        {
            foreach (j; 0 .. i)
            {
                BitArray a1, a2;
                a1.length = i;
                a2.length = i;
                a1[j] = true;
            }
        }
    }

    unittest
    {
        bool[] v;
        for (int i = 1; i < 256; i++)
        {   stderr.writeln("opCmp test it: ",i);
            v.length = i;
            v[] = false;
            BitArray x; x.init(v);
            v[i-1] = true;
            BitArray y; y.init(v);
        }
    }
}
