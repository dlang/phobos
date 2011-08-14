// Written in the D programming language.

/**
 * Read and write memory mapped files.
 * Macros:
 *  WIKI=Phobos/StdMmfile
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright),
 *            Matthew Wilson
 * Source:    $(PHOBOSSRC std/_mmfile.d)
 */
/*          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.mmfile;

private import std.file;
private import core.stdc.stdio;
private import core.stdc.stdlib;
private import core.stdc.errno;
private import std.path;
private import std.string;
import std.conv, std.exception, std.stdio;

//debug = MMFILE;

version (Win32)
{
    private import std.c.windows.windows;
    private import std.utf;

    private __gshared const uint dwVersion;

    shared static this()
    {
        /* http://msdn.microsoft.com/library/default.asp?url=/library/en-us
           /sysinfo/base/getversion.asp */
        dwVersion = GetVersion();
    }
}
else version (Posix)
{
    private import core.sys.posix.fcntl;
    private import core.sys.posix.unistd;
    private import core.sys.posix.sys.mman;
    private import core.sys.posix.sys.stat;
}
else
{
    static assert(0);
}

/**
 * MmFile objects control the memory mapped file resource.
 */
class MmFile
{
    /**
     * The mode the memory mapped file is opened with.
     */
    enum Mode
    {
        read,            /// Read existing file
        readWriteNew,    /// Delete existing file, write new file
        readWrite,       /// Read/Write existing file, create if not existing
        readCopyOnWrite, /// Read/Write existing file, copy on write
    }

    /**
     * Open memory mapped file filename for reading.
     * File is closed when the object instance is deleted.
     * Throws:
     *  std.file.FileException
     */
    this(string filename)
    {
        this(filename, Mode.read, 0, null);
    }

    version(linux) this(File file, Mode mode = Mode.read, ulong size = 0,
            void* address = null, size_t window = 0)
    {
        this(file.fileno, mode, size, address, window);
    }

    version(linux) private this(int fildes, Mode mode, ulong size,
            void* address, size_t window)
    {
        int oflag;
        int fmode;

        switch (mode)
        {
        case Mode.read:
            flags = MAP_SHARED;
            prot = PROT_READ;
            oflag = O_RDONLY;
            fmode = 0;
            break;

        case Mode.readWriteNew:
            assert(size != 0);
            flags = MAP_SHARED;
            prot = PROT_READ | PROT_WRITE;
            oflag = O_CREAT | O_RDWR | O_TRUNC;
            fmode = octal!660;
            break;

        case Mode.readWrite:
            flags = MAP_SHARED;
            prot = PROT_READ | PROT_WRITE;
            oflag = O_CREAT | O_RDWR;
            fmode = octal!660;
            break;

        case Mode.readCopyOnWrite:
            flags = MAP_PRIVATE;
            prot = PROT_READ | PROT_WRITE;
            oflag = O_RDWR;
            fmode = 0;
            break;

        default:
            assert(0);
        }

        // Adjust size
        struct_stat64 statbuf = void;
        errnoEnforce(fstat64(fd, &statbuf) == 0);
        if (prot & PROT_WRITE && size > statbuf.st_size)
        {
            // Need to make the file size bytes big
            lseek(fd, cast(int)(size - 1), SEEK_SET);
            char c = 0;
            core.sys.posix.unistd.write(fd, &c, 1);
        }
        else if (prot & PROT_READ && size == 0)
            size = statbuf.st_size;
        this.size = size;

        // Map the file into memory!
        size_t initial_map = (window && 2*window<size)
            ? 2*window : cast(size_t)size;
        auto p = mmap(address, initial_map, prot, flags, fd, 0);
        if (p == MAP_FAILED) {
            errnoEnforce(false, "Could not map file into memory");
        }
        data = p[0 .. initial_map];
    }

