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
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <sys/types.h>
#include <sys/stat.h>

#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>
#include <X11/Xos.h>
#include <X11/cursorfont.h>
#include <X11/Xutil.h>
#include <X11/xpm.h>

#define XK_MISCELLANY 1
#include <X11/keysymdef.h>
#include <ctype.h>

#include "simz80.h"
#include "xvirtualnascom.h"

#define VERSION	"1.0"
#define YAZEVERSION "1.10"


/* Z80 registers */

WORD af[2];			/* accumulator and flags (2 banks) */
int af_sel;			/* bank select for af */

struct ddregs regs[2];		/* bc,de,hl */
int regs_sel;			/* bank select for ddregs */

WORD ir;			/* other Z80 registers */
WORD ix;
WORD iy;
WORD sp;
WORD pc;
WORD IFF;

BYTE ram[MEMSIZE*1024];		/* Z80 memory space */
#ifdef MMU
BYTE *pagetable[MEMSIZE/4];	/* MMU page table */
#endif

#ifndef LIBDIR
#define LIBDIR "/usr/local/lib/"
#endif

static char *monitor = "nassys3.nal";
static char *progname;
static int  vflag = 0;

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

void load_nascom(char *file)
{
  FILE *f = fopen(file, "r");
  int a, b1, b2, b3, b4, b5, b6, b7, b8;
  int count = 0;
  int ch;

  if (!f) {
    perror(file);
    exit(1);
  }

  if (vflag) printf("Loading %s", file);
  for (;!feof(f);) {
    if (fscanf(f, "%x %x %x %x %x %x %x %x %x",
	       &a, &b1, &b2, &b3, &b4, &b5, &b6, &b7, &b8)
	== 9) {
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
  if (vflag) printf(". Successfully loaded %d bytes\n", count);
}

extern char *optarg;
extern int optind, opterr, optopt;
int getopt(int argc, char * const *argv, const char *optstring);

int main(int argc, char **argv)
{
  int c;
  
  progname = argv[0];

  xsetup(1, argv);
    

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

  simz80(pc, 20, xhandleevent);

  fprintf(stderr,"HALT\n\r");
  fprintf(stderr,"PC   SP   IR   IX   IY   AF   BC   DE   HL   AF'  BC'  DE'  HL'\n\r");
  fprintf(stderr,"%04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x\n\r",pc,sp,ir,ix,iy,af[af_sel],regs[regs_sel].bc,regs[regs_sel].de,regs[regs_sel].hl,af[1-af_sel],regs[1-regs_sel].bc,regs[1-regs_sel].de,regs[1-regs_sel].hl);
  exit(0);
}

#ifndef USE_GNU_READLINE
void *
xmalloc(size_t size)
{
    void *p = malloc(size);

    if (p == NULL) {
	fputs("insufficient memory\n", stderr);
	exit(1);
    }
    return p;
}
#endif






#include "chars.xpm"

#define APP_NAME		"xnasemu"
#define APP_CLASS		"XNasemu"

# define RightButton		Button3
# define MiddleButton		Button2
# define LeftButton		Button1
# define RightButtonMask	Button3Mask
# define MiddleButtonMask	Button2Mask
# define LeftButtonMask		Button1Mask

/*
 * If MAXARGS isn't enough to hold all the arguments you pass any Xt
 * procedure, the program aborts
 */
#define MAXARGS 32
static int nargs;
static Arg wargs[MAXARGS];
#define startargs()		nargs = 0
#define setarg(name, value)	\
	if (nargs < MAXARGS) \
		XtSetArg(wargs[nargs], name, value), nargs++; \
	else \
		abort()

static Cursor WorkingCursor;
static Display *dpy;
static Window win;
static GC gc;
static GC cleargc;

XImage *chars_bitmap, *chars_mask;
XpmAttributes chars_attrs;

#define CHARWIDTH 8
#define CHARHEIGHT 16
#define ROWS 16
#define COLS 48

/* Defaults */
static int defaultWidth  = CHARWIDTH * COLS;
static int defaultHeight = CHARHEIGHT * ROWS;

static int Width, Height;
static Pixel fg, bg;
static char *progname;

/* Application Resources - no particular widget */
static XtResource application_resources[] = {
	{"name", "Name", XtRString, sizeof(char *),
		(Cardinal)&progname, XtRString, APP_NAME},
	{"width", "Width", XtRInt, sizeof(int),
		(Cardinal)&Width, XtRInt, (caddr_t) &defaultWidth},
	{"height", "Height", XtRInt, sizeof(int),
		(Cardinal)&Height, XtRInt, (caddr_t) &defaultHeight},
	{"foreground", "Foreground", XtRPixel, sizeof(Pixel),
		(Cardinal)&fg, XtRString, (caddr_t) "Black"},
	{"background", "Background", XtRPixel, sizeof(Pixel),
		(Cardinal)&bg, XtRString, (caddr_t) "White"},
};

/*
 *  Command line options table. The command line is parsed for these,
 *  and it sets/overrides the appropriate values in the resource
 *  database
 */
static XrmOptionDescRec optionDescList[] = {
{"-width",	"*width",	XrmoptionSepArg, 	(caddr_t) NULL},
{"-height",	"*height",	XrmoptionSepArg,	(caddr_t) NULL},
{"-fg",		"*foreground",	XrmoptionSepArg,	(caddr_t) NULL},
{"-bg",		"*background",	XrmoptionSepArg,	(caddr_t) NULL},
};


void RepaintCanvas(Widget w, caddr_t data, XEvent *ev);
void RecordMapStatus(Widget w, caddr_t data, XEvent *ev);
void EventHandler(Widget w, caddr_t data, XEvent *ev);

void xsetup(int argc, char **argv)
{
  Widget toplevel;
  Widget w;
  XGCValues gcv;
  XEvent ev;

  /*
   * Create the top level Widget that represents encloses the
   * application.
   */
  toplevel = XtInitialize(argv[0], 
			  APP_CLASS,
			  optionDescList,
			  XtNumber(optionDescList), 
			  &argc,
			  argv);

  XtGetApplicationResources(toplevel, (caddr_t) 0, application_resources,
			    XtNumber(application_resources), (ArgList) NULL, (Cardinal)0);


  if (argc != 1) {
    (void) fprintf(stderr, "Usage: %s [Xt options]\n", argv[0]);
    exit(-1);
  }

  /*
   * Create a simple Core class widget which we'll use for the actual
   * game.  A Core class widget is basically just a window, with a
   * simple Xt "wrapper" around it.
   */
  startargs();
  setarg(XtNwidth, Width);
  setarg(XtNheight, Height);
  w = XtCreateManagedWidget(argv[0], widgetClass, toplevel, 
			    wargs, XtNumber(wargs));

  /*
   * Set the procedures for various X Windows actions - exposure events
   * which arrive when a window needs to be redrawn. The map event lets
   * you know that the window is now on the screen so you can actually
   * do stuff. The ButtonPress event lets you know that a mouse button
   * was pressed.
   */
  XtAddEventHandler(w, (EventMask) ExposureMask, False, 
		    (XtEventHandler) RepaintCanvas, "redraw_data");
  XtAddEventHandler(w, (EventMask) StructureNotifyMask, False, 
		    (XtEventHandler) RecordMapStatus, "map_data");
  /* One day, we'll use the translation manager here */
  XtAddEventHandler(w, (EventMask) KeyPressMask | KeyReleaseMask, False,
		    (XtEventHandler) EventHandler, "input_data");

  /*
   * Create the windows, and set their attributes according to the Widget
   * data.
   */
  XtRealizeWidget(toplevel);
	
  /* We need these for the raw Xlib calls */
  win = XtWindow(w);
  dpy = XtDisplay(w);

  WorkingCursor = XCreateFontCursor(dpy, XC_top_left_arrow);
  XDefineCursor(dpy, win, WorkingCursor);

  /*
   *  make the GC stuff here - one for copy, one for invert. Remember
   *  to change the both appropriately
   */
  gcv.foreground = fg;
  gcv.background = bg;
  gcv.function = GXcopy;
  gc = XCreateGC(dpy, win, GCForeground | GCBackground 
		 | GCFunction, &gcv);
  gcv.foreground = bg;
  cleargc = XCreateGC(dpy, win, GCForeground | GCBackground 
		      | GCFunction, &gcv);

  XpmCreateImageFromData(dpy, chars_xpm, &chars_bitmap, &chars_mask, 
			 &chars_attrs);

  /*
   *  Now process the events.
   */

  /* Wait for first exposure event so we know window has been mapped */
  XWindowEvent(dpy, win, (long) ExposureMask, &ev);
}

static int isMapped = 0;


/*ARGSUSED*/
void RepaintCanvas(Widget w, caddr_t data, XEvent *ev)
{
  int x, y;

  if (!isMapped)
    return;
  /*
   * Redraw the array
   */
  if (ev && ev->xexpose.count == 0) {
    XEvent event;
    /* Skip all excess redraws */
    while (XCheckTypedEvent(dpy, Expose, &event))
      ;
  }

  /* The Nascom screen memory has the top line be line 15 with
     line 0-14 just following it.  Yes, stupid indeed */

  for (x = 0; x < 48; ++x) 
    xputch(x, 0, RAM(0x80a+64*15+x));
		
  for (y = 0; y < 15; ++y)
    for (x = 0; x < 48; ++x)
      xputch(x, y+1, RAM(0x80a+y*64+x));

  XFlush(dpy);
}


void RecordMapStatus(Widget w, caddr_t data, XEvent *ev)
{
	if (ev->type == MapNotify) {
#ifdef WINDOWDEBUG
		(void) printf("window mapped\n");
#endif
		isMapped = TRUE;
	} else if (ev->type == ConfigureNotify) {
#ifdef WINDOWDEBUG
		(void) printf("window resized\n");
#endif
	}
}


static char * kbd_translation[] = {
/* 0 */  "xxxxxxxx",
/* 1 */  "xyTXF5BH",
/* 2 */  "xyYZD6NJ",
/* 3 */  "xyUSE7MK",
/* 4 */  "xyIAW8,L",
/* 5 */  "xxOQ39.;",
/* 6 */  "x[P120/:",
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
    case XK_End:
      {
	FILE *f;
	f = fopen("screendump", "w");
	fwrite((const void *) (ram+0x800), 1, 1024, f);
	fclose(f);
	if (vflag) printf("Screen dumped\n");
      }
      break;
    }

  if (i != -1) {
    if (ev->xany.type == KeyPress)
      keym[i] |= 1 << bit;
    else
      keym[i] &= ~(1 << bit);
  }
}

void xputch(int x, int y, unsigned char v)
{
  /* FIXME: Are Nascom characters really 16 pixels high? */
  XPutImage(dpy, win, gc, chars_bitmap, 0, v*16, x*8, y*16, 8, 16);
  /* XFlush(dpy); An unsuccessful attempt to improve some games */
}

void xhandleevent()
{
  XEvent ev;

  if (XtPending()) {
    XtNextEvent(&ev);
    XtDispatchEvent(&ev);
  }
}
