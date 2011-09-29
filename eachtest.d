// Written in the D programming language.

/**
 *  This utility depends only druntime.
 *  DO NOT USE Phobos in this module.
 *
 * Copyright: Kenji Hara 2011.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Kenji Hara
 *
 */
module eachrun;

import core.stdc.stdio;

//debug = internal;

bool printcmd = true;

int main(string[] args)
{
    if (args.length == 1)
    {
        printf("usage: %.*s [options] -- files...\n",
            args[0].length, args[0].ptr);
        return 0;
    }

    string[] cmds = args, files;
    foreach (i; 1 .. args.length)
    {
        if (args[i] == "--")
        {
            cmds = args[1 .. i];
            files = args[i + 1 .. $];
            break;
        }
    }

    if (files.length)
    {
        foreach (i, file; files)
        {
            if (printcmd)
                printf("\n");

            foreach (j, cmd; cmds)
            {
                auto cmdln = replace_current_target(file, cmd);

                if (printcmd)
                    printf("each%d:%d> %.*s\n", i+1, j+1, cmdln.length, cmdln.ptr);

                if (system(cmdln) != 0)
                    return -1;
            }
        }
    }

    return 0;
}

/* **************** string operations **************** */

bool startsWith(string s, string head)
{
    if (s.length >= head.length)
        return s[0..head.length] == head[];
    return false;
}

string baseName(string path)
{
    string base = path;
    for (size_t i = path.length; i-- > 0; )
    {
        if (path[i] == '.')
        {
            base = path[0 .. i];
            break;
        }
        if (path[i] == '\\')
            break;
    }
    return base;
}

string baseDir(string base)
{
    string dir;
    for (size_t i = base.length; i-- > 0; )
    {
        if (base[i] == '\\')
        {
            dir = base[0 .. i + 1];
            break;
        }
    }
    return dir;
}

// $*, $(base*), $(basedir*), $(basename*)
// $@
// $$
string replace_current_target(string target, string cmdline)
{
    string base = baseName(target);
    string basedir = baseDir(base);
    string basefile = base[basedir.length .. $];
    debug (internal) printf("\ttgt = %.*s, base = %.*s (%.*s, %.*s)\n", target, base, basedir, basefile);

    bool inquote = false;
    for (size_t i = 0; i < cmdline.length; )
    {
        if (cmdline[i] == '"')
        {
            inquote = !inquote;
            break;
        }
        if (inquote)
            continue;

        if (cmdline[i] == '$' && i+1 != cmdline.length)
        {
            size_t j = i + 1;

            char kind = cmdline[j];
            string kindname;
            if (kind == '(')
            {
                for (++j; j < cmdline.length; ++j)
                {
                    if (cmdline[j] == ')')
                    {
                        kindname = cmdline[i+2 .. j];
                        ++j;
                        break;
                    }
                }
                if (!kindname)
                    assert(0);
                kind = kindname[$-1];
                kindname = kindname[0 .. $-1];
            }
            else
                ++j;

            debug (internal) printf("\tkind = %c, kindname = %.*s\n", kind, kindname);

            string replace;

            switch (kind)
            {
                case '*':   // Name of current target without extension
                    replace = base;
                    switch (kindname)
                    {
                        case "base":        replace = base;         break;
                        case "basedir":     replace = basedir;      break;
                        case "basefile":    replace = basefile;     break;
                        default:            assert(0);
                    }
                    break;
                case '@':   // Full target name
                    replace = target;
                    break;
                case '$':
                    replace = "$";
                    break;
                default:
                    assert(0);
            }
            cmdline = cmdline[0..i] ~ replace ~ cmdline[j .. $];
            i = i + replace.length;
        }
        else
            ++i;
    }
    return cmdline;
}


string join(string[] ror, string sep)
{
    string r;
    foreach (i, s; ror)
    {
        if (i == ror.length - 1)
            r ~= s;
        else
            r ~= s ~ sep;
    }
    return r;
}

