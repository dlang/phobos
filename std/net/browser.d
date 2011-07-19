// Written in the D programming language.

/**
For dealing with web browsers.

Macros:
WIKI = Phobos/StdNetBrowser

Copyright: Copyright Digital Mars 2011.
License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(WEB digitalmars.com, Walter Bright)
Source:    $(PHOBOSSRC std/net/browser.d)
 */
module std.net.browser;

version (Windows)
{
    import std.string;
    import core.sys.windows.windows;

    extern (Windows)
    HINSTANCE ShellExecuteA(HWND hwnd, LPCSTR lpOperation, LPCSTR lpFile, LPCSTR lpParameters, LPCSTR lpDirectory, INT nShowCmd);


    pragma(lib,"shell32.lib");

    /****************************************
     * Start up the browser and set it to viewing the page at url.
     */
    void browse(string url)
    {
        ShellExecuteA(null, "open", toStringz(url), null, null, SW_SHOWNORMAL);
    }
}
else version (OSX)
{
    import core.stdc.stdio;
    import core.stdc.string;
    import core.stdc.stdlib;
    import core.sys.posix.unistd;

    import std.string;

    void browse(string url)
    {
        const char *args[5];

        const(char)* browser = getenv("BROWSER");
        if (browser)
        {   browser = strdup(browser);
            args[0] = browser;
            args[1] = toStringz(url);
            args[2] = null;
        }
        else
        {
            //browser = "/Applications/Safari.app/Contents/MacOS/Safari";
            args[0] = "open".ptr;
            args[1] = "-a".ptr;
            args[2] = "/Applications/Safari.app".ptr;
            args[3] = toStringz(url);
            args[4] = null;
        }

        auto childpid = fork();
        if (childpid == 0)
        {
            execvp(args[0], cast(char**)args.ptr);
            perror(args[0]);                // failed to execute
            return;
        }
    }
}
else version (Posix)
{
    import core.stdc.stdio;
    import core.stdc.string;
    import core.stdc.stdlib;
    import core.sys.posix.unistd;

    import std.string;

    void browse(string url)
    {

        const(char)* browser = getenv("BROWSER");
        if (browser)
            browser = strdup(browser);
        else
            browser = "x-www-browser".ptr;

        const(char)*[3] args;
        args[0] = browser;
        args[1] = toStringz(url);
        args[2] = null;

        auto childpid = fork();
        if (childpid == 0)
        {
            execvp(args[0], cast(char**)args.ptr);
            perror(args[0]);                // failed to execute
            return;
        }
    }
}
else
    static assert(0, "os not supported");


