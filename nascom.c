/*   VirtualNascom, a Nascom II emulator.

   Copyright (C) 2000  Tommy Thorn
   Copyright (C) 1995,1998  Frank D. Cringle.

NasEmu is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.



   A Nascom consists of:

    - a Z80 CPU,
    - an UART,
    - a bitmapped keyboard,
    - memory:
        0000 - 07ff  2 KB ROM monitor,
        0800 - 0bff  1 KB screen memory,
        0c00 - 0fff  1 KB workspace
        1000 - dfff       memory
        e000 - ffff  8 KB of MS Basic

  With the Z80 emulator in place the first thing to get working is the
  screen memory.  The "correct" way to simulate screen memory is to
  trap upon writes, but that would be slow.  We do it any just to get
  started.


  */

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <ctype.h>
#include "simz80.h"
#include "nascom.h"


unsigned char keym[9] = {
    0,  /* ? ? ? Shift ? ? ? ? */
    0,  /* ?!TXF5BH  ! = Up*/
    0,  /* ?!YZD6NJ  ! = Left*/
    0,  /* ?!USE7MK  ! = Down */
    0,  /* ?!IAW8,L  ! = Right */
    0,  /* ??OQ39.; */
    0,  /* ?[P120/: */
    0,  /* ?]R C4VG */
    0   /* ? ? CR - Newline BS */
};

unsigned char keyp = 0;
unsigned char port0;

static void
usage(void)
{
    fprintf(stderr,
            "Usage: %s {flags} {commands}\n"
            "           -m <file>       use <file> as monitor (default is nasysy3.nal)\n"
            "           -v              verbose\n"
            ,progname);
    exit (1);
}

void load_nascom(const char *file)
{
    FILE *f = fopen(file, "r");
    int a, b1, b2, b3, b4, b5, b6, b7, b8;
    int count = 0;
    int ch;

    if (!f) {
        perror(file);
        exit(1);
    }

    if (vflag)
        printf("Loading %s", file);

    for (; !feof(f) ;) {
        if (fscanf(f, "%x %x %x %x %x %x %x %x %x",
                   &a, &b1, &b2, &b3, &b4, &b5, &b6, &b7, &b8) == 9) {
            RAM(a)   = b1;
            RAM(a+1) = b2;
            RAM(a+2) = b3;
            RAM(a+3) = b4;
            RAM(a+4) = b5;
            RAM(a+5) = b6;
            RAM(a+6) = b7;
            RAM(a+7) = b8;
            count += 8;
        }

        do
            ch = fgetc(f);
        while (ch != -1 && ch != '\n');

        if (ch == -1)
            break;
    }

    fclose(f);
    if (vflag)
        printf(". Successfully loaded %d bytes\n", count);
}

int main(int argc, char **argv)
{
    int c;

    setup(argc, argv);

    monitor = "nassys3.nal";
    progname = argv[0];


#ifdef MMU
    for (c=0; c<MEMSIZE/4; ++c) pagetable[c]=ram+(c<<12);
#endif

    while ((c = getopt(argc, argv, "m:v")) != EOF)
        switch (c) {
        case 'm':
            monitor = optarg;
            break;
        case 'v':
            vflag = 1;
            break;
        case '?':
            usage();
        }

    if (vflag)
        puts("VirtualNascom, a Nascom 2 emulator version " VERSION "\n"
             "Copyright 2000 Tommy Thorn.  Based on\n"
             "Yet Another Z80 Emulator version " YAZEVERSION
             ", Copyright 1995,1998 Frank D. Cringle.\n"
             "NasEmu comes with ABSOLUTELY NO WARRANTY; for details\n"
             "see the file \"COPYING\" in the distribution directory.\n");

    load_nascom(monitor);
    load_nascom("basic.nal");

    for ( ; optind < argc; optind++)
        load_nascom(argv[optind]);

    simz80(pc, 20, NULL /*xhandleevent*/);

    fprintf(stderr,"HALT\n\r");
    fprintf(stderr,"PC   SP   IR   IX   IY   AF   BC   DE   HL   AF'  BC'  DE'  HL'\n\r");
    fprintf(stderr,"%04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x\n\r",pc,sp,ir,ix,iy,af[af_sel],regs[regs_sel].bc,regs[regs_sel].de,regs[regs_sel].hl,af[1-af_sel],regs[1-regs_sel].bc,regs[1-regs_sel].de,regs[1-regs_sel].hl);
    exit(0);
}

