//
// Copyright (c) 1999-2003 by Digital Mars, www.digitalmars.com
// All Rights Reserved
// Written by Walter Bright

// Exception handling support

//debug=1;

import linuxextern;

extern (C) int _d_isbaseof(ClassInfo oc, ClassInfo c);

alias int (*fp_t)();   // function pointer in ambient memory model

struct DHandlerInfo
{
    uint offset;		// offset from function address to start of guarded section
    int prev_index;		// previous table index
    uint cioffset;		// offset to DCatchInfo data from start of table (!=0 if try-catch)
    void *finally_code;		// pointer to finally code to execute
				// (!=0 if try-finally)
}

// Address of DHandlerTable, searched for by eh_finddata()

struct DHandlerTable
{
    void *fptr;			// pointer to start of function
    uint espoffset;		// offset of ESP from EBP
    uint retoffset;		// offset from start of function to return code
    uint nhandlers;		// dimension of handler_info[]
    DHandlerInfo handler_info[1];
}

struct DCatchBlock
{
    ClassInfo type;		// catch type
    uint bpoffset;		// EBP offset of catch var
    void *code;			// catch handler code
}

// Create one of these for each try-catch
struct DCatchInfo
{
    uint ncatches;			// number of catch blocks
    DCatchBlock catch_block[1];		// data for each catch block
}

// One of these is generated for each function with try-catch or try-finally

struct FuncTable
{
    void *fptr;			// pointer to start of function
    DHandlerTable *handlertable; // eh data for this function
    uint fsize;		// size of function in bytes
}

void terminate()
{
    asm
    {
	hlt ;
    }
}

/*******************************************
 * Given address that is inside a function,
 * figure out which function it is in.
 * Return DHandlerTable if there is one, NULL if not.
 */

DHandlerTable *__eh_finddata(void *address)
{
    FuncTable *ft;

    debug printf("__eh_finddata(address = x%x)\n", address);
    debug printf("_deh_beg = x%x, _deh_end = x%x\n", &_deh_beg, &_deh_end);
    for (ft = (FuncTable *)&_deh_beg;
	 ft < (FuncTable *)&_deh_end;
	 ft++)
    {
	debug printf("\tfptr = x%x, fsize = x%x, handlertable = x%x\n",
		ft.fptr, ft.fsize, ft.handlertable);

	if (ft.fptr <= address &&
	    address < (void *)((char *)ft.fptr + ft.fsize))
	{
	    return ft.handlertable;
	}
    }
    return null;
}


/******************************
 * Given EBP, find return address to caller, and caller's EBP.
 * Input:
 *   regbp       Value of EBP for current function
 *   *pretaddr   Return address
 * Output:
 *   *pretaddr   return address to caller
 * Returns:
 *   caller's EBP
 */

uint __eh_find_caller(uint regbp, uint *pretaddr)
{
    uint bp = *(uint *)regbp;

    if (bp)         // if not end of call chain
    {
	// Perform sanity checks on new EBP.
	// If it is screwed up, terminate() hopefully before we do more damage.
	if (bp <= regbp) 
	    // stack should grow to smaller values
	    terminate();

        *pretaddr = *(uint *)(regbp + int.size);
    }
    return bp;
}

/***********************************
 * Throw a D object.
 */

extern (Windows) void _d_throw(Object *h)
{
    uint regebp;

    debug
    {
	printf("_d_throw(h = %p, &h = %p)\n", h, &h);
	printf("\tvptr = %p\n", *(void **)h);
    }

    asm
    {
	mov regebp,EBP	;
    }

    while (1)		// for each function on the stack
    {
        DHandlerTable *handler_table;
	FuncTable *pfunc;
	DHandlerInfo *phi;
	uint retaddr;
        uint funcoffset;
	uint spoff;
	uint retoffset;
        int index;
        int dim;
	int ndx;
	int prev_ndx;

        regebp = __eh_find_caller(regebp,&retaddr);
        if (!regebp)
	{   // if end of call chain
	    debug printf("end of call chain\n");
            break;
	}

	debug printf("found caller, EBP = x%x, retaddr = x%x\n", regebp, retaddr);
        handler_table = __eh_finddata((void *)retaddr);   // find static data associated with function
        if (!handler_table)         // if no static data
        {   
	    debug printf("no handler table\n");
            continue;
        }
        funcoffset = (uint)handler_table.fptr;
        spoff = handler_table.espoffset;
        retoffset = handler_table.retoffset;

	debug
	{
	    printf("retaddr = x%x\n",(uint)retaddr);
	    printf("regebp=x%04x, funcoffset=x%04x, spoff=x%x, retoffset=x%x\n",
	    regebp,funcoffset,spoff,retoffset);
	}

        // Find start index for retaddr in static data
        dim = handler_table.nhandlers;
        index = -1;
        for (int i = 0; i < dim; i++)
        {   
	    phi = &handler_table.handler_info[i];

            if ((uint)retaddr >= funcoffset + phi.offset)
                index = i;
        }

	// walk through handler table, checking each handler
	// with an index smaller than the current table_index
	for (ndx = index; ndx != -1; ndx = prev_ndx)
	{
	    phi = &handler_table.handler_info[ndx];
	    prev_ndx = phi.prev_index;
	    if (phi.cioffset)
	    {
		// this is a catch handler (no finally)
		DCatchInfo *pci;
		int ncatches;
		int i;

		pci = (DCatchInfo *)((char *)handler_table + phi.cioffset);
		ncatches = pci.ncatches;
		for (i = 0; i < ncatches; i++)
		{
		    DCatchBlock *pcb;
		    ClassInfo ci = **(ClassInfo **)h;

		    pcb = &pci.catch_block[i];

		    if (_d_isbaseof(ci, pcb.type))
		    {   // Matched the catch type, so we've found the handler.

			// Initialize catch variable
			*(void **)(regebp + (pcb.bpoffset)) = h;

			// Jump to catch block. Does not return.
			{
			    uint catch_esp;
			    fp_t catch_addr;

			    catch_addr = (fp_t)(pcb.code);
			    catch_esp = regebp - handler_table.espoffset - fp_t.size;
			    asm
			    {
				mov	EAX,catch_esp	;
				mov	ECX,catch_addr	;
				mov	[EAX],ECX	;
				mov	EBP,regebp	;
				mov	ESP,EAX		; // reset stack
				ret			; // jump to catch block
			    }
			}
		    }
		}
	    }
	    else if (phi.finally_code)
	    {	// Call finally block
		// Note that it is unnecessary to adjust the ESP, as the finally block
		// accesses all items on the stack as relative to EBP.

		void *blockaddr = phi.finally_code;

		asm
		{
		    push	EBX		;
		    mov		EBX,blockaddr	;
		    push	EBP		;
		    mov		EBP,regebp	;
		    call	EBX		;
		    pop		EBP		;
		    pop		EBX		;
		}
	    }
	}
    }
}

