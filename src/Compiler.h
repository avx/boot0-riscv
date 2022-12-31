/* Compiler.h
2021-01-05 : Igor Pavlov : Public domain */

#ifndef __7Z_COMPILER_H
#define __7Z_COMPILER_H

  #ifdef __clang__
    #pragma clang diagnostic ignored "-Wunused-private-field"
  #endif

#define UNUSED_VAR(x) (void)x;
/* #define UNUSED_VAR(x) x=x; */

#endif
