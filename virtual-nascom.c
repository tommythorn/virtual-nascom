/*   Virtual Nascom, a Nascom II emulator.

     Copyright (C) 2000,2009,2017,2018  Tommy Thorn

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
    - a UART,
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
#include <assert.h>
#include "simz80.h"
#include "nascom.h"
#include "ihex.h"
#include <SDL.h>
#ifdef __EMSCRIPTEN__
  #include <emscripten.h>
#endif


/*
 * The version of simz80 we are using doesn't could T-states, so count
 * (t_sim_delay) is given in instructions.  As a rough average, we
 * assume each instruction takes 8 T cycles (@ 4 MHz).  That means
 * that at the refresh_rate we have 4,000,000/refresh_rate/8 cycles to
 * run.
 */

#define NASCOM2_FREQUENCY    4000000
#define UI_REFRESH_RATE           60
#define ESTIMATED_CYCLES_PER_INSN  8

#define SLOW_DELAY  (NASCOM2_FREQUENCY/ESTIMATED_CYCLES_PER_INSN/UI_REFRESH_RATE)
#define FAST_DELAY 900000

static bool go_fast = false;
static int t_sim_delay = SLOW_DELAY;


/* The Nascom 2 video interface uses a 8x12 matrix for PAL (europe) and 8x14 for NTSC (US).
   The graphics character set uses the top 64 chars for a 2x3 block of "graphics", for a
   96x48 graphics.  Unfortunately the block graphic pixels are 4x5, so especially for PAL
   output looks terrible.  We use 15 for now, but it's tempting to change the graphic ROM
   use use 4x4 pixels and switch font height to 12. */

#define FONT_H_PITCH 16
#define FONT_H       15  // Actual hardware uses 14 for US/NTSC, and 12 PAL/Europe
#define FONT_W        8

#define DISPLAY_WIDTH   480
#define DISPLAY_HEIGHT  256
#define DISPLAY_X_OFFSET 48
#define DISPLAY_Y_OFFSET  8

extern uint8_t nascom_font_raw[];

static SDL_Window *screen;
static SDL_Renderer *rend;
static SDL_Texture *texture;
static uint32_t pixmap[DISPLAY_HEIGHT * DISPLAY_WIDTH];

static FILE *serial_out, *serial_in;
static int tape_led = 0;
static int tape_led_force = 0;
static int serial_input_available = 0;

static void RenderItem(int idx, int xp, int yp)
{
	uint8_t *p = nascom_font_raw + 16 * idx;
	uint32_t *r = pixmap + DISPLAY_X_OFFSET +
	        DISPLAY_Y_OFFSET * DISPLAY_WIDTH +
	        /* Only this bit is actually not part of a constant */
	        xp + yp * DISPLAY_WIDTH;
	int8_t y, x;
	for (y = 0; y < FONT_H; y++) {
		uint8_t c = *p;
		for (x = FONT_W - 1; x >= 0; x--)
			*r++ = (c & (1 << x)) ? 0xFFFFFFFF : 0;
                r += DISPLAY_WIDTH - 8;
		p++;
	}
}

/* The keyboard holds the state state of every depressed key and a
   current scanning pointer. */

static struct {
    unsigned char mask[9];
    unsigned char index;
} keyboard = {
    {
        0,  /*     ? Sh ?  ?  ?  ?  */
        0,  /* Up T  X  F  5  B  H  */
        0,  /* Lt Y  Z  D  6  N  J  */
        0,  /* Dn U  S  E  7  M  K  */
        0,  /* Rt I  A  W  8  ,  L  */
        0,  /* Gr O  Q  3  9  .  ;  */
        0,  /* [  P  1  2  0  /  :  */
        0,  /* ]  R  Sp C  4  V  G  */
        0   /* Ch @  Sh Ct -  Nl Bs */
    },
    0};

static char * kbd_translation[] = {
/* 0 */  "_\t@__-\r\010",
/* 1 */  "__TXF5BH",
/* 2 */  "__YZD6NJ",
/* 3 */  "__USE7MK",
/* 4 */  "__IAW8,L",
/* 5 */  "__OQ39.;",
/* 6 */  "_[P120/:",
/* 7 */  "_]R C4VG",
};

