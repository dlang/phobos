
extern (C)
{
    // Functions from the C library.
    void *memcpy(void *, void *, uint);
}

extern (C):

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
version (X86)
{
    asm
    {
	mov	EDI,p		;
	mov	EAX,value	;
	mov	ECX,count	;
	mov	EDX,EDI		;
	rep			;
	stosd			;
	mov	EAX,EDX		;
    }
}
else
{
    int *pstart = p;
    int *ptop;

    for (ptop = &p[count]; p < ptop; p++)
	*p = value;
    return pstart;
}
}

long *_memset64(long *p, long value, int count)
{
    long *pstart = p;
    long *ptop;

    for (ptop = &p[count]; p < ptop; p++)
	*p = value;
    return pstart;
}

real *_memset80(real *p, real value, int count)
{
    real *pstart = p;
    real *ptop;

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
