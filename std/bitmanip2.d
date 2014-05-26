module std.bitmanip2;
import core.bitop;
import std.stdio;
bool ittrigger = false;
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
                auto b = ptr[0 .. olddim];
                b.length = newdim; // realloc
                ptr = b.ptr;
            }

            len = newlen;
        }
        return len;
    }

    void init(bool[] ba)
    {
        length = ba.length;

        version(nobug2)
        {
            foreach (ref e; ptr[0 .. dim])
                e = 0;
        }
        else
        {
            foreach (i, b; ba)
            {
                version(nobug3)
                {
                    if (b)
                        bts(ptr, i);
                    else
                        btr(ptr, i);
                }
                else
                {
                    if (ittrigger)
                        stderr.writeln(i);
                    this[i] = b;
                }
            }
        }
    }

    bool opIndexAssign(bool b, size_t i)
    {
        if (b)
            bts(ptr, i);
        else
            btr(ptr, i);
        return b;
    }

    unittest
    {

        version(nobug4) {}
        else
        {
            foreach (i; 1 .. 256)
            {
                foreach (j; 0 .. i)
                {
                    BitArray a1, a2;
                    a1.length = i;
                    a2.length = i;
                }
            }
        }

        version(nobug5)
        {
            import core.memory;
            GC.collect;
            GC.minimize;
        }

        bool[] v;
        for (int i = 1; i < 256; i++)
        {   if (i == 30) ittrigger = true;
            v.length = i;
            BitArray x; x.init(v);
            BitArray y; y.init(v);
        }
    }
}
