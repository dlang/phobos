/*
 * Placed into the Public Domain.
 * written by Sean Kelly
 * www.digitalmars.com
 */

#ifdef __APPLE__


#include <mach-o/dyld.h>
#include <mach-o/getsect.h>

void _d_gc_addrange( void* pbot, void* ptop );
void _d_gc_removerange( void* p );

typedef struct
{
    const char* seg;
    const char* sect;
} seg_ref;

const static seg_ref data_segs[] = {{SEG_DATA, SECT_DATA},
                                    {SEG_DATA, SECT_BSS},
                                    {SEG_DATA, SECT_COMMON}};
const static int NUM_DATA_SEGS   = sizeof(data_segs) / sizeof(seg_ref);


static void on_add_image( const struct mach_header* h, intptr_t slide )
{
    const struct section* sect;
        int i;

    for( i = 0; i < NUM_DATA_SEGS; ++i )
    {
        sect = getsectbynamefromheader( h,
                                        data_segs[i].seg,
                                        data_segs[i].sect );
        if( sect == NULL || sect->size == 0 )
            continue;
        _d_gc_addrange( (void*) sect->addr + slide,
                        (void*) sect->addr + slide + sect->size );
    }
}


static void on_remove_image( const struct mach_header* h, intptr_t slide )
{
    const struct section* sect;
        int i;

    for( i = 0; i < NUM_DATA_SEGS; ++i )
    {
        sect = getsectbynamefromheader( h,
                                        data_segs[i].seg,
                                        data_segs[i].sect );
        if( sect == NULL || sect->size == 0 )
            continue;
        _d_gc_removerange( (void*) sect->addr + slide );
    }
}


void _d_osx_image_init()
{
    _dyld_register_func_for_add_image( &on_add_image );
    _dyld_register_func_for_remove_image( &on_remove_image );
}


#endif