    /**
     * Open memory mapped file filename in mode.
     * File is closed when the object instance is deleted.
     * Params:
     *  filename = name of the file.
     *      If null, an anonymous file mapping is created.
     *  mode = access mode defined above.
     *  size =  the size of the file. If 0, it is taken to be the
     *      size of the existing file.
     *  address = the preferred address to map the file to,
     *      although the system is not required to honor it.
     *      If null, the system selects the most convenient address.
     *  window = preferred block size of the amount of data to map at one time
     *      with 0 meaning map the entire file. The window size must be a
     *      multiple of the memory allocation page size.
     * Throws:
     *  std.file.FileException
     */
    this(string filename, Mode mode, ulong size, void* address,
            size_t window = 0)
    {
        this.filename = filename;
        this.mMode = mode;
        this.window = window;
        this.address = address;

        version (Win32)
        {
            void* p;
            uint dwDesiredAccess2;
            uint dwShareMode;
            uint dwCreationDisposition;
            uint flProtect;

            if (dwVersion & 0x80000000 && (dwVersion & 0xFF) == 3)
            {
                throw new FileException(filename,
                        "Win32s does not implement mm files");
            }

            switch (mode)
            {
            case Mode.read:
                dwDesiredAccess2 = GENERIC_READ;
                dwShareMode = FILE_SHARE_READ;
                dwCreationDisposition = OPEN_EXISTING;
                flProtect = PAGE_READONLY;
                dwDesiredAccess = FILE_MAP_READ;
                break;

            case Mode.readWriteNew:
                assert(size != 0);
                dwDesiredAccess2 = GENERIC_READ | GENERIC_WRITE;
                dwShareMode = FILE_SHARE_READ | FILE_SHARE_WRITE;
                dwCreationDisposition = CREATE_ALWAYS;
                flProtect = PAGE_READWRITE;
                dwDesiredAccess = FILE_MAP_WRITE;
                break;

            case Mode.readWrite:
                dwDesiredAccess2 = GENERIC_READ | GENERIC_WRITE;
                dwShareMode = FILE_SHARE_READ | FILE_SHARE_WRITE;
                dwCreationDisposition = OPEN_ALWAYS;
                flProtect = PAGE_READWRITE;
                dwDesiredAccess = FILE_MAP_WRITE;
                break;

            case Mode.readCopyOnWrite:
                if (dwVersion & 0x80000000)
                {
                    throw new FileException(filename,
                            "Win9x does not implement copy on write");
                }
                dwDesiredAccess2 = GENERIC_READ | GENERIC_WRITE;
                dwShareMode = FILE_SHARE_READ | FILE_SHARE_WRITE;
                dwCreationDisposition = OPEN_EXISTING;
                flProtect = PAGE_WRITECOPY;
                dwDesiredAccess = FILE_MAP_COPY;
                break;

            default:
                assert(0);
            }

            if (filename)
            {
                if (useWfuncs)
                {
                    auto namez = std.utf.toUTF16z(filename);
                    hFile = CreateFileW(namez,
                            dwDesiredAccess2,
                            dwShareMode,
                            null,
                            dwCreationDisposition,
                            FILE_ATTRIBUTE_NORMAL,
                            cast(HANDLE)null);
                }
                else
                {
                    auto namez = std.file.toMBSz(filename);
                    hFile = CreateFileA(namez,
                            dwDesiredAccess2,
                            dwShareMode,
                            null,
                            dwCreationDisposition,
                            FILE_ATTRIBUTE_NORMAL,
                            cast(HANDLE)null);
                }
                if (hFile == INVALID_HANDLE_VALUE)
                    goto err1;
            }
            else
                hFile = null;

            int hi = cast(int)(size>>32);
            hFileMap = CreateFileMappingA(hFile, null, flProtect,
                    hi, cast(uint)size, null);
            if (hFileMap == null)               // mapping failed
                goto err1;

            if (size == 0)
            {
                uint sizehi;
                uint sizelow = GetFileSize(hFile,&sizehi);
                size = (cast(ulong)sizehi << 32) + sizelow;
            }
            this.size = size;

            size_t initial_map = (window && 2*window<size)
                ? 2*window : cast(size_t)size;
            p = MapViewOfFileEx(hFileMap, dwDesiredAccess, 0, 0,
                    initial_map, address);
            if (!p) goto err1;
            data = p[0 .. initial_map];

            debug (MMFILE) printf("MmFile.this(): p = %p, size = %d\n", p, size);
            return;

          err1:
            if (hFileMap != null)
                CloseHandle(hFileMap);
            hFileMap = null;

            if (hFile != INVALID_HANDLE_VALUE)
                CloseHandle(hFile);
            hFile = INVALID_HANDLE_VALUE;

            errnoEnforce(false);
        }
        else version (Posix)
        {
            auto namez = toStringz(filename);
            void* p;
            int oflag;
            int fmode;

            switch (mode)
            {
            case Mode.read:
                flags = MAP_SHARED;
                prot = PROT_READ;
                oflag = O_RDONLY;
                fmode = 0;
                break;

            case Mode.readWriteNew:
                assert(size != 0);
                flags = MAP_SHARED;
                prot = PROT_READ | PROT_WRITE;
                oflag = O_CREAT | O_RDWR | O_TRUNC;
                fmode = octal!660;
                break;

            case Mode.readWrite:
                flags = MAP_SHARED;
                prot = PROT_READ | PROT_WRITE;
                oflag = O_CREAT | O_RDWR;
                fmode = octal!660;
                break;

            case Mode.readCopyOnWrite:
                flags = MAP_PRIVATE;
                prot = PROT_READ | PROT_WRITE;
                oflag = O_RDWR;
                fmode = 0;
                break;

            default:
                assert(0);
            }

            if (filename.length)
            {
                fd = .open(namez, oflag, fmode);
                errnoEnforce(fd != -1, "Could not open file "~filename);

                struct_stat64 statbuf;
                if (fstat64(fd, &statbuf))
                {
                    //printf("\tfstat error, errno = %d\n",getErrno());
                    .close(fd);
                    errnoEnforce(false, "Could not stat file "~filename);
                }

                if (prot & PROT_WRITE && size > statbuf.st_size)
                {
                    // Need to make the file size bytes big
                    .lseek(fd, cast(int)(size - 1), SEEK_SET);
                    char c = 0;
                    core.sys.posix.unistd.write(fd, &c, 1);
                }
                else if (prot & PROT_READ && size == 0)
                    size = statbuf.st_size;
            }
            else
            {
                fd = -1;
                flags |= MAP_ANON;
            }
            this.size = size;
            size_t initial_map = (window && 2*window<size)
                ? 2*window : cast(size_t)size;
            p = mmap(address, initial_map, prot, flags, fd, 0);
            if (p == MAP_FAILED) {
                if (fd != -1)
                    .close(fd);
                errnoEnforce(fd != -1, "Could not map file "~filename);
            }

            data = p[0 .. initial_map];
        }
        else
        {
            static assert(0);
        }
    }

