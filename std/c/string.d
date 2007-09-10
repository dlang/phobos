
/**
 * C's &lt;string.h&gt;
 * Authors: Walter Bright, Digital Mars, www.digitalmars.com
 * License: Public Domain
 * Macros:
 *	WIKI=Phobos/StdCString
 */

module std.c.string;

extern (C):

void* memcpy(void* s1, in void* s2, size_t n);	///
void* memmove(void* s1, in void* s2, size_t n);	///
char* strcpy(char* s1, in char* s2);		///
char* strncpy(char* s1, in char* s2, size_t n);	///
char* strncat(char*  s1, in char*  s2, size_t n);	///
int strcoll(in char* s1, in char* s2);		///
int strncmp(in char* s1, in char* s2, size_t n);	///
size_t strxfrm(char*  s1, in char*  s2, size_t n);	///
const(void)* memchr(in void* s, int c, size_t n);		///
const(char)* strchr(in char* s, int c);			///
size_t strcspn(in char* s1, in char* s2);		///
const(char)* strpbrk(in char* s1, in char* s2);		///
char* strrchr(char* s, int c);			///
size_t strspn(in char* s1, in char* s2);		///
char* strstr(in char* s1, in char* s2);		///
char* strtok(in char*  s1, in char*  s2);		///
void* memset(void* s, int c, size_t n);		///
const(char)* strerror(int errnum);			///
size_t strlen(in char* s);				///
int strcmp(in char* s1, in char* s2);			///
char* strcat(char* s1, in char* s2);		///
int memcmp(in void* s1, in void* s2, size_t n);	///

version (Windows)
{
    int memicmp(in char* s1, in char* s2, size_t n);	///
}