#define ___ " " // Dummy
static const char
kbd_us_shift[] = ";:'\"[{]}\\|-_=+`~1!2@3#4$5%6^7&8*9(0),<.>/?";
static const char
kbd_spec          [] = ";" ":" "["    "]" "-" "," "." "/"    "0" "1" "2"  "3" "4" "5" "6" "7" "8" "9" " ";
static const char
kbd_spec_w_shift  [] = "+" "*" "\\"   "_" "=" "<" ">" "?"    "^" "!" "\"" "#" "$" "%" "&" "'" "(" ")" ___;
static const char
kbd_spec_w_ctrl   [] = "{" ___ "\033" ___ ___ ___ ___ ___    ___ ___ ___  ___ ___ ___ ___ ___ ___ ___ "`";
static const char
kbd_spec_w_shctrl [] = ___ ___ ___    ___ "}" "|" "~" "\177" ___ ___ ___  ___ ___ ___ ___ ___ ___ ___ ___;

typedef enum { CONT = 0, RESET = 1, DONE = -1 } sim_action_t;
static sim_action_t action = CONT;

// Ctr-Shift-Meta 0 -> the REAL # (instead of the pound symbol)
// Ctrl-Space -> `

static void handle_key_event_dwim(SDL_Keysym keysym, bool keydown);
static void handle_key_event_raw(SDL_Keysym keysym, bool keydown);

static void (*handle_key_event)(SDL_Keysym, bool) = handle_key_event_dwim;

static void handle_app_control(SDL_Keysym keysym)
{
    switch (keysym.sym) {
    case SDLK_END: {
        FILE *f;
        f = fopen("screendump", "a+");
        fwrite((const void *) (ram+0x800), 1, 1024, f);
        fclose(f);
        if (verbose) printf("Screen dumped\n");
        break;
    }

    case SDLK_F4:
        action = DONE;
        break;

    case SDLK_F5:
        go_fast = !go_fast;
        printf("Switch to %s\n", go_fast ? "fast" : "slow");

        t_sim_delay = go_fast ? FAST_DELAY : SLOW_DELAY;
        break;

    case SDLK_F6:
        tape_led = tape_led_force ^= 1;
        break;

    case SDLK_F9:
        action = RESET;
        break;

    case SDLK_F10:
        if (handle_key_event == handle_key_event_raw)
            handle_key_event = handle_key_event_dwim;
        else
            handle_key_event = handle_key_event_raw;

        printf("Switch to %s keyboard\n",
               handle_key_event == handle_key_event_raw ? "raw" : "dwim");
        break;

    default:
        ;
    }
}

/*
 * Theory of operation: we first translate the SDL into the
 * corresponding key the user pressed (eg. ':' will show up as ';' +
 * shift modifier).  This assumes US keyboard, sorry (I'm not sure how
 * to handle this better).
 *
 * Next we try to find what you would have had to press on the Nascom
 * 2 keyboard to get that.
 *
 * Yes, this would all be faster (and simpler) by being completely
 * table driven), (x,y,shift,ctrl,graph) = table[sym, mod];
 */
