/*
 * __globals.h
 *
 *  Created on: 28. July 2026
 *      Author: oyvindteig
 */

typedef enum {false,true} bool;

typedef signed int time32_t; // signed int (=signed) or unsigned int (=unsigned) both ok, as long as they are monotoneously increasing
                             // XC/XMOS 100 MHz increment every 10 ns for max 2exp32 = 4294967296,
                             // ie. divide by 100 mill = 42.9.. seconds

typedef enum {PORT_LOW, PORT_HIGH} port_val_e;

#define BITSNUM32 32

#define LOG_START_HEADING_STR "===LOG:" //Must be on a separate line

#ifndef ALWAYS 
    // ALWAYS is always 1, for VS Code "folding"
    // #region or // #region do not work as I want to and extension "Explicit Folding" by zokogun is not good enough, see
    // https://www.teigfam.net/oyvind/home/technology/060-wishes-for-a-folding-editor/#explicit_folding_by_zokogun
    #define ALWAYS 1 
#endif