    /**
     * Flushes pending output and closes the memory mapped file.
     */
    ~this()
    {
        debug (MMFILE) printf("MmFile.~this()\n");
        unmap();
        version (Win32)
        {
            errnoEnforce(hFileMap == null || CloseHandle(hFileMap) == TRUE,
                    "Could not close file handle");
            hFileMap = null;

            errnoEnforce(!hFile || hFile == INVALID_HANDLE_VALUE
                    || CloseHandle(hFile) == TRUE,
                    "Could not close handle");
            hFile = INVALID_HANDLE_VALUE;
        }
        else version (Posix)
        {
            errnoEnforce(fd == -1 || fd <= 2
                    || .close(fd) != -1,
                    "Could not close handle");
            fd = -1;
        }
        else
        {
            static assert(0);
        }
        data = null;
    }

    /* Flush any pending output.
     */
    void flush()
    {
        debug (MMFILE) printf("MmFile.flush()\n");
        version (Win32)
        {
            FlushViewOfFile(data.ptr, data.length);
        }
        else version (Posix)
        {
            int i;
            i = msync(cast(void*)data, data.length, MS_SYNC);   // sys/mman.h
            errnoEnforce(i == 0, "msync failed");
        }
        else
        {
            static assert(0);
        }
    }

    /**
     * Gives size in bytes of the memory mapped file.
     */
    @property ulong length()
    {
        debug (MMFILE) printf("MmFile.length()\n");
        return size;
    }

    /**
     * Read-only property returning the file mode.
     */
    Mode mode()
    {
        debug (MMFILE) printf("MmFile.mode()\n");
        return mMode;
    }

    /**
     * Returns entire file contents as an array.
     */
    void[] opSlice()
    {
        debug (MMFILE) printf("MmFile.opSlice()\n");
        return opSlice(0,size);
    }

    /**
     * Returns slice of file contents as an array.
     */
    void[] opSlice(ulong i1, ulong i2)
    {
        debug (MMFILE) printf("MmFile.opSlice(%lld, %lld)\n", i1, i2);
        ensureMapped(i1,i2);
        size_t off1 = cast(size_t)(i1-start);
        size_t off2 = cast(size_t)(i2-start);
        return data[off1 .. off2];
    }

    /**
     * Returns byte at index i in file.
     */
    ubyte opIndex(ulong i)
    {
        debug (MMFILE) printf("MmFile.opIndex(%lld)\n", i);
        ensureMapped(i);
        size_t off = cast(size_t)(i-start);
        return (cast(ubyte[])data)[off];
    }

    /**
     * Sets and returns byte at index i in file to value.
     */
    ubyte opIndexAssign(ubyte value, ulong i)
    {
        debug (MMFILE) printf("MmFile.opIndex(%lld, %d)\n", i, value);
        ensureMapped(i);
        size_t off = cast(size_t)(i-start);
        return (cast(ubyte[])data)[off] = value;
    }


    // return true if the given position is currently mapped
    private int mapped(ulong i)
    {
        debug (MMFILE) printf("MmFile.mapped(%lld, %lld, %d)\n", i,start,
                data.length);
        return i >= start && i < start+data.length;
    }

