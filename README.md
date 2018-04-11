Virtual Nascom, Version 2.0, 2018-04-11
========================================

This is a version 2.0 of Virtual Nascom, yet another Nascom 2
emulator.  There's emulation support for all(?) of the standard
hardware and it runs nearly all of the software on the
nascomhomepage.com (see KNOWN ISSUES below).

Version 1.9 switches from a (partially broken) X Window specific
implementation to portable and more more robust SDL implementation. It
also gained basic serial port support in the process.

Version 1.10 adds support for "natural" keyboard, that is, US keyboard
events are translated into the equivalent Nascom keycombination.

* Homepage: http://www.nascomhomepage.com

* Git repository: http://github.com/tommythorn/virtual-nascom.git


INSTALLATION
------------

Virtual Nascom should compile on all platform with SDL support, but
has only been tested on macOS (10.12.4 and older) and various Linux
versions.

To compile you may have to adapt the Makefile with the libraries you
need and their path, but generally it should be enough to simply run

    $ make

USAGE
-----

    Usage: ./virtual-nascom {flags} [NAS files]
               -i <file>       take serial port input from file (when tape led is on)
               -m <file>       use <file> as monitor (default is nassys3.nal)
               -v              verbose

Virtual Nascom expects to find `nassys.nal` (unless you changed the
monitor using the `-m` option) and `basic.nal` upon startup.  You can
add files to be loaded by providing them as arguments at the end of
the line.

For example to run *Pac Man*, run

    $ ./virtual-nnascom programs/e1000/pacman.nas

and type `E1000` in the Nascom 2 window. Control with arrow keys.

The emulator conveniently dumps the memory state in `memorydump.nas`
upon exit so one might resume execution later on.

The following keys are supported:

* END - leaves a screendump in `screendump`
* F4 - exits the emulator
* F5 - toggles between stupidly fast and "normal" speed
* F6 - force serial input on
* F9 - resets the emulated Nascom
* F10 - toggles between "raw" and "natural" keyboard emulation

All serial output is appended to `serialout.txt` which may be fed back
in on a subsequent launch via the `-i` option.

CREDITS
-------

A very crucial part of Virtual Nascom is the excellent Z-80 emulator
from Yaze, Copyright (C) 1995,1998  Frank D. Cringle.

Thanks to Dene Carter for encouragement


SOMETHING DIFFERENT
-------------------

This repo includes a quick hack at a repackaging the Nascom font
as an BDF file, for use in X11.  Example usage:

    $ cd BDF; mkfontdir; xset +fp $PWD; xset fp rehash
    $ xterm -bg '#000' -fg '#0F0' -fn '-tommy-nascom-medium-r-normal--16-160-72-72-c-80-iso8859-1'

and enjoy the nostalgia :)

Known issues: should only be ~ 14 pixels tall, only the ASCII subset
works, ~ and # looks funny, but that's Nascom.


TODO
----

* Support pixel doubling

* Reconsider the name

* Clean up code and document; improve UI

* Allow for switching input and output file while running

* Precise timings (a rough, but machine independent job should be
  easily done)

* Emulate sound (requires precise timings)


KNOWN ISSUES
------------

* *Galaxy Attack* doesn't work on Virtual Nascom.  As it does work on
  VNASCOM it must be an emulation bug.
