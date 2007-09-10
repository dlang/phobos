

// Copyright (c) 1999-2003 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com

/* These functions are built-in intrinsics to the compiler.
 */

module math;

int bsf(uint v);
int bsr(uint v);
int bt(uint *p, uint bitnum);
int btc(uint *p, uint bitnum);
int btr(uint *p, uint bitnum);
int bts(uint *p, uint bitnum);

uint bswap(uint v);

ubyte  inp(uint);
ushort inpw(uint);
uint   inpl(uint);

ubyte  outp(uint, ubyte);
ushort outpw(uint, ushort);
uint   outpl(uint, uint);


