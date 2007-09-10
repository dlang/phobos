
long double _modulo(long double x, long double y)
{   short sw;

    __asm
    {
	fld	tbyte ptr y
	fld	tbyte ptr x		// ST = x, ST1 = y
FM1:	// We don't use fprem1 because for some inexplicable
	// reason we get -5 when we do _modulo(15, 10)
	fprem				// ST = ST % ST1
	fstsw	word ptr sw
	fwait
	mov	AH,byte ptr sw+1	// get msb of status word in AH
	sahf				// transfer to flags
	jp	FM1			// continue till ST < ST1
	fstp	ST(1)			// leave remainder on stack
    }
}

/************************* Test **********************/

#if 0

#include <stdio.h>

extern double _fmod87(double x, double y);

void main()
{
    double x = 15;
    double y = 10;
    double z = _modulo(x, y);
    printf("z = %g\n", z);
    z = _fmod87(x, y);
    printf("z = %g\n", z);
}

#endif
