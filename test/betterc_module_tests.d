static immutable bettercModules = [
    "std.sumtype"
];

template from(string modname)
{
    mixin("import from = ", modname, ";");
}

void testModule(string modname)()
{
    import core.stdc.stdio : printf;

    printf("Running BetterC tests for %.*s\n", cast(int) modname.length, modname.ptr);

    static foreach (test; __traits(getUnitTests, from!modname))
    {
        test();
    }
}

extern(C) int main()
{
    static foreach (modname; bettercModules)
    {
        testModule!modname;
    }

    return 0;
}
