

module termios;

extern (C):

alias char cc_t;
alias uint speed_t;
alias uint tcflag_t;
enum { NCCS = 32 } ;

struct termios
{
    tcflag_t c_iflag;
    tcflag_t c_oflag;
    tcflag_t c_cflag;
    tcflag_t c_lflag;
    cc_t c_line;
    cc_t[NCCS] c_cc;
    speed_t c_ispeed;
    speed_t c_ospeed;
}

int tcgetattr(int fd, termios* p);

enum { TCSANOW, TCSADRAIN, TCSAFLUSH }
int tcsetattr(int fd, int tcsa, const termios* p);

void cfmakeraw(termios* p);

enum { TCIFLUSH, TCOFLUSH, TCIOFLUSH }
int tcflush(int fd, int tc_flush);

enum { TCOOFF, TCOON, TCIOFF, TCION }
int tcflow(int fd, int tc);

int tcsendbreak(int fd, int duration);
int tcdrain(int fd);

int cfsetspeed(termios* p, speed_t speed);
int cfsetispeed(termios* p, speed_t speed);
int cfsetospeed(termios* p, speed_t speed);

speed_t cfgetispeed(termios* p);
speed_t cfgetospeed(termios* p);

