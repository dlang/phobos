
// Copyright (C) 2001 by Digital Mars
// All Rights Reserved
// Written by Walter Bright

#include <assert.h>
#include <stdlib.h>

#include "bits.h"

GCBits::GCBits()
{
    data = NULL;
    nwords = 0;
    nbits = 0;
}

GCBits::~GCBits()
{
    if (data)
	::free(data);
    data = NULL;
}

void GCBits::invariant()
{
    if (data)
    {
	assert(nwords * sizeof(*data) * 8 >= nbits);
    }
}

void GCBits::alloc(unsigned nbits)
{
    this->nbits = nbits;
    nwords = (nbits + (BITS_PER_WORD - 1)) >> BITS_SHIFT;
    data = (unsigned *)::calloc(nwords + 2, sizeof(unsigned));
    assert(data);
}
