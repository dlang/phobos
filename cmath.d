// cmath.d
// Written by Walter Bright
// Copyright (c) 2001-2003 Digital Mars
// All Rights Reserved
// www.digitalmars.com


module math;

real fabs(real);
real sqrt(real);

creal sqrt(creal z)
{
    creal c;
    real x,y,w,r;

    if (z == 0)
    {
	c = 0;
    }
    else
    {	real z_re = z.re;
	real z_im = z.im;

	x = fabs(z_re);
	y = fabs(z_im);
	if (x >= y)
	{
	    r = y / x;
	    w = sqrt(x) * sqrt(0.5 * (1 + sqrt(1 + r * r)));
	}
	else
	{
	    r = x / y;
	    w = sqrt(y) * sqrt(0.5 * (r + sqrt(1 + r * r)));
	}

	if (z_re >= 0)
	{
	    c = w + (z_im / (w + w)) * 1.0i;
	}
	else
	{
	    if (z_im < 0)
		w = -w;
	    c = z_im / (w + w) + w * 1.0i;
	}
    }
    return c;
}

