/* Since Windows does not provide the POSIX rand48 functions, declare them here
 * so the C test code can compile and run correctly on Windows (when linking them
 * with the Zig implementation of rand48). */

#ifndef RAND48_H
#define RAND48_H

double drand48(void);
double erand48(unsigned short xsubi[3]);
long jrand48(unsigned short xsubi[3]);
void lcong48(unsigned short param[7]);
long lrand48(void);
long mrand48(void);
long nrand48(unsigned short xsubi[3]);
unsigned short *seed48(unsigned short seed16v[3]);
void srand48(long seedval);

#endif /* RAND48_H */