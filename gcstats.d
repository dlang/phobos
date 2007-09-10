// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com

struct GCStats
{
    uint poolsize;		// total size of pool
    uint usedsize;		// bytes allocated
    uint freeblocks;		// number of blocks marked FREE
    uint freelistsize;		// total of memory on free lists
    uint pageblocks;		// number of blocks marked PAGE
}


