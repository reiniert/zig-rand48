#include <assert.h>
#include <stdlib.h>
#include <stdio.h>

/*
static void print_dres(double d, const unsigned short xsubi[3])
{
    printf("d = %f, xsubi = {%u, %u, %u}\n", d, xsubi[0], xsubi[1], xsubi[2]);
}

static void print_ires(long i, const unsigned short xsubi[3])
{
    printf("i = %ld, xsubi = {%u, %u, %u}\n", i, xsubi[0], xsubi[1], xsubi[2]);
}
*/

int main(void)
{
    {
        unsigned short xsubi[3] = {37174, 64810, 11603};
        double d = erand48(xsubi);
        assert(d >= 0.896);
        assert(d <= 0.897);
        assert(xsubi[0] == 22537);
        assert(xsubi[1] == 47966);
        assert(xsubi[2] == 58735);
        d = erand48(xsubi);
        assert(d >= 0.337);
        assert(d <= 0.338);
        assert(xsubi[0] == 37344);
        assert(xsubi[1] == 32911);
        assert(xsubi[2] == 22119);
        d = erand48(xsubi);
        assert(d >= 0.647);
        assert(d <= 0.648);
        assert(xsubi[0] == 23659);
        assert(xsubi[1] == 29872);
        assert(xsubi[2] == 42445);
        d = erand48(xsubi);
        assert(d >= 0.500);
        assert(d <= 0.501);
        assert(xsubi[0] == 31642);
        assert(xsubi[1] == 7875);
        assert(xsubi[2] == 32802);
        d = erand48(xsubi);
        assert(d >= 0.506);
        assert(d <= 0.507);
        assert(xsubi[0] == 64669);
        assert(xsubi[1] == 14399);
        assert(xsubi[2] == 33170);
    }

    {
        unsigned short xsubi[3] = {25175, 11052, 45015};
        assert(jrand48(xsubi) == 1699503220);
        assert(xsubi[0] == 2326);
        assert(xsubi[1] == 23668);
        assert(xsubi[2] == 25932);
        assert(jrand48(xsubi) == -992276007);
        assert(xsubi[0] == 41577);
        assert(xsubi[1] == 4569);
        assert(xsubi[2] == 50395);
        assert(jrand48(xsubi) == -19535776);
        assert(xsubi[0] == 31936);
        assert(xsubi[1] == 59488);
        assert(xsubi[2] == 65237);
        assert(jrand48(xsubi) == 79438377);
        assert(xsubi[0] == 40395);
        assert(xsubi[1] == 8745);
        assert(xsubi[2] == 1212);
        assert(jrand48(xsubi) == -1258917728);
        assert(xsubi[0] == 37242);
        assert(xsubi[1] == 28832);
        assert(xsubi[2] == 46326);
    }

    {
        unsigned short xsubi[3] = {546, 33817, 23389};
        assert(nrand48(xsubi) == 914920692);
        assert(xsubi[0] == 29829);
        assert(xsubi[1] == 10728);
        assert(xsubi[2] == 27921);
        assert(nrand48(xsubi) == 754104482);
        assert(xsubi[0] == 6828);
        assert(xsubi[1] == 28997);
        assert(xsubi[2] == 23013);
        assert(nrand48(xsubi) == 609453945);
        assert(xsubi[0] == 58183);
        assert(xsubi[1] == 3826);
        assert(xsubi[2] == 18599);
        assert(nrand48(xsubi) == 1878644360);
        assert(xsubi[0] == 36678);
        assert(xsubi[1] == 44304);
        assert(xsubi[2] == 57331);
        assert(nrand48(xsubi) == 2114923686);
        assert(xsubi[0] == 58585);
        assert(xsubi[1] == 22861);
        assert(xsubi[2] == 64542);
    }
    return 0;
}