static void handle_key_event_dwim(SDL_Keysym keysym, bool keydown)
{
    memset(keyboard.mask, 0, sizeof keyboard.mask);

    if (!keydown)
        return;

    /*** Step 1: Translate SDL keyboard events into ASCII ***/

    bool emu_shift = (keysym.mod & (KMOD_RSHIFT | KMOD_LSHIFT)) != 0;
    bool emu_ctrl  = (keysym.mod & (KMOD_RCTRL  | KMOD_LCTRL))  != 0;
    bool emu_graph = (keysym.mod & (KMOD_RALT   | KMOD_LALT))   != 0;
    int  ch        = 0;

    switch (keysym.sym) {
    case SDLK_UP:      break;
    case SDLK_LEFT:    break;
    case SDLK_DOWN:    break;
    case SDLK_RIGHT:   break;
    default:
        if (128 < keysym.sym) {
            handle_app_control(keysym);
            return;
        }
        ch = toupper((uint8_t)keysym.sym);
    }

    /* Translate shifted keys */
    if (emu_shift)
        for (int i = 0; kbd_us_shift[i]; i += 2) {
            if (kbd_us_shift[i] == ch) {
                ch = kbd_us_shift[i+1];
                emu_shift = false;
                break;
            }
        }

    /*** Step 2: Translate the ASCII to Nascom keyboard events ***/

    // Quick hack to enable LF (which is shift-CH)
    if (ch == '\t' && emu_shift) {
        emu_shift = true;
    }

#if 0
    // HACKS THAT TECHNICALLY BREAK FAITHFUL EMULATION
    // The gylphs for '#' is £ but there exist a gylph that looks right
    if (ch == '#') {
        ch = '0';
        emu_shift = true;
        emu_ctrl  = true;
        emu_graph = true;
        goto search;
    }

    // The glyph for '^' is ↑ but there exist a gylph that looks right
    if (ch == '^') {
        emu_shift = false;
        emu_ctrl  = false;
        emu_graph = true;
        ch = '3';
        goto search;
    }

    // Other things: | and ~ doesn't look quite like their modern versions,
    // but there doesn't appear to be a good alternative
#endif

    // ' ' has to be special cased because it's the NOT_ITEM above
    if (ch == ' ')
        goto search;

    // '@' is also special
    if (ch == '@') {
        emu_shift = true;
        goto search;
    }

    for (int i = 0; kbd_spec_w_shift[i]; ++i)
        if (kbd_spec_w_shift[i] == ch) {
            emu_shift = true;
            ch = kbd_spec[i];
            goto search;
        }

    for (int i = 0; kbd_spec_w_ctrl[i]; ++i)
        if (kbd_spec_w_ctrl[i] == ch) {
            emu_shift = false;
            emu_ctrl = true;
            ch = kbd_spec[i];
            goto search;
        }

    for (int i = 0; kbd_spec_w_shctrl[i]; ++i)
        if (kbd_spec_w_shctrl[i] == ch) {
            emu_shift = true;
            emu_ctrl = true;
            ch = kbd_spec[i];
            goto search;
        }

search:
    keyboard.mask[0] |= emu_shift << 4;
    keyboard.mask[0] |= emu_ctrl  << 3;
    keyboard.mask[5] |= emu_graph << 6;

    if (keysym.sym < 128) {
        for (unsigned row = 0; row < 8; ++row)
            for (unsigned col = 0; col < 7; ++col)
                if (kbd_translation[row][7-col] == ch) {
                    keyboard.mask[row] |= 1 << col;
                    return;
                }
    } else {
        switch (keysym.sym) {
        case SDLK_UP:    keyboard.mask[1] |= 1 << 6; break;
        case SDLK_LEFT:  keyboard.mask[2] |= 1 << 6; break;
        case SDLK_DOWN:  keyboard.mask[3] |= 1 << 6; break;
        case SDLK_RIGHT: keyboard.mask[4] |= 1 << 6; break;
        default:
            handle_app_control(keysym);
        }
    }
}

