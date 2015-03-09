/*   Virtual Nascom, a Nascom II emulator.

     Copyright (C) 2000,2009  Tommy Thorn

     Z80 emulator portition Copyright (C) 1995,1998 Frank D. Cringle.

     NasEmu is free software; you can redistribute it and/or modify it
     under the terms of the GNU General Public License as published by
     the Free Software Foundation; either version 2 of the License, or
     (at your option) any later version.

     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
     General Public License for more details.

     You should have received a copy of the GNU General Public License
     along with this program; if not, write to the Free Software
     Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
     02111-1307, USA.


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
#include "ihex.h"
#include <SDL.h>

#define FONT_H_PITCH 16
#define FONT_H       15
#define FONT_W        8

extern uint8_t nascom_font_raw[];

static SDL_Surface *screen;
static struct font {
    SDL_Surface *surf;
    int w, h, h_pitch;
} nascom_font;

FILE *serial_out, *serial_in;
int tape_led = 0;
int serial_input_available = 0;

static unsigned framebuffer_generation;

static void RenderItem(struct font *font, int idx, int x, int y)
{
    auto SDL_Rect dest = { x, y, font->w, font->h };
    SDL_Rect clip = { 0, idx * font->h_pitch, font->w, font->h };
    SDL_BlitSurface(font->surf, &clip, screen, &dest);
}

void RenderLetters(struct font *font, char *s, int x, int y)
{
    for (; *s; ++s, x += font->w)
        RenderItem(font, *s, x, y);
}

int mysetup(int argc, char **argv)
{
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
        return 1;
    }


    atexit(SDL_Quit);


    screen = SDL_SetVideoMode(48 * FONT_W, 16 * FONT_H, 8, SDL_SWSURFACE);
    if (screen == NULL) {
        fprintf(stderr, "Unable to set video: %s\n", SDL_GetError());
        return 1;
    }

    /* Set the window caption */
    SDL_WM_SetCaption("Nascom II", "Nascom II");

#if 0
    /* Populate the palette */
    SDL_Color colors[256];

    colors[0].r = colors[0].g = colors[0].b = 0;
    colors[255].r = colors[255].b = 0;
    colors[255].g = 255;

    /* Set palette */
    if (!SDL_SetColors(screen, colors, 0, 256)) {
        fprintf(stderr, "Unable to create framebuffer palette: %s\n",
                SDL_GetError());
        screen = 0; //XXX should free it
        return 1;
    }
#endif

    /* Load font */
    nascom_font.surf =
        SDL_CreateRGBSurfaceFrom(
                nascom_font_raw,
                8 /* width */,
           256*16 /* height */,
                1 /* depth */,
                1 /* pitch */,
                0 /* Rmask */,
                1 /* Gmask */,
                0 /* Bmask */,
                0 /* Amask */);
    nascom_font.w = FONT_W;
    nascom_font.h = FONT_H;
    nascom_font.h_pitch = FONT_H_PITCH;

    if (!nascom_font.surf) {
        perror("Couldn't load the font\n");
        return 1;
    }

    nascom_font.surf = SDL_DisplayFormat(nascom_font.surf);

    return 0;
}



/* */

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

    if (verbose)
        printf("Loading %s\n", file);

    ch = fgetc(f);
    rewind(f);

    if (ch == ':') {
        load_ihex(file, &RAM(0));
        return;
    }

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
    if (verbose)
        printf(". Successfully loaded %d bytes\n", count);

    if (count == 2048) {
        FILE *f;
        f = fopen("blob", "w");
        fwrite((const void *) ram, 1, 2048, f);
        fclose(f);
    }
}

static char * kbd_translation[] = {
/* 0 */  "xxzzzxxx",
/* 1 */  "xzTXF5BH",
/* 2 */  "xzYZD6NJ",
/* 3 */  "xzUSE7MK",
/* 4 */  "xzIAW8,L",
/* 5 */  "xzOQ39.;",
/* 6 */  "x[P120/'",
/* 7 */  "x]R C4VG",
/* 8 */  "xzxxx-\r\010"
};

int reset = 0;

