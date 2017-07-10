module unittest_merge;

// A hack to set coverage to merge
shared static this()
{
    version(D_Coverage)
    {
        import core.runtime : dmd_coverSetMerge;
        dmd_coverSetMerge(true);
    }
}