static void handle_key_event_raw(SDL_Keysym keysym, bool keydown)
{
    int i = -1, bit = 0;

    // We need this to be able to share kbd_translation between the
    // RAW and the DWIM variant
    if (keysym.sym == '\'')
        keysym.sym = ':';

    if (keysym.sym < 128) {
        int ch = toupper(keysym.sym);
        for (i = 0; i < 8; ++i)
            for (bit = 0; bit < 7; ++bit)
                if (kbd_translation[i][7-bit] == ch) {
                    goto translate;
                }
        i = -1;
translate:;
    } else {
        switch (keysym.sym) {
        // case Newline  i = 0, bit = 5; break;
        // case '@':     i = 0, bit = 5; break;
        case SDLK_LCTRL:
        case SDLK_RCTRL:   i = 0, bit = 3; break;

        case SDLK_LSHIFT:
        case SDLK_RSHIFT:  i = 0, bit = 4; break;

        case SDLK_UP:      i = 1, bit = 6; break;
        case SDLK_LEFT:    i = 2, bit = 6; break;
        case SDLK_DOWN:    i = 3, bit = 6; break;
        case SDLK_RIGHT:   i = 4, bit = 6; break;

        case SDLK_LGUI:
        case SDLK_RGUI:
        case SDLK_LALT:
        case SDLK_RALT:    i = 5, bit = 6; break;

        case SDLK_KP_ENTER:i = 0, bit = 6; break;
        default:
            if (keydown)
                handle_app_control(keysym);
            return;
        }
    }

    if (i != -1) {
        if (keydown)
            keyboard.mask[i] |= 1 << bit;
        else
            keyboard.mask[i] &= ~(1 << bit);
    }
}

static void load_nascom(const char *file)
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
}

static void save_nascom(int start, int end, const char *name)
{
    FILE *f = fopen(name, "w+");

    if (!f) {
        perror(name);
        return;
    }

    for (uint8_t *p = ram + start; start < end; p += 8, start += 8)
        fprintf(f, "%04X %02X %02X %02X %02X %02X %02X %02X %02X %02X%c%c\r\n",
                start, *p, p[1], p[2], p[3], p[4], p[5], p[6], p[7], 0, 8, 8);

    fclose(f);
}

static void ui_serve_input(void)
{
    SDL_Event event;

    if (SDL_PollEvent(&event)) {
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
            handle_key_event(event.key.keysym, event.type == SDL_KEYDOWN);
            break;
        case SDL_QUIT:
            //printf("Quit\n");
            return;
        default:
            //printf("Unknown event: %d\n", event.type);
            break;
        }
    }
}

/* Would be better to do the updating on demand and the push here */
static void ui_display_refresh(void)
{
    static uint8_t screencache[1024] = { 0 };
    bool dirty = false;

    for (uint8_t *p0 = ram + 0x80A, *q0 = screencache + 0xA;
         p0 < ram + 0xC00; p0 += 64, q0 += 64)
        for (unsigned char *p = p0, *q = q0; p < p0 + 48; ++p, ++q)
            if (*q != *p) {
                *q = *p;
                unsigned index = p - ram - 0x800;
                unsigned x     = index % 64 - 10;
                unsigned y     = index / 64;
                y = (y + 1) % 16; // The last line is the first line

                RenderItem(*p, x * FONT_W, y * FONT_H);
                dirty = true;
            }

    if (dirty) {
	SDL_Rect sr;
	sr.x = 0;
	sr.y = 0;
	sr.w = DISPLAY_WIDTH;
	sr.h = DISPLAY_HEIGHT;
	SDL_UpdateTexture(texture, NULL, pixmap, DISPLAY_WIDTH * 4);
	SDL_RenderClear(rend);
	SDL_RenderCopy(rend, texture, NULL, &sr);
	SDL_RenderPresent(rend);
    }
}

static int sim_delay(void)
{
    ui_display_refresh();

    SDL_Delay(1000/UI_REFRESH_RATE);

    return action;
}

static void
usage(void)
{
    fprintf(stderr,
 "This is Virtual Nascom.  Usage: %s {flags} files\n"
 "           -i <file>       take serial port input from file (if tape led is on)\n"
 "           -m <file>       use <file> as monitor (default is nassys3.nal)\n"
 "           -v              be verbose\n"
            ,progname);
    exit (1);
}

static int mysetup(int argc, char **argv);

#ifdef __EMSCRIPTEN__
static int em_sim_delay(void) {
    ui_display_refresh();
    return DONE;
}

static void em_main_loop(void) {
    simz80(pc, t_sim_delay, em_sim_delay);
}

EMSCRIPTEN_KEEPALIVE void reset_nascom() {
    pc = 0;
}