void mainloop(void)
{
    int i = -1, bit = 0;
    unsigned last_generation = 0;

    for (;;) {
        SDL_Event event;

        while (SDL_PollEvent(&event)) {
            switch (event.type) {
            case SDL_MOUSEMOTION:
                /*printf("Mouse moved by %d,%d to (%d,%d)\n",
                  event.motion.xrel, event.motion.yrel,
                  event.motion.x, event.motion.y);*/
                break;
            case SDL_MOUSEBUTTONDOWN:
                /*printf("Mouse button %d pressed at (%d,%d)\n",
                  event.button.button, event.button.x, event.button.y);*/
                break;
            case SDL_KEYDOWN:
            case SDL_KEYUP:
                if (event.key.keysym.sym == '\\' && event.type == SDL_KEYDOWN) {
                    reset = 1;
                    break;
                }

                if (event.key.keysym.sym == 27)
                    exit(0);

                if (event.key.keysym.sym < 128) {
                    int ch = toupper(event.key.keysym.sym);
                    for (i = 0; i < 9; ++i)
                        for (bit = 0; bit < 8; ++bit)
                            if (kbd_translation[i][7-bit] == ch) {
                                goto found;
                            }
                    i = -1;
found:;
                } else {
                    switch (event.key.keysym.sym) {
                    case SDLK_LCTRL:   i = 0, bit = 3; break;
                    case SDLK_LSHIFT:
                    case SDLK_RSHIFT:  i = 0, bit = 4; break;
                    case SDLK_RCTRL:   i = 0, bit = 5; break;
                    case SDLK_UP:      i = 1, bit = 6; break;
                    case SDLK_LEFT:    i = 2, bit = 6; break;
                    case SDLK_DOWN:    i = 3, bit = 6; break;
                    case SDLK_RIGHT:   i = 4, bit = 6; break;
                    case SDLK_RMETA:
                    case SDLK_LMETA:
                    case SDLK_RALT:
                    case SDLK_LALT:    i = 5, bit = 6; break;
                    case SDLK_KP_ENTER:i = 8, bit = 6; break;
                    case SDLK_END: {
                        /* Undocumented hack */
                        FILE *f;
                        f = fopen("screendump", "w");
                        fwrite((const void *) (ram+0x800), 1, 1024, f);
                        fclose(f);
                        if (verbose) printf("Screen dumped\n");
                        break;
                    }
                    default:
                        //printf("%d? ", event.key.keysym.sym);
                        //printf(" keysym %s\n", SDL_GetKeyName(event.key.keysym.sym));
                        ;
                    }
                }

                if (i != -1) {
                    if (event.type == SDL_KEYDOWN)
                        keym[i] |= 1 << bit;
                    else
                        keym[i] &= ~(1 << bit);
                }
                break;
            case SDL_QUIT:
                //printf("Quit\n");
                return;
            default:
                //printf("Unknown event: %d\n", event.type);
                break;
            }
        }

        /* Only update the screen if the framebuffer has been written
           since last update */
        if (last_generation != framebuffer_generation) {
            int x, y;
            unsigned p = 0x800 + 10;
            last_generation = framebuffer_generation;

            for (y = 1; y < 16; ++y, p += 64) {
                for (x = 0; x < 48; ++x)
                    RenderItem(&nascom_font, RAM(p + x), x * FONT_W, y * FONT_H);
            }

            // Nascom is strange in that the last line is the first line!
            for (x = 0; x < 48; ++x)
                RenderItem(&nascom_font, RAM(p + x), x * FONT_W, 0);

            SDL_UpdateRect(screen, 0, 0, screen->w, screen->h);
            // SDL_Flip(screen); either seem to work
        }

        SDL_Delay(1000 / 30); // 30 fps
    }
}

int sim_delay()
{
    if (reset) {
        reset = 0;
        return 1;
    }

    SDL_Delay(1);

    return 0;
}

void simulate(void *dummy)
{
    simz80(pc, 900, sim_delay);
}

static void
usage(void)
{
    fprintf(stderr,
 "This is Virtual Nascom.  Usage: %s {flags} {commands}\n"
 "           -i <file>       take serial port input from file (if tape led is on)\n"
 "           -m <file>       use <file> as monitor (default is nassys3.nal)\n"
 "           -v              be verbose\n"
            ,progname);
    exit (1);
}

