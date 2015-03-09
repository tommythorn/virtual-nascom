#include "ihex.h"
#include <stdio.h>
#include <stdbool.h>
#include <ctype.h>

// return true if failed
static bool hexdigitValue(int ch, int *v)
{
    if ('0' <= ch && ch <= '9')
        *v = ch - '0';
    else if ('A' <= ch && ch <= 'F')
        *v = ch - 'A' + 10;
    else if ('a' <= ch && ch <= 'f')
        *v = ch - 'a' + 10;
    else
        return true;

    return false;
}

static bool read_hex(FILE *f, int n, int *v)
{
    *v = 0;

    while (n-- > 0) {
        int dv, ch = fgetc(f);

        if (hexdigitValue(ch, &dv)) {
            fprintf(stderr, "Expected hexdigit at pos %ld, got %d",
                    ftell(f) - 1, ch);
            return true;
        }

        *v = 16* *v + dv;
    }

    return false;
}

static bool read_ihex_line(FILE *f, char *memory, unsigned *start_addr)
{
    /*
     Expect lines like this:
     :10010000214601360121470136007EFE09D2190140
     That is (without spaces)
     CC AAAAA TT DD DD DD .. DD KK
     CC is the byte count (# of DD pairs)
     AA is the 16-bit address (offset) from base
     TT is the type
     KK checksum (twos compliment of sum of all bytes)
    */

    int ch, count, addr, type, v, chk;

    do {
        ch = fgetc(f);
        if (ch < 0)
            return false;
    } while (ch == '\n' || ch == '\r');

    if (ch != ':') {
        fprintf(stderr, "Expected ':' at pos %ld, got %d",
                ftell(f) - 1, ch);
        return true;
    }

    if (read_hex(f, 2, &count) ||
        read_hex(f, 4, &addr) ||
        read_hex(f, 2, &type))
        return true;

    if (type == 5)
        *start_addr = addr;

    while (count-- > 0) {
        if (read_hex(f, 2, &v))
            return true;

        if (2048 <= addr && addr < 65536)
            memory[addr++] = v;
    }

    if (read_hex(f, 2, &chk))
        return true;

    return false;
}

void load_ihex(const char *file, char *memory)
{
    FILE *f = fopen(file, "r");
    unsigned start_addr = -1;

    while (!feof(f))
        if (read_ihex_line(f, memory, &start_addr)) {
            printf("Couldn't load %s as ihex\n", file);
            break;
        }
}
