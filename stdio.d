
extern (C):

const int _NFILE = 60;
const int BUFSIZ = 0x4000;
const int EOF = -1;
const int FOPEN_MAX = 20;
const int FILENAME_MAX = 256;  // 255 plus NULL
const int TMP_MAX = 32767;
const int _SYS_OPEN = 20;
const int SYS_OPEN = _SYS_OPEN;

const wchar WEOF = 0xFFFF;

enum { SEEK_SET, SEEK_CUR, SEEK_END }

alias uint size_t;

struct _iobuf
{
    align (1):
	char	*_ptr;
	int	_cnt;
	char	*_base;
	int	_flag;
	int	_file;
	int	_charbuf;
	int	_bufsiz;
	int	__tmpnum;
}

alias _iobuf FILE;

enum
{
    _F_RDWR = 0x0003,
    _F_READ = 0x0001,
    _F_WRIT = 0x0002,
    _F_BUF  = 0x0004,
    _F_LBUF = 0x0008,
    _F_ERR  = 0x0010,
    _F_EOF  = 0x0020,
    _F_BIN  = 0x0040,
    _F_IN   = 0x0080,
    _F_OUT  = 0x0100,
    _F_TERM = 0x0200,
}

FILE _iob[_NFILE];	// BUG: should be extern

enum
{
    _IOREAD	= 1,
    _IOWRT	= 2,
    _IONBF	= 4,
    _IOMYBUF	= 8,
    _IOEOF	= 0x10,
    _IOERR	= 0x20,
    _IOLBF	= 0x40,
    _IOSTRG     = 0x40,
    _IORW	= 0x80,
    _IOFBF	= 0,
    _IOAPP	= 0x200,
    _IOTRAN	= 0x100,
}

const FILE *stdin  = &_iob[0];
const FILE *stdout = &_iob[1];
const FILE *stderr = &_iob[2];
const FILE *stdaux = &_iob[3];
const FILE *stdprn = &_iob[4];

const char[] _P_tmpdir = "\\";
const wchar[] _wP_tmpdir = "\\";
const int L_tmpnam = _P_tmpdir.length + 12;

alias int fpos_t;

alias ubyte* va_list;

char *	 tmpnam(char *);
FILE *	 fopen(char *,char *);
FILE *	 _fsopen(char *,char *,int );
FILE *	 freopen(char *,char *,FILE *);
int	 fseek(FILE *,int,int);
int	 ftell(FILE *);
char *	 fgets(char *,int,FILE *);
int	 fgetc(FILE *);
int	 _fgetchar(void);
int	 fflush(FILE *);
int	 fclose(FILE *);
int	 fputs(char *,FILE *);
char *	 gets(char *);
int	 fputc(int,FILE *);
int	 _fputchar(int);
int	 puts(char *);
int	 ungetc(int,FILE *);
size_t	 fread(void *,size_t,size_t,FILE *);
size_t	 fwrite(void *,size_t,size_t,FILE *);
int	 printf(char *,...);
int	 fprintf(FILE *,char *,...);
int	 vfprintf(FILE *,char *,va_list);
int	 vprintf(char *,va_list);
int	 sprintf(char *,char *,...);
int	 vsprintf(char *,char *,va_list);
int	 scanf(char *,...);
int	 fscanf(FILE *,char *,...);
int	 sscanf(char *,char *,...);
void	 setbuf(FILE *,char *);
int	 setvbuf(FILE *,char *,int,size_t);
int	 remove(char *);
int	 rename(char *,char *);
void	 perror(char *);
int	 fgetpos(FILE *,fpos_t *);
int	 fsetpos(FILE *,fpos_t *);
FILE *	 tmpfile(void);
int	 _rmtmp(void);
int      _fillbuf(FILE *);
int      _flushbu(int, FILE *);

int  getw(FILE *FHdl);
int  putw(int Word, FILE *FilePtr);

int  getchar()		{ return getc(stdin);		}
int  putchar(int c)	{ return putc(c,stdout);	}
int  getc(FILE *fp)	{ return fgetc(fp);		}
int  putc(int c,FILE *fp) { return fputc(c,fp);		}
int  ferror(FILE *fp)	{ return fp._flag&_IOERR;	}
int  feof(FILE *fp)	{ return fp._flag&_IOEOF;	}
void clearerr(FILE *fp)	{ fp._flag &= ~(_IOERR|_IOEOF); }
void rewind(FILE *fp)	{ fseek(fp,0L,SEEK_SET); fp._flag&=~_IOERR; }
int  _bufsize(FILE *fp)	{ return fp._bufsiz; }
int  fileno(FILE *fp)	{ return fp._file; }

int      unlink(char *);
FILE *	 fdopen(int, char *);
int	 fgetchar(void);
int	 fputchar(int);
int	 fcloseall(void);
int	 filesize(char *);
int	 flushall(void);
int	 getch(void);
int	 getche(void);
int      kbhit(void);
char *   tempnam (char *dir, char *pfx);
int      _snprintf(char *,size_t,char *,...);
int	 _vsnprintf(char *,size_t,char *,va_list);

wchar *  _wtmpnam(wchar *);
FILE *  _wfopen(wchar *, wchar *);
FILE *  _wfsopen(wchar *, wchar *, int);
FILE *  _wfreopen(wchar *, wchar *, FILE *);
wchar *  fgetws(wchar *, int, FILE *);
int  fputws(wchar *, FILE *);
wchar *  _getws(wchar *);
int  _putws(wchar *);
int  wprintf(wchar *, ...);
int  fwprintf(FILE *, wchar *, ...);
int  vwprintf(wchar *, va_list);
int  vfwprintf(FILE *, wchar *, va_list);
int  swprintf(wchar *, wchar *, ...);
int  vswprintf(wchar *, wchar *, va_list);
int  _snwprintf(wchar *, size_t, wchar *, ...);
int  _vsnwprintf(wchar *, size_t, wchar *, va_list);
int  wscanf(wchar *, ...);
int  fwscanf(FILE *, wchar *, ...);
int  swscanf(wchar *, wchar *, ...);
int  _wremove(wchar *);
void  _wperror(wchar *);
FILE *  _wfdopen(int, wchar *);
wchar *  _wtempnam(wchar *, wchar *);
wchar  fgetwc(FILE *);
wchar  _fgetwchar(void);
wchar  fputwc(wchar, FILE *);
wchar  _fputwchar(wchar);
wchar  getwchar(void);
wchar  ungetwc(wchar, FILE *);

wchar	 getwchar()		{ return fgetwc(stdin); }
wchar	 putwchar(wchar c)	{ return fputwc(c,stdout); }
wchar	 getwc(FILE *fp)	{ return fgetwc(fp); }
wchar	 putwc(wchar c, FILE *fp)	{ return fputwc(c, fp); }

