// Written in the D programming language

/*
        Copyright (C) 2004 Christopher E. Miller

        This software is provided 'as-is', without any express or implied
        warranty.  In no event will the authors be held liable for any damages
        arising from the use of this software.

        Permission is granted to anyone to use this software for any purpose,
        including commercial applications, and to alter it and redistribute it
        freely, subject to the following restrictions:

        1. The origin of this software must not be misrepresented; you must not
           claim that you wrote the original software. If you use this software
           in a product, an acknowledgment in the product documentation would be
           appreciated but is not required.
        2. Altered source versions must be plainly marked as such, and must not be
           misrepresented as being the original software.
        3. This notice may not be removed or altered from any source distribution.
*/

/**************
 * $(RED Warning: This module is considered out-dated and not up to Phobos'
 *       current standards. It will remain until we have a suitable replacement,
 *       but be aware that it will not remain long term.)
 *
 * $(D SocketStream) is a stream for a blocking,
 * connected $(D Socket).
 *
 * Example:
 *      See $(SAMPLESRC htmlget.d)
 * Authors: Christopher E. Miller
 * References:
 *      $(LINK2 std_stream.html, std.stream)
 * Source:    $(PHOBOSSRC std/_socketstream.d)
 * Macros: WIKI=Phobos/StdSocketstream
 */

module std.socketstream;

private import std.stream;
private import std.socket;

/**************
 * $(D SocketStream) is a stream for a blocking,
 * connected $(D Socket).
 */
class SocketStream: Stream
{
    private:
        Socket sock;

    public:

        /**
         * Constructs a SocketStream with the specified Socket and FileMode flags.
         */
        this(Socket sock, FileMode mode)
        {
            if(mode & FileMode.In)
                readable = true;
            if(mode & FileMode.Out)
                writeable = true;

            this.sock = sock;
        }

        /**
         * Uses mode $(D FileMode.In | FileMode.Out).
         */
        this(Socket sock)
        {
            writeable = readable = true;
            this.sock = sock;
        }

        /**
         * Property to get the $(D Socket) that is being streamed.
         */
        Socket socket()
        {
            return sock;
        }

        /**
         * Attempts to read the entire block, waiting if necessary.
         */
        override size_t readBlock(void* _buffer, size_t size)
        {
            ubyte* buffer = cast(ubyte*)_buffer;
            assertReadable();

            if (size == 0)
                return size;

            auto len = sock.receive(buffer[0 .. size]);
            readEOF = cast(bool)(len == 0);
            if (len == sock.ERROR)
                len = 0;
            return len;
        }

        /**
         * Attempts to write the entire block, waiting if necessary.
         */
        override size_t writeBlock(const void* _buffer, size_t size)
        {
            ubyte* buffer = cast(ubyte*)_buffer;
            assertWriteable();

            if (size == 0)
                return size;

            auto len = sock.send(buffer[0 .. size]);
            readEOF = cast(bool)(len == 0);
            if (len == sock.ERROR)
                len = 0;
            return len;
        }

        /**
         * Socket streams do not support seeking. This disabled method throws
         * a $(D SeekException).
         */
        @disable override ulong seek(long offset, SeekPos whence)
        {
            throw new SeekException("Cannot seek a socket.");
        }

        /**
         * Does not return the entire stream because that would
         * require the remote connection to be closed.
         */
        override string toString()
        {
            return sock.toString();
        }

        /**
         * Close the $(D Socket).
         */
        override void close()
        {
            sock.close();
            super.close();
        }
}

