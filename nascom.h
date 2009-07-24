#define VERSION "2.0"
#define YAZEVERSION "1.10"

#include <stdbool.h>

/* Z80 registers */

WORD af[2];                     /* accumulator and flags (2 banks) */
int af_sel;                     /* bank select for af */

struct ddregs regs[2];          /* bc,de,hl */
int regs_sel;                   /* bank select for ddregs */

WORD ir;                        /* other Z80 registers */
WORD ix;
WORD iy;
WORD sp;
WORD pc;
WORD IFF;

#define INSCREEN(x) (((x) >> 10) == 2)

BYTE ram[MEMSIZE*1024];         /* Z80 memory space */
#ifdef MMU
BYTE *pagetable[MEMSIZE/4];     /* MMU page table */
#endif

#ifndef LIBDIR
#define LIBDIR "/usr/local/lib/"
#endif

char *monitor;
char *progname;
bool  verbose;
unsigned char keym[9];

int setup(int, char **);