    // unmap the current range
    private void unmap()
    {
        debug (MMFILE) printf("MmFile.unmap()\n");
        version(Windows) {
            /* Note that under Windows 95, UnmapViewOfFile() seems to return
             * random values, not TRUE or FALSE.
             */
            errnoEnforce(!data || UnmapViewOfFile(data.ptr) != FALSE ||
                    (dwVersion & 0x80000000) != 0);
        } else {
            errnoEnforce(!data || munmap(cast(void*)data, data.length) == 0,
                    "munmap failed");
        }
        data = null;
    }

    // map range
    private void map(ulong start, size_t len)
    {
        debug (MMFILE) printf("MmFile.map(%lld, %d)\n", start, len);
        void* p;
        if (start+len > size)
            len = cast(size_t)(size-start);
        version(Windows) {
            uint hi = cast(uint)(start>>32);
            p = MapViewOfFileEx(hFileMap, dwDesiredAccess, hi, cast(uint)start, len, address);
            errnoEnforce(p);
        } else {
            p = mmap(address, len, prot, flags, fd, cast(int)start);
            errnoEnforce(p != MAP_FAILED);
        }
        data = p[0 .. len];
        this.start = start;
    }

    // ensure a given position is mapped
    private void ensureMapped(ulong i)
    {
        debug (MMFILE) printf("MmFile.ensureMapped(%lld)\n", i);
        if (!mapped(i)) {
            unmap();
            if (window == 0) {
                map(0,cast(size_t)size);
            } else {
                ulong block = i/window;
                if (block == 0)
                    map(0,2*window);
                else
                    map(window*(block-1),3*window);
            }
        }
    }

    // ensure a given range is mapped
    private void ensureMapped(ulong i, ulong j)
    {
        debug (MMFILE) printf("MmFile.ensureMapped(%lld, %lld)\n", i, j);
        if (!mapped(i) || !mapped(j-1)) {
            unmap();
            if (window == 0) {
                map(0,cast(size_t)size);
            } else {
                ulong iblock = i/window;
                ulong jblock = (j-1)/window;
                if (iblock == 0) {
                    map(0,cast(size_t)(window*(jblock+2)));
                } else {
                    map(window*(iblock-1),cast(size_t)(window*(jblock-iblock+3)));
                }
            }
        }
    }

private:
    string filename;
    void[] data;
    ulong  start;
    size_t window;
    ulong  size;
    Mode   mMode;
    void*  address;

    version (Win32)
    {
        HANDLE hFile = INVALID_HANDLE_VALUE;
        HANDLE hFileMap = null;
        uint dwDesiredAccess;
    }
    else version (Posix)
    {
        int fd;
        int prot;
        int flags;
        int fmode;
    }
    else
    {
        static assert(0);
    }

    // Report error, where errno gives the error number
    // void errNo()
    // {
    //     version (Win32)
    //     {
    //         throw new FileException(filename, GetLastError());
    //     }
    //     else version (linux)
    //     {
    //         throw new FileException(filename, getErrno());
    //     }
    //     else
    //     {
    //         static assert(0);
    //     }
    // }
}

unittest
{
    const size_t K = 1024;
    size_t win = 64*K; // assume the page size is 64K
    version(Win32) {
        /+ these aren't defined in std.c.windows.windows so let's use default
         SYSTEM_INFO sysinfo;
         GetSystemInfo(&sysinfo);
         win = sysinfo.dwAllocationGranularity;
         +/
    } else version (linux) {
        // getpagesize() is not defined in the unix D headers so use the guess
    }
    MmFile mf = new MmFile("testing.txt",MmFile.Mode.readWriteNew,
            100*K,null,win);
    ubyte[] str = cast(ubyte[])"1234567890";
    ubyte[] data = cast(ubyte[])mf[0 .. 10];
    data[] = str[];
    assert( mf[0 .. 10] == str );
    data = cast(ubyte[])mf[50 .. 60];
    data[] = str[];
    assert( mf[50 .. 60] == str );
    ubyte[] data2 = cast(ubyte[])mf[20*K .. 60*K];
    assert( data2.length == 40*K );
    assert( data2[$-1] == 0 );
    mf[100*K-1] = cast(ubyte)'b';
    data2 = cast(ubyte[])mf[21*K .. 100*K];
    assert( data2.length == 79*K );
    assert( data2[$-1] == 'b' );
    delete mf;
    std.file.remove("testing.txt");
    // Create anonymous mapping
    auto test = new MmFile(null, MmFile.Mode.readWriteNew, 1024*1024, null);
}
