
class GC
{
    /***********************************
     * Run a full garbage collection cycle.
     */

    void fullCollect();

    /***********************************
     * Run a generational garbage collection cycle.
     * Takes less time than a fullcollect(), but isn't
     * as effective.
     */

    void genCollect();

    /***********************************
     * If a collection hasn't been run in a while,
     * run a collection. This is useful to embed
     * in an idle loop or place in a low priority thread.
     */

    void lazyCollect();

    /***************************************
     * Disable and enable collections. They must be
     * a matched pair, and can nest.
     * By default collections are enabled.
     */

    void disable();
    void enable();

    /****************************************
     * Run all pending destructors.
     */

    void runDestructors();

    /*****************************
     * The stomper is a memory debugging aid.
     * It helps flush out initialization and dangling pointer
     * bugs by stomping on allocated and free'd memory.
     * With the stomper running, it's extremely unlikely that deleted
     * and collected memory will inadvertantly
     * contain valid data.
     * Stomping, of course, slows down execution, so
     * it can be adjusted dynamically.
     *	level	0	no stomping, run at max speed
     *		1	stomp on new's, delete's,
     *			cause array resizes to always copy & stomp
     *		2	add sentinels before and after objects to detect
     *			over and underruns
     */

    void setStomper(int level);
}
