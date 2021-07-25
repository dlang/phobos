// Written in the D programming language

/**
* This module exposes the getpass function that reads a string from the
* current terminal without echoing it.
*
* Copyright: Teodor Dutu 2021-.
* License:   $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).
* Source:    $(PHOBOSSRC std/getpass.d)
* Authors:   Teodor Dutu
*/

module std.getpass;

import std.conv : to;

version (Posix)
{
    version (unittest)
    {
        import std.stdio : FILE, fclose, fflush, fileno, fprintf, stdin, stdout, _IO_FILE;
        import core.sys.linux.termios : ECHO, termios, TCSAFLUSH;
        import core.sys.posix.sys.types : ssize_t;

        private enum GetlineBehavior
        {
            getlineNormal,
            getlineNullBuff,
            getlineReturnsNeg
        }

        private GetlineBehavior getlineBehavior;
        private bool fopenNormal;
        private bool tcgetattrNormal;
        private bool tcsetattrNormal;
        private string password;

        private FILE* fopen(scope const char* fname, scope const char* mode)
        {
            if (fopenNormal)
            {
                import std.stdio : fopen;
                return fopen(fname, mode);
            }

            return null;
        }

        private void writePassword(char **buf, size_t *len)
        {
            import core.stdc.string : strcpy;

            *buf = cast(char*)(new char[password.length + 2]);
            *len = password.length + 1;
            strcpy(*buf, password.ptr);
            (*buf)[password.length] = '\n';
            (*buf)[password.length + 1] = '\0';
        }

        private ssize_t getline(char** buf, size_t* len, FILE* file)
        {
            switch (getlineBehavior)
            {
                case GetlineBehavior.getlineNormal:
                    writePassword(buf, len);
                    return password.length + 1;
                case GetlineBehavior.getlineNullBuff:
                    *buf = null;
                    return 0;
                case GetlineBehavior.getlineReturnsNeg:
                    writePassword(buf, len);
                    return -1;
                default:
                    assert(0, "unknown behavior");
            }
        }

        private int tcsetattr(int fd, int flag, const scope termios* term)
        {
            if (tcsetattrNormal)
            {
                import core.sys.linux.termios : tcsetattr;
                return tcsetattr(fd, flag, term);
            }

            return 1;
        }

        private int tcgetattr(int fd, termios* term)
        {
            if (tcgetattrNormal)
            {
                import core.sys.linux.termios : tcgetattr;
                return tcgetattr(fd, term);
            }

            return 1;
        }
    }
    else
    {
        import std.stdio;
        import core.sys.linux.termios;
        import core.sys.posix.stdio : getline;
    }

    // `getpass` implementation on POSIX systems.
    // Uses `tcgetattr` to disable echoing to the terminal of the current
    // process.
    private string getpassPosix(string prompt)
    {
        int inFd, ttyChanged;
        termios oldTerm, newTerm;
        shared _IO_FILE* inStream, outStream;
        char *pass = null;
        ssize_t numRead;
        size_t passLen = 0;

        inStream = fopen("/dev/tty", "w+");
        if (inStream == null)
        {
            inStream = stdin.getFP;
            outStream = stdout.getFP;
        }
        else
        {
            outStream = inStream;
        }

        inFd = fileno(inStream);

        if (!tcgetattr(inFd, &oldTerm))
        {
            newTerm = oldTerm;
            newTerm.c_lflag &= ~ECHO;
            ttyChanged = tcsetattr(inFd, TCSAFLUSH, &newTerm) == 0;
        }
        else
        {
            ttyChanged = 0;
        }

        fprintf(outStream, "%s", prompt.ptr);
        fflush(outStream);

        numRead = getline(&pass, &passLen, inStream);

        if (pass)
        {
            if (numRead <= 0)
            {
                pass[0] = '\0';
            }
            else if (pass[numRead - 1] == '\n')
            {
                pass[numRead - 1] = '\0';
                if (ttyChanged)
                {
                    fprintf(outStream, "\n");
                }
            }
        }

        if (ttyChanged)
        {
            tcsetattr(inFd, TCSAFLUSH, &oldTerm);
        }

        if (inStream != stdin.getFP)
        {
            fclose(inStream);
        }

        return to!string(pass);
    }
}
else version (Windows)
{
    import std.array : popBack;
    import std.stdio : printf;

    version (unittest)
    {
        string password;
        size_t cursor;

        private int getch()
        {
            return cast(int) password[cursor++];
        }
    }
    else
    {
        extern (C) private int getch();
    }

    // `getpass` implementation on Windows systems.
    // Uses the `getch` from the Windows C runtime, which reads a single
    // character, without echoing it.
    private string getpassWindows(string prompt)
    {
        char[] pass;
        char c;

        printf("%s", prompt.ptr);

        do
        {
            c = cast(char) getch();
            if (c == '\b')
            {
                if (pass.length)
                {
                    pass.popBack;
                }
            }
            else
            {
                pass ~= c;
            }
        } while (c != '\003' && c != '\r' && c != '\n');  // Ctrl + C or newline

        // Move the cursor to a new line.
        printf("\n");

        pass = pass[0..$-1];
        return to!string(pass);
    }
}

/**
  Reads user password from the terminal of the current process (`/dev/tty`) if
  available, or from `stdin` otherwise. The password is not echoed.

  Example:
  -------------------
  // Places the password in the homonymous variable.
  string password = getpass("Please enter your password: ");
  -------------------

  Params:
    prompt = String to be displayed to the user before they type their password.

  Returns:
    The password provided by the user without its trailing newline.
*/
string getpass(string prompt = "Password: ")
{
    version (Posix)
    {
        return getpassPosix(prompt);
    }
    else version (Windows)
    {
        return getpassWindows(prompt);
    }
    else
    {
        assert(0, "unknown version");
    }
}

/// The variables below are used for mocking the functions called internally
/// by getpass
@system unittest
{
    version (Posix)
    {
        password = "testPassword1234@!$";

        getlineBehavior = GetlineBehavior.getlineNormal;
        fopenNormal = true;
        tcgetattrNormal = false;  // to reduce the number of printed newlines
        tcsetattrNormal = true;
        assert(password == getpass(""));

        fopenNormal = false;
        assert(password == getpass(""));

        fopenNormal = true;
        tcgetattrNormal = true;
        assert(password == getpass(""));

        tcgetattrNormal = true;
        tcsetattrNormal = false;
        assert(password == getpass(""));

        getlineBehavior = GetlineBehavior.getlineNullBuff;
        assert(null == getpass(""));

        getlineBehavior = GetlineBehavior.getlineReturnsNeg;
        assert("" == getpass(""));
    }
    else version (Windows)
    {
        password = "\r";
        cursor = 0;
        assert("" == getpass(""));

        password = "\n";
        cursor = 0;
        assert("" == getpass(""));

        password = "\b\n";
        cursor = 0;
        assert("" == getpass(""));

        password = "aa\b\b\n";
        cursor = 0;
        assert("" == getpass(""));

        password = "testPassword1234@!$\n";
        cursor = 0;
        assert("testPassword1234@!$" == getpass(""));

        password = "testPassword1\b234\b@!$\n";
        cursor = 0;
        assert("testPassword23@!$" == getpass(""));
    }
    else
    {
        assert(0);
    }
}