string escape(string cmdline)
{
    char[] r;

    size_t i = 0;
    for (size_t j = 0; j < cmdline.length; ++j)
    {
        if (cmdline[j] == '\\')
        {
            auto part = cmdline[i .. j];
            auto k = r.length;
            r.length = k + part.length + 2;
            r[k .. $-2] = part[];
            r[$-2 .. $] = `\\`;
            i = j + 1;
        }
    }
    if (i < cmdline.length)
    {
        auto part = cmdline[i .. $];
        auto k = r.length;
        r.length = k + part.length;
        r[k .. $] = part[];
    }

    return cast(string)r;
}

/* **************** run command **************** */

import core.sys.windows.windows;
enum CP_UTF8 = 65001;
pragma(lib,"shell32.lib");

extern (Windows)
{
    struct STARTUPINFO {
      DWORD  cb;
      LPTSTR lpReserved;
      LPTSTR lpDesktop;
      LPTSTR lpTitle;
      DWORD  dwX;
      DWORD  dwY;
      DWORD  dwXSize;
      DWORD  dwYSize;
      DWORD  dwXCountChars;
      DWORD  dwYCountChars;
      DWORD  dwFillAttribute;
      DWORD  dwFlags;
      WORD   wShowWindow;
      WORD   cbReserved2;
      LPBYTE lpReserved2;
      HANDLE hStdInput;
      HANDLE hStdOutput;
      HANDLE hStdError;
    }
    alias STARTUPINFO* LPSTARTUPINFO;

    struct PROCESS_INFORMATION {
      HANDLE hProcess;
      HANDLE hThread;
      DWORD  dwProcessId;
      DWORD  dwThreadId;
    }
    alias PROCESS_INFORMATION* LPPROCESS_INFORMATION;

    export
    BOOL CreateProcessA(
      LPCSTR lpApplicationName,
      LPSTR lpCommandLine,
      LPSECURITY_ATTRIBUTES lpProcessAttributes,
      LPSECURITY_ATTRIBUTES lpThreadAttributes,
      BOOL bInheritHandles,
      DWORD dwCreationFlags,
      LPVOID lpEnvironment,
      LPCSTR lpCurrentDirectory,
      LPSTARTUPINFO lpStartupInfo,
      LPPROCESS_INFORMATION lpProcessInformation
    );

    export
    BOOL CreateProcessW(
      LPCWSTR lpApplicationName,
      LPWSTR lpCommandLine,
      LPSECURITY_ATTRIBUTES lpProcessAttributes,
      LPSECURITY_ATTRIBUTES lpThreadAttributes,
      BOOL bInheritHandles,
      DWORD dwCreationFlags,
      LPVOID lpEnvironment,
      LPCWSTR lpCurrentDirectory,
      LPSTARTUPINFO lpStartupInfo,
      LPPROCESS_INFORMATION lpProcessInformation
    );

    export
    BOOL
    GetExitCodeProcess(
      HANDLE hProcess,
      LPDWORD lpExitCode
    );
}

int system(string cmdline)
in { assert(cmdline.length); }
body
{
    //cmdline = escape(cmdline);    // not need

    auto n = MultiByteToWideChar(CP_UTF8, 0, cmdline.ptr, cmdline.length, null, 0);
    assert(n != 0);

    wchar[] wsz = new wchar[n + 1];
    n = MultiByteToWideChar(CP_UTF8, 0, cmdline.ptr, cmdline.length, wsz.ptr, wsz.length);
    assert(n != 0);
    wsz[$-1] = '\0';

    STARTUPINFO si = { STARTUPINFO.sizeof };
    PROCESS_INFORMATION pinfo;
    if (CreateProcessW(null, wsz.ptr, null, null, TRUE, 0, null, null, &si, &pinfo))
    {
        //printf("pinfo hTh = %p, hPr = %p\n", pinfo.hThread, pinfo.hProcess);
        CloseHandle(pinfo.hThread);

        WaitForSingleObject(pinfo.hProcess, INFINITE);

        DWORD ExitCode;
        GetExitCodeProcess(pinfo.hProcess, &ExitCode);
        CloseHandle(pinfo.hProcess);

        return ExitCode;
    }

    return -1;
}
