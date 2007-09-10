
#include <string.h>

short *_memset16(short *p, short value, int count)
{
    short *pstart = p;
    short *ptop;

    for (ptop = &p[count]; p < ptop; p++)
	*p = value;
    return pstart;
}

int *_memset32(int *p, int value, int count)
{
    int *pstart = p;
    int *ptop;

    for (ptop = &p[count]; p < ptop; p++)
	*p = value;
    return pstart;
}

long long *_memset64(long long *p, long long value, int count)
{
    long long *pstart = p;
    long long *ptop;

    for (ptop = &p[count]; p < ptop; p++)
	*p = value;
    return pstart;
}

long double *_memset80(long double *p, long double value, int count)
{
    long double *pstart = p;
    long double *ptop;

    for (ptop = &p[count]; p < ptop; p++)
	*p = value;
    return pstart;
}

void *_memsetn(void *p, void *value, int count, int sizelem)
{   void *pstart = p;
    int i;

    for (i = 0; i < count; i++)
    {
	memcpy(p, value, sizelem);
	p = (void *)((char *)p + sizelem);
    }
    return pstart;
}
