

// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com

/* These functions are built-in intrinsics to the compiler.
 */

int bsf(uint v);
int bsr(uint v);
int bt(uint *p, uint bitnum);
int btc(uint *p, uint bitnum);
int btr(uint *p, uint bitnum);
int bts(uint *p, uint bitnum);

ubyte  inp(uint);
ushort inpw(uint);
uint   inpl(uint);

ubyte  outp(uint, ubyte);
ushort outpw(uint, ushort);
uint   outpl(uint, uint);

extended cos(extended);
extended fabs(extended);
extended rint(extended);
long rndtol(extended);
extended sin(extended);
extended sqrt(extended);