EMSCRIPTEN_KEEPALIVE void load_nascom_string(const char *str) {
    int a, b1, b2, b3, b4, b5, b6, b7, b8;
    int len = strlen(str);
    int i = 0;
    int count = 0;
    while (i < len) {
        if (sscanf(&(str[i]), "%x %x %x %x %x %x %x %x %x",
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
    i += 34;
    while (i < len && str[i] != '\n')
        i++;
  }
  if (verbose)
      printf(". Successfully loaded %d bytes\n", count);
}

static char     *cas_input_data  = NULL;
static uint32_t  cas_input_len   = 0;
static uint32_t  cas_input_index = 0;
EMSCRIPTEN_KEEPALIVE void cas_load_input(const char *str, uint32_t len) {
  if (cas_input_data) {
    free(cas_input_data);
  }
  cas_input_len  = len;
  cas_input_data = malloc(cas_input_len);
  memcpy(cas_input_data, str, cas_input_len);
  cas_input_index = 0;
//  fprintf(stdout, "cas_load_input: len: %d\n", cas_input_len);
}
EMSCRIPTEN_KEEPALIVE void cas_rewind() {
  cas_input_index = 0;
}
EMSCRIPTEN_KEEPALIVE uint8_t cas_get_next() {
//  fprintf(stdout, "cas_get_next called -> ");
  uint8_t retValue = 0;
  if (cas_input_data && cas_input_index < cas_input_len) {
    retValue = cas_input_data[cas_input_index++];
  }
//  fprintf(stdout, "%d\n", retValue);
  return retValue;
}
EMSCRIPTEN_KEEPALIVE uint8_t cas_eof() {
  return (cas_input_data == NULL || cas_input_index >= cas_input_len);
}
#endif

int main(int argc, char **argv)
{
    int c;

    serial_out = fopen("serialout.txt", "ab+");

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
            serial_in = fopen(optarg, "rb");
            if (!serial_in)
                perror(optarg), exit(1);
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

    puts("Virtual Nascom, a Nascom 2 emulator version " VERSION "\n"
         "Copyright (C) 2000,2009,2017,2018,2021  Tommy Thorn.\n"
         "http://github.com/tommythorn/virtual-nascom.git\n"
         "Uses software from Yet Another Z80 Emulator version "YAZEVERSION
         ", Copyright (C) 1995,1998 Frank D. Cringle.\n"
         "Virtual Nascom comes with ABSOLUTELY NO WARRANTY; for details\n"
         "see the file \"COPYING\" in the distribution directory.\n"
         "\n"
         "The emulator dumps the memory state in `memorydump.nas`\n"
         "upon exit so one might resume execution later on.\n"
         "\n"
         "The following keys are supported:\n"
         "\n"
         "* END - leaves a screendump in `screendump`\n"
         "* F4 - exits the emulator\n"
         "* F5 - toggles between stupidly fast and \"normal\" speed\n"
         "* F6 - force serial input on\n"
         "* F9 - resets the emulated Nascom\n"
         "* F10 - toggles between \"raw\" and \"natural\" keyboard emulation\n"
         "\n"
         "All serial output is appended to `serialout.txt` which may be fed back\n"
         "in on a subsequent launch via the `-i` option.\n");

    load_nascom(monitor);
    load_nascom("basic.nal");

    for (; optind < argc; optind++)
        load_nascom(argv[optind]);

    ram[0x10000] = ram[0]; // Make GetWord[0xFFFF) work correctly

    puts("Starting Z80 Simulator\n");
#ifdef __EMSCRIPTEN__
    emscripten_set_main_loop(em_main_loop, 0, 1); // Use default refresh rate (60fps)
#else
    simz80(pc, t_sim_delay, sim_delay);
#endif
    puts("Stopped Z80 Simulator\n");

    save_nascom(0x800, 0x10000, "memorydump.nas");

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
    static unsigned char port0;

    switch (port) {
    case 0:;
        /* KBD */
        uint8_t posedge = ~port0 & value;
        port0 = value;

        if (value & P0_OUT_KEYBOARD_RESET) {
            ui_serve_input();
            keyboard.index = 0;
            port0 = P0_OUT_KEYBOARD_CLOCK;
        } else if ((posedge & P0_OUT_KEYBOARD_CLOCK))
            keyboard.index = (keyboard.index + 1) & 7;
#if 0
        if (tape_led != !!(value & P0_OUT_TAPE_DRIVE_LED))
            fprintf(stderr, "Tape LED = %d\n", !!(value & P0_OUT_TAPE_DRIVE_LED));
#endif
        tape_led = !!(value & P0_OUT_TAPE_DRIVE_LED) | tape_led_force;
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
        /* printf("[%d]", keyboard.index); */
        assert(keyboard.index < 8);
        return ~keyboard.mask[keyboard.index];
#ifdef __EMSCRIPTEN__
    case 1:
        if (verbose) {
          static uint32_t pcount1 = 0;
          if (pcount1++ > 5000) {
            fprintf(stdout, "%d: in(1): tape_led:%d, cas_eof():%d\n", pcount1, tape_led, cas_eof());
            pcount1 = 0;
          }
        }
        if (!cas_eof() && tape_led) {
            return cas_get_next();
        }
        return 0;
    case 2:
        /* Status port on the UART */
        if (verbose) {
          static uint32_t pcount2 = 0;
          if (pcount2++ > 5000) {
            fprintf(stdout, "%d: in(2): tape_led:%d, cas_eof():%d\n", pcount2, tape_led, cas_eof());
            pcount2 = 0;
          }
        }
        return UART_TBR_EMPTY |
            ((!cas_eof() && tape_led) ? UART_DATA_READY : 0);
#else
    case 1:
        if (serial_input_available & tape_led) {
            uint8_t ch = fgetc(serial_in);
            serial_input_available = feof(serial_in) == 0;
            if (verbose) {
              static uint32_t byte_count = 0;
              fprintf(stdout, "%04x: IN(%02x) -> %02x, serial_input_available: %d\n", byte_count, port, ch, serial_input_available);
              byte_count++;
            }
            return ch;
        }
        else
            return 0;
    case 2: {
        /* Status port on the UART */
        uint8_t retVal;
        retVal = UART_TBR_EMPTY | (serial_input_available && tape_led ? UART_DATA_READY : 0);
        return retVal;
    }
#endif            
    default:
        if (verbose)
            fprintf(stdout, "IN <- [%02x]\n", port);
        return 0;
    }
}

static int mysetup(int argc, char **argv)
{
#ifdef __EMSCRIPTEN__
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
#else
    if (SDL_Init(SDL_INIT_EVERYTHING) < 0) {
#endif
        fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
        return 1;
    }

    atexit(SDL_Quit);

    screen = SDL_CreateWindow("Nascom 2",
		SDL_WINDOWPOS_UNDEFINED,
		SDL_WINDOWPOS_UNDEFINED,
		DISPLAY_WIDTH, DISPLAY_HEIGHT,
		SDL_WINDOW_RESIZABLE);

    if (screen == NULL) {
        fprintf(stderr, "Unable to create window: %s\n", SDL_GetError());
        return 1;
    }

    rend = SDL_CreateRenderer(screen, -1, 0);
    if (rend == NULL) {
	fprintf(stderr, "Unable to create renderer: %s\n", SDL_GetError());
	return 1;
    }

    if (texture)
	SDL_DestroyTexture(texture);

    texture = SDL_CreateTexture(rend, SDL_PIXELFORMAT_ARGB8888,
	SDL_TEXTUREACCESS_STREAMING, DISPLAY_WIDTH, DISPLAY_HEIGHT);
    if (texture == NULL) {
	fprintf(stderr, "Unable to create display texture: %s\n", SDL_GetError());
	return 1;
    }

    SDL_SetRenderDrawColor(rend, 0, 0, 0, 255);
    SDL_RenderClear(rend);
    SDL_RenderPresent(rend);

    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "linear");
    SDL_RenderSetLogicalSize(rend, DISPLAY_WIDTH, DISPLAY_HEIGHT);

    return 0;
}