void out(unsigned int port, unsigned char value)
{
    unsigned int down_trans;

    if (0) fprintf(stdout, "[%02x] <- %02x\n", port, value);

    switch (port) {
    case 0:
        /* KBD */
        down_trans = port0 & ~value;
        port0 = value;

        if ((1 & down_trans) && keyp < 9) keyp++;
        if (2 & down_trans) keyp = 0;
        break;

    default: ;
    }
}

int in(unsigned int port)
{
    if (0) fprintf(stdout, "<- [%02x]\n", port);

    switch (port) {
    case 0:
        /* KBD */
        /* printf("[%d]", keyp); */
        return ~keym[keyp];
    case 2:
        /* Status port on the UART */
        return 0;
    default:
        return 0;
    }
}

#if 0

#include "xvirtualnascom.h"
#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>
#include <X11/Xos.h>
#include <X11/cursorfont.h>
#include <X11/Xutil.h>
#include <X11/xpm.h>

#define XK_MISCELLANY 1
#include <X11/keysymdef.h>

void slow_write(unsigned int a, unsigned char v)
{
    if (INSCREEN(a)) {
        unsigned int y = (a-0x800) / 64;
        unsigned int x = (a-0x800) % 64;
        /* fprintf(stdout, "putbyte %04x %02x '%c'\n", a, v, v); */
        if (10 <= x && x < 58 && ' ' <= v) {
            if (y == 15)
                y = 0;
            else
                ++y;

            xputch(x-10, y, v);
        }
    }
    if (0x800 <= a && a <= 0xE000)
        RAM(a) = v;
}

static char * kbd_translation[] = {
/* 0 */  "xxxxxxxx",
/* 1 */  "xyTXF5BH",
/* 2 */  "xyYZD6NJ",
/* 3 */  "xyUSE7MK",
/* 4 */  "xyIAW8,L",
/* 5 */  "xxOQ39.;",
/* 6 */  "x[P120/'",
/* 7 */  "x]R C4VG",
/* 8 */  "x\rxxx-\n\007"
};

void EventHandler(Widget w, caddr_t data, XEvent *ev)
{
    KeySym keysym;
    int i = -1, bit = 0;

    if (ev->xany.type != KeyPress && ev->xany.type != KeyRelease)
        return;

    keysym = XKeycodeToKeysym(dpy, ev->xkey.keycode, 0);

    if ((unsigned long) keysym < 128) {
        int ch = toupper(keysym);
        for (i = 0; i < 9; ++i)
            for (bit = 0; bit < 8; ++bit)
                if (kbd_translation[i][7-bit] == ch)
                    goto found;
        i = -1;
        found:;
    } else
        switch (keysym) {
        case XK_Shift_L:
        case XK_Shift_R:   i = 0, bit = 4; break;
        case XK_Up:        i = 1, bit = 6; break;
        case XK_Left:      i = 2, bit = 6; break;
        case XK_Down:      i = 3, bit = 6; break;
        case XK_Right:     i = 4, bit = 6; break;
        case XK_BackSpace: i = 8, bit = 0; break;
        case XK_Return:    i = 8, bit = 1; break;
        case XK_End: {
            /* Undocumented hack */
            FILE *f;
            f = fopen("screendump", "w");
            fwrite((const void *) (ram+0x800), 1, 1024, f);
            fclose(f);
            if (vflag) printf("Screen dumped\n");
            break;
        }}

    if (i != -1) {
        if (ev->xany.type == KeyPress)
            keym[i] |= 1 << bit;
        else
            keym[i] &= ~(1 << bit);
    }
}

#endif