int main(int argc, char **argv)
{
    int c;

    serial_out = fopen("serialout.txt", "w+");

    if (!serial_out)
        exit(3);

    if (mysetup(argc, argv))
        return 1;

    monitor = "nassys3.nal";
    progname = argv[0];


#ifdef MMU
    for (c=0; c<MEMSIZE/4; ++c) pagetable[c]=ram+(c<<12);
#endif

    while ((c = getopt(argc, argv, "i:m:v")) != EOF)
        switch (c) {
        case 'i':
            serial_in = fopen(optarg, "r");
            //printf("serial input %s -> %p\n", optarg, serial_in);
            serial_input_available = !feof(serial_in);
            break;
        case 'm':
            monitor = optarg;
            break;
        case 'v':
            verbose = 1;
            break;
        case '?':
            usage();
        }

    if (verbose)
        puts("Virtual Nascom, a Nascom 2 emulator version " VERSION "\n"
             "Copyright (C) 2000-2015 Tommy Thorn.\n"
             "Uses software from \n"
             "Yet Another Z80 Emulator version " YAZEVERSION
             ", Copyright (C) 1995,1998 Frank D. Cringle.\n"
             "VirtualNascom comes with ABSOLUTELY NO WARRANTY; for details\n"
             "see the file \"COPYING\" in the distribution directory.\n");

    load_nascom(monitor);
    load_nascom("basic.nal");

    for (; optind < argc; optind++)
        load_nascom(argv[optind]);

    SDL_CreateThread((int (*)(void *))simulate, NULL);
    mainloop();

    exit(0);
}

/*
 * 1.7 Input/output port addressing
 *
 *     Output Bit
 * P0  7 Not available          7 Unused
 *     6 Not used               6 Keyboard S6
 *     5 Unused                 5 Keyboard S3
 *     4 Tape drive LED         4 Keyboard S5
 *     3 Single step            3 Keyboard S4
 *     2 Unused                 2 Keyboard S0
 *     1 Reset keyb'd count     1 Keyboard S2
 *     0 Clock keyb'd count     0 Keyboard S1
 */

#define P0_OUT_TAPE_DRIVE_LED 16
#define P0_OUT_SINGLE_STEP     8
#define P0_OUT_KEYBOARD_RESET  2
#define P0_OUT_KEYBOARD_CLOCK  1

/*
 * P1  0 - 7 Data to UART       0 - 7 Data from UART
 *     (Serial port)            (Serial port)
 *
 * P2  0 - 7 Not assigned       7 Data received from UART
 *                              6 UART TBR empty
 *                              5 Not assigned
 *                              4 Not assigned
 *                              3 F error on UART
 *                              2 P error on UART
 *                              1 O error on UART
 *                              0 Not assigned
 */

#define UART_DATA_READY 128
#define UART_TBR_EMPTY   64
#define UART_F_ERROR      8
#define UART_P_ERROR      4
#define UART_O_ERROR      2

/*
 * P3  Not assigned             Not assigned
 *
 * P4  PIO port A data input and output
 *
 * P5  PIO port B data input and output
 *
 * P6  PIO port A control
 *
 * P7  PIO port B control
 */

void out(unsigned int port, unsigned char value)
{
    unsigned int down_trans;

    if (0) fprintf(stdout, "[%02x] <- %02x\n", port, value);

    switch (port) {
    case 0:
        /* KBD */
        down_trans = port0 & ~value;
        port0 = value;

        if ((down_trans & P0_OUT_KEYBOARD_CLOCK) && keyp < 9)
            keyp++;
        if (down_trans & P0_OUT_KEYBOARD_RESET)
            keyp = 0;

#if 0
        if (tape_led != !!(value & P0_OUT_TAPE_DRIVE_LED))
            fprintf(stderr, "Tape LED = %d\n", !!(value & P0_OUT_TAPE_DRIVE_LED));
#endif
        tape_led = !!(value & P0_OUT_TAPE_DRIVE_LED);
        break;

    case 1:
        fputc(value, serial_out);
        break;

    default:
        if (verbose)
            fprintf(stdout, "OUT [%02x] <- %02x\n", port, value);
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
    case 1:
        if (serial_input_available & tape_led) {
            char ch = fgetc(serial_in);
            serial_input_available = !feof(serial_in);
            return ch;
        }
        else
            return 0;
    case 2:
        /* Status port on the UART */
        return UART_TBR_EMPTY |
            (serial_input_available & tape_led ? UART_DATA_READY : 0);
    default:
        if (verbose)
            fprintf(stdout, "IN <- [%02x]\n", port);
        return 0;
    }
}

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

            //xputch(x-10, y, v);
            //fprintf(stderr, "\033[%d;%dH%c", 1+y, 1+x-10, v);
            framebuffer_generation++;
        }
    }

    if (0x800 <= a && a < 0xE000)
        RAM(a) = v;
}
