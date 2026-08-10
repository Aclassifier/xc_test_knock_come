#define TEXT_FOLD     1 // Always 1, for VS Code "folding"
#define NOT_CODE_FOLD 0 // Always 0, for VS Code "folding", not to compile

#if NOT_CODE_FOLD // ========== ABOUT ==========
/*
 * xc_test_knock_come.xc
 *
 *  Created on: 20. mai 2026
 *      Author: oyvindteig
 *      This knock-come pattern implementation is described in-line here.
 *
 * The algorithm / implementations are also described from these links:
 *   [The "knock-come" deadlock free pattern]
 *       https://www.teigfam.net/oyvind/home/technology/009-the-knock-come-deadlock-free-pattern/
 *   [xc_test_knock_come GitHub XC]
 *       https://github.com/Aclassifier/xc_test_knock_come/tree/master
 *   [My Beep-BRRR notes - Decoupling task_slave and master_task_b - Implementation D]
 *       https://www.teigfam.net/oyvind/home/technology/219-my-beep-brrr-notes/#implementation_d
 *   [xc_test_knock_come GitHub Rust]
 *       https://github.com/Aclassifier/rust_test_knock_come/tree/master
 *
 * Some discussion here:
 * task_slave and task_master want to spontaneously send to the other part. With only synchronous non-buffered
 * channels available we either could introduce a one element buffer task in one of the channels, and make sure
 * that sending to this buffer task never overflows it. This is how it would have been solved in occam.
 * For the XC language by XMOS, on the XCORE architecture, a channel may be tagged as "streaming"
 * (see above) - making up for a one-element buffer task. This channel carries the data-less "knock" from
 * the task_slavek, which cannot just send data on a zero-buffered synchronous channel in fear of a deadlock
 * with a master_task_b. Both tasks trigger themselves to initiate send (knock) or actually send (data)
 * with an internal timer, with pseudorandom timeout valuse, inlcuding immediate action.
 * 
 * See the full description of the algorithm in the above referenced blog note.
 */
#endif // NOT_CODE_FOLD ABOUT

#if TEXT_FOLD // ========== include ==========

#include <xs1.h>
#include <platform.h> // slice. For _XTC #include _PLATFORM_INCLUDE_FILE
#include <syscall.h>  // _XTC new for me
#include <timer.h>    // delay_milliseconds(200), XS1_TIMER_HZ etc
#include <stdio.h>    // printf
#include <iso646.h>   // not etc.
#include <xassert.h>
#include <random.h>   // A file "random_conf.h" here with #define RANDOM_ENABLE_HW_SEED 1 needs to be defined
#include "__globals.h"
#include "my_numbers.h"
#include "my_random.h"

#endif // TEXT_FOLD include

#if TEXT_FOLD // ========== VERSION_STR ==========
//
#define VERSION_STR "0.949" // Strictly only for DO_KNOCK_COME and DO_LIB_RANDOM_EXAMPLE
//
#endif // TEXT_FOLD VERSION_STR

#if NOT_CODE_FOLD // ========== COMMITS ==========
/*
10Aug2026 0.949
Lots of changes, see _log.txt. Now the mean is around RND CLK 50.00 ms. Better get_until_next_timeout_ticks
10Aug2026 0.948
* commits.h -> _commit_texts 
* File "commits.h" made for older commit version texts, plus NOT_CODE_FOLD new
* ALWAYS now is TEXT_FOLD etc. 
* get_until_next_timeout_ticks new code, the other was plain wrong. "Folding" better. 
  See _log.txt, stil I think that "mean" should be around 50 ms, not 41 ms.
10AUg2026 0.947 
* Comment
* _log.txt added 36 hours log (started at 16:22:07 Aug  5 2026) with DO_COMPILE_RUN_MAIN == DO_FIND_32BITS_DROP_CNT_MAX 
DO_FIND_32BITS_ONES_CNT and DO_FIND_32BITS_ZEROS_CNT are new
10AUg2026 0.946 
Comments

#include "_commit_texts.h" // Older versions (not compiled, include as such not needed)

21May2026 0.0.900 Initial version
*/

#endif // NOT_CODE_FOLD COMMITS

#if TEXT_FOLD // ========== WHICH main TO RUN ==========
#define DO_KNOCK_COME               0 // VERSION_STR makes sense
#define DO_LIB_RANDOM_EXAMPLE       1 // --''--
#define DO_FIND_BIT31_DROP_CNT_MAX  2
#define DO_FIND_32BITS_DROP_CNT_MAX 3 // Then: see DO_FIND_32BITS_ONES_CNT and DO_FIND_32BITS_ZEROS_CNT

#define DO_COMPILE_RUN_MAIN DO_KNOCK_COME // Observe VS Code colour coding shades non-used code
#endif // TEXT_FOLD WHICH..

#if TEXT_FOLD // ========== #defines ==========
//                                     LEDS COUNT ABOUT THE SAME RATE FOR BOTH
#define SPEED_SLOW_AND_PRINT      0 // Scope possible: use ROLL scope
#define SPEED_SLOW_AND_PRINT_LESS 1 // Scope possible: use ROLL scope
#define SPEED_FAST_AND_SCOPE      2 // Scope 5 us/div two channels and SINGLE shots

#define SPEED_SLOW_AND_PRINT_12 ((PRINT_OR_SCOPE == SPEED_SLOW_AND_PRINT) or (PRINT_OR_SCOPE == SPEED_SLOW_AND_PRINT_LESS))

#define DEBUG_KNOCKCOME                  1 // 0 default, 1 test of state transitions
#define PRINT_OR_SCOPE                   SPEED_SLOW_AND_PRINT
#define TEST_DEADLOCK_NO_STREAMING_CHAN  0 // 0 default to get it to work, 1 deadlocks
#define TEST_STREAMING_CHAN_DOUBLE_KNOCK 0 // 0 default single spontaneous send on streaming ch_knock, 1 double send will cause double COME and crash
#define USE_ORDERED_PRI_SELECT_MASTER    0 // 0 default, 1 to test (*)
#define USE_ORDERED_PRI_SELECT_SLAVE     0 // 0 default, 1 to test (*)
#define PRINT_RANDOM_VALS_MASTER         0 // 0 default, 1 to test

//
// (*) Observe that the Promela code to verify this pattern proves that it does not deadlock with its
// non-deterministic handling of the if :: case 1 :: case 2 fi; select / ALT. No [[ordered]] or "biased" (Rust tokio) 
// See https://www.teigfam.net/oyvind/home/technology/009-the-knock-come-deadlock-free-pattern/#formal_proof_of_deadlock_freedom

#define TIMER_FACTOR_KNOCKCOME_US 1 // microseconds, but not zero

#if ((TEST_DEADLOCK_NO_STREAMING_CHAN==0) or (DEBUG_KNOCKCOME==0)) 
    #define STREAMING streaming // Default. ch_knock the HW layer buffers at leat TWO 32 bits words, see TEST_STREAMING_CHAN_DOUBLE_KNOCK==1
    // See https://www.xcore.com/viewtopic.php?t=9298 "XC and the size of streaming chan buffer" on XCore Exchange
    //   Is there some list anywhere about the size of streaming chan buffer on the different architectures X1, X2, X3?
    //   And is a buffer element always 32 bits wide?
    //   Also, is there some library out there to test this?
    //   I have done some basic coding now and see that for the X2 the buffer is at least two words. 
    //   I have also experimented some with [[ordered]] select in that code. It's the "knock-come" pattern.
    // And https://www.xcore.com/viewtopic.php?t=3737 on XCore Exchange
    //   A normal channel end sets up and closes the connection each time data is transferred.
    //   A streaming channel end sets up the connection, and keeps it open within the scope of the function.
    //   It's a bit like packet switched vs. circuit switched. It means a streaming chan is faster (although both are pretty fast) 
    //   due to not having overhead of setup and close, but it occupies a route through the switch. This is not an issue on a single 
    //   tile where you are only limited by chanends count, but in dual tile systems you typically get only 4 paths from tile to tile,
    //   so streaming channels should be used cautiously across tiles. This code uses single tile, so streaming chan use is fine.
    //   The protocol is different so you cannot mix streaming/no streaming channel end types.
#else 
    #define STREAMING // ch_knock not buffered will cause deadlock!
    #warning Not streaming knock chan!
#endif

#if ((TEST_STREAMING_CHAN_DOUBLE_KNOCK==0) or (DEBUG_KNOCKCOME==0))
    #define DOUBLE_KNOCK 0 // Default
#else 
    #define DOUBLE_KNOCK 1
    #warning Double knock!
#endif

#if ((USE_ORDERED_PRI_SELECT_SLAVE==1) or (DEBUG_KNOCKCOME==0)) 
    #define ORDERED_PRI_SELECT_SLAVE [[ordered]] // Default. Probably not necessary (but not proven), since KnockCome_State_e, and
    //                                              since "unspecified" below probably is implemented as ordered anyhow
    // 
    // XMOS Programming Guide (2015/9/18)
    //   Ordering
    //     Generally there is no priority on the events in a select. If more than one event is
    //     ready when the select executes, the chosen event is unspecified.
    //     Sometimes it is useful to force a priority by using the [[ordered]] attribute which
    //     says that a select is presented with events ordered in priority from highest to lowest.
#else
    #define ORDERED_PRI_SELECT_SLAVE // Seems to run just as good as the alternative
#endif

#if ((USE_ORDERED_PRI_SELECT_MASTER==1) or (DEBUG_KNOCKCOME==0)) 
    #define ORDERED_PRI_SELECT_MASTER [[ordered]] 
#else
    #define ORDERED_PRI_SELECT_MASTER // Seems to run just as good as the alternative
#endif

// Usage:
// SLAVE_SET_KNOCKCOME_STATE  (PresentState,NewState)
// MASTER_SET_KNOCKCOME_STATE (PresentState,NewState)
//
#if (DEBUG_KNOCKCOME == 1)
    #define SLAVE_SET_KNOCKCOME_STATE(PresentState,NewState)  PresentState = Slave_Set_KnockCome_State (PresentState,NewState)
    #define MASTER_SET_KNOCKCOME_STATE(PresentState,NewState) PresentState = Master_Set_KnockCome_State(PresentState,NewState)
#else
    // DEBUG_PRINT_F_PATTERN_KNOCKCOME not tested here, so no print in this case!
    //
    #define SLAVE_SET_KNOCKCOME_STATE(PresentState,NewState)  PresentState = NewState
    #define MASTER_SET_KNOCKCOME_STATE(PresentState,NewState) PresentState = NewState
#endif

// Rename from_10ms_delta_print_10ms if these change:
#define PRINT_TIMEOUT_RESOLUTION_MS 10
#define PRINT_TIMEOUT_TICKS         (PRINT_TIMEOUT_RESOLUTION_MS * XS1_TIMER_KHZ) // Every 10 ms

#if (SPEED_SLOW_AND_PRINT_12)
    #define RANDOM_VAL_MAX_US          (TIMER_FACTOR_KNOCKCOME_US * 100000) // [0..99] ms 
    #define MEAN_LEDS_BLINKING_DIVISOR 10 // (*)
    #define ARR_DELTA_PRINT_DIM        20
#else // SPEED_FAST_AND_SCOPE
    #define RANDOM_VAL_MAX_US          (TIMER_FACTOR_KNOCKCOME_US * 10) // [0..9] us (basically for scope)
    #define MEAN_LEDS_BLINKING_DIVISOR 100000 // (*)
    #define ARR_DELTA_PRINT_DIM        1
#endif
//
#define MAX_SUM_CNT 1000 // Must be an even number if USE_SYMMETRIC:

#if (USE_SYMMETRIC)
    #if (((MAX_SUM_CNT % 2) != 0) or ((RANDOM_VAL_MAX_US % 2) != 0))
        #error Symmetric pseudorandom algorithm values must be even
    #endif
#endif

#define DATA_FIRST_AND_INC 1
//
// (*) Since timimg is random then blinking also is (but divided by some factor it behaves rather average or mean)

#define PRINT_WELCOME_BANNER  print_welcome_banner() // Always print this

#if (SPEED_SLOW_AND_PRINT_12)
    #define PRINT_AND_CLEAR_CNTS(cnts,randoms) print_and_clear_debug_cnts(cnts,randoms) 
#else // SPEED_FAST_AND_SCOPE
    #define PRINT_AND_CLEAR_CNTS(cnts,randoms)
#endif

#if (TEST_DEADLOCK_NO_STREAMING_CHAN==1)
    #define PRINT_DEADLOCK_BANNER print_deadlock_banner()
#else
    #define PRINT_DEADLOCK_BANNER
#endif

#if (USE_ORDERED_PRI_SELECT_MASTER==1)
    #define PRINT_ORDERED_BANNER print_ordered_banner()
#else
    #define PRINT_ORDERED_BANNER
#endif

#define RANDOM_SEED_SLAVE  5678 // Any value, but not 0 since primitive polynom, but only for random_create_generator_from_seed
#define RANDOM_SEED_MASTER 8765 // --''--

#endif // TEXT_FOLD #defines

#if TEXT_FOLD // ========== enums ==========

typedef enum {        // NEEDS
    KC_TYP_NONE_DATA, // Master sends spontaneous data to Slave, not part of knock-come scheme
    KC_TYP_SM_KNOCK,  // Slave to Master (not necessary since anything on this streaning chan makes sense)
    KC_TYP_COME,      // Master sends "come!" to Slave, no piggy.backed data
    KC_TYP_COME_DATA, // Master sends "come!" to Slave, but also includes spontaneous piggy-backed data
    KC_TYP_SM_DATA    // Slave sends data to Master. Knock-Come Sequence finished
} KnockCome_Message_Type_e;

typedef enum {
    // We don't need a KNOCKCOME_KNOCKSEND_PENDING_TO_SEND_KNOCK_A since we can always send immediately,
    // since it's a SIGNAL-type asynch non-blocking sending
    //
                                               //                  NEXT STATE
    KC_STATE_SLAVE_SENT_DATA_NOW_READY = 0x1A, // 26 Also INIT --> KC_STATE_SLAVE_SENT_KNOCK
    KC_STATE_SLAVE_SENT_KNOCK          = 0x1B, // 27           --> KC_STATE_SLAVE_GOT_COME
                                               //                  After this we are dependent on how long the master may be busy: KC_THROUGHPUT_TAG
    KC_STATE_SLAVE_GOT_COME            = 0x1C, // 28           --> KC_STATE_SLAVE_SENT_DATA_NOW_READY
                                               //
    KC_STATE_MASTER_GOT_DATA_NOW_READY = 0x2A, // 42  Also INIT --> KC_STATE_MASTER_GOT_KNOCK
    KC_STATE_MASTER_GOT_KNOCK          = 0x2B, // 43            --> KC_STATE_MASTER_SENT_COME
    KC_STATE_MASTER_SENT_COME          = 0x2C, // 44            --> KC_STATE_MASTER_GOT_DATA_NOW_READY (atomic)
    //
} KnockCome_State_e;

typedef enum {
    task_a,
    task_b
} ab_src_e;

#endif // TEXT_FOLD enums

#if TEXT_FOLD // ========== structs ==========

typedef struct {
    unsigned sent_cnt;
    unsigned rec_cnt;
    unsigned sum_sent_cnt;
    unsigned sum_rec_cnt;
    //
    timer    print_tmr;
    time32_t print_time_ticks;
    unsigned from_10ms_delta_print_10ms;
    unsigned iof_arr; // This:
    unsigned arr_delta_print_10ms [ARR_DELTA_PRINT_DIM];
    // 
    uint64_t sum_ticks_u64;
    unsigned num_ticks;
} cnts_t;

typedef struct {
    KnockCome_Message_Type_e KnockCome_Message_Type; // KC_TYP_SM_KNOCK only
} ch_knock_t;

// Between task_slave and task_master
// task_slave sends important data and task_master some times adds like new menu changes
//
typedef struct {
    ab_src_e source;
    KnockCome_Message_Type_e KnockCome_Message_Type;
    union {
        unsigned data_from_task_a_slave;  // KC_TYP_SM_DATA source is task_slave
        unsigned data_from_task_b_master; // KC_TYP_NONE_DATA or KC_TYP_COME_DATA source is task_master
    } data;
} ch_come_or_sdata_t;

#endif // TEXT_FOLD structs

#if TEXT_FOLD // ========== Knock-Come state change ==========

KnockCome_State_e
Slave_Set_KnockCome_State // The callee TASK starts with KNOCK and later SENDS data
(
    const KnockCome_State_e PresentState,
    const KnockCome_State_e NewState)
{
    KnockCome_State_e NextState;

    #if (DEBUG_KNOCKCOME == 1)
        //  State transition verification
        switch (NewState) {
            case KC_STATE_SLAVE_SENT_KNOCK: {
                xassert (PresentState == KC_STATE_SLAVE_SENT_DATA_NOW_READY);
            } break;

            case KC_STATE_SLAVE_GOT_COME: {
                xassert (PresentState == KC_STATE_SLAVE_SENT_KNOCK); // if (DOUBLE_KNOCK==1) then
                                                                     // PresentState = KC_STATE_SLAVE_GOT_COME, so this is #2!
            } break;

            case KC_STATE_SLAVE_SENT_DATA_NOW_READY: {
               // No code since ..NOW_READY
            } break;

            default: {
                xassert (false);
            } break;
        }
    #endif

    NextState = NewState;

    return NextState;
} // Slave_Set_KnockCome_State


KnockCome_State_e
Master_Set_KnockCome_State // The callee TASK responds with COME and then RECEIVES
(
    const KnockCome_State_e PresentState,
    const KnockCome_State_e NewState)
{
    KnockCome_State_e NextState;

    #if (DEBUG_KNOCKCOME == 1)
        //  State transition verification
        switch (NewState)
        {
            case KC_STATE_MASTER_GOT_KNOCK: {
                xassert (PresentState == KC_STATE_MASTER_GOT_DATA_NOW_READY);
            } break;

            case KC_STATE_MASTER_SENT_COME: {
                xassert (PresentState == KC_STATE_MASTER_GOT_KNOCK);
            } break;

            case KC_STATE_MASTER_GOT_DATA_NOW_READY: {
                // No code since ..NOW_READY
            } break;

            default: {
                xassert (false);
            } break;
        }
    #endif

    NextState = NewState;

    return NextState;
} // Master_Set_KnockCome_State

#endif // TEXT_FOLD Knock-Come..

#if TEXT_FOLD // ========== print and debug functions ==========

void reset_debug_cnts (cnts_t &cnts)
{
    cnts.sent_cnt = 0;
    cnts.rec_cnt  = 0;
    // Don't touch sum_sent_cnt, sum_rec_cnt

    cnts.print_tmr :> cnts.print_time_ticks;  
    cnts.from_10ms_delta_print_10ms = 0;

    cnts.sum_ticks_u64 = 0LL;
    cnts.num_ticks     = 0;
} // reset_debug_cnts

void reset_debug_cnts_arr (cnts_t &cnts)
{
    cnts.iof_arr = 0;
    for (unsigned ix = 0; ix < ARR_DELTA_PRINT_DIM; ix++) {
        cnts.arr_delta_print_10ms [ix] = 0;
    }
} // init_debug_cnts

void init_debug_cnts (cnts_t &cnts)
{
    reset_debug_cnts (cnts);
    reset_debug_cnts_arr (cnts);

    cnts.sum_sent_cnt = 0;
    cnts.sum_rec_cnt  = 0;
} // init_debug_cnts


void print_and_clear_debug_cnts (cnts_t &cnts, randoms_t &randoms)
{
    #if (PRINT_OR_SCOPE == SPEED_SLOW_AND_PRINT)
        unsigned medium_us = 0;
        if (cnts.num_ticks != 0) {
            medium_us = ((unsigned) (cnts.sum_ticks_u64 / (uint64_t) cnts.num_ticks)) / XS1_TIMER_MHZ;
        } else {} // 0

        char max_loop_drop_neg_cnt_str[25]; // SYM means symmetric random properties
        sprintf (max_loop_drop_neg_cnt_str,   "SYM(P %u N %u/%u)\t", randoms.max_loop_pos_cnt, randoms.max_loop_neg_cnt, randoms.max_loop_neg_cnt_ever);
       
        // From v0.941
        // M: SYMCNT(P 1 N 9/9)        RX 997  TX 1000 ACC(RX 997      TX 1000)        TIME 49.09s sum, RND CLK 50.079ms mean
        //       tm means task_master
        printf ("tm: %sRX %u\tTX %u\tACC(RX %u\tTX %u)\tTIME %u.%0*us sum, RND CLK %u.%0*ums mean\n",
            USE_SYMMETRIC ? max_loop_drop_neg_cnt_str : "",
            cnts.rec_cnt,
            cnts.sent_cnt,
            cnts.sum_rec_cnt,
            cnts.sum_sent_cnt,
            get_integer_part   (cnts.from_10ms_delta_print_10ms, scale_hundred), // s
            get_trailing_zeros (scale_hundred), // For this:
            get_fraction_part  (cnts.from_10ms_delta_print_10ms, scale_hundred), // %02 since div 100
            get_integer_part   (medium_us, scale_thousand),  // ms Average sum of random times, how good is the random function generator..
            get_trailing_zeros (scale_thousand),
            get_fraction_part  (medium_us, scale_thousand)); //  ..in delivering average in exactly in the middle?                    
    #elif (PRINT_OR_SCOPE == SPEED_SLOW_AND_PRINT_LESS)
        cnts.arr_delta_print_10ms [cnts.iof_arr] = cnts.from_10ms_delta_print_10ms;
        cnts.iof_arr++;
        if ((cnts.iof_arr % ARR_DELTA_PRINT_DIM) == 0) {
            for (unsigned ix = 0; ix < ARR_DELTA_PRINT_DIM; ix++) {
                printf ("DT %u.%*0us\n", // Not "us" med "s"
                get_integer_part   (cnts.arr_delta_print_10ms [ix], scale_hundred), // absolute time in 10ms
                get_trailing_zeros (scale_hundred),
                get_fraction_part  (cnts.arr_delta_print_10ms [ix], scale_hundred), // %02 since div 100
            }
            printf ("--\n");
            reset_debug_cnts_arr (cnts);
        }
    #endif
   
    randoms.max_loop_neg_cnt = 0;
    randoms.max_loop_pos_cnt = 0;
    reset_debug_cnts (cnts);
} // print_and_clear_debug_cnts


void print_welcome_banner()
{
    printf ("XCC %u.%u KNOCK-COME v%s on date %s %s\nTime random max %u us %scnt events at %u%s\nOrdered select Master %u Slave %u PRINT_OR_SCOPE %u\nDeadlock if LEDS stop to count (Teig)\n",
            XCC_VERSION_MAJOR, XCC_VERSION_MINOR,
            VERSION_STR,
            __DATE__, __TIME__,
            RANDOM_VAL_MAX_US, 
            SPEED_SLOW_AND_PRINT_12 ? "" : "(", // (..) if SPEED_FAST_AND_SCOPE
            MAX_SUM_CNT,
            SPEED_SLOW_AND_PRINT_12 ? "" : ")",
            USE_ORDERED_PRI_SELECT_MASTER,
            USE_ORDERED_PRI_SELECT_SLAVE,
            PRINT_OR_SCOPE);

    printf ("DO_COMPILE_RUN_MAIN %u USE_RANDOM_TYPE %u\n\n", DO_COMPILE_RUN_MAIN, USE_RANDOM_TYPE);
} // print_welcome_banner


void print_deadlock_banner()
{
    printf ("ch_knock is not buffered, system will deadlock.\n"
            "This is last print. Wait one minute to confirm.\n\n");
} // print_deadlock_banner


void print_ordered_banner()
{
    printf ("[[ordered]] not used in select statement(s) seems to have no effect\n"
            "But watch out for stopped log\n");
} // print_ordered_banner

#endif // TEXT_FOLD print..

#if TEXT_FOLD // ========== functions local ==========

// To assure correct scope channel for pin. Start scope in roll mode and auto trig
//
void exercise_p1_out_purple_master (port out p1_out_purple_master) {
    
    for (unsigned ix=0; ix<100; ix++) {
        p1_out_purple_master <: ix;
        delay_milliseconds (10); // 10 ms * 100 = 1 sec, so 50 pulses,
    }
    p1_out_purple_master <: PORT_LOW; // Since 99 yields a '1' PORT_HIGH
} // exercise_p1_out_purple_master


// ===============================================================================================================================
// get_until_next_timeout_ticks to convert from random value as seen as signed to upper and lower half of next_timeout_ticks range
//
time32_t get_until_next_timeout_ticks_input_to_ai (
    const random_unsigned32_t random_number) // From used generators here, all values except 0, 
    // so there is "one less" random_number % RANDOM_VAL_MAX_US = 0 than the others [1..99]. This 
    // same problem also exist on from (2ˆ32)-1 100 upper values (96,97,98,99 are missing) since
    // (2ˆ32)-1 = 4294967295 
    // Examples with RANDOM_VAL_MAX_US 100000 us (100 ms) or 10 us (no overflow problem for any)                                    
{ 
    time32_t next_timeout_ticks;                        

    const random_unsigned32_t random_unsigned32_in_range_us = //                                            1 since never 0 since random_number > 0
        (random_number % (RANDOM_VAL_MAX_US + TIMER_FACTOR_KNOCKCOME_US)) - TIMER_FACTOR_KNOCKCOME_US; // "[1..(99999+1)]-1 = [0 - 99999]"
                                                                                                       // "[1..(9+1)]-1 = [0 - 9]"
    
    #if (USE_SYMMETRIC)
        // "50" is zero point 
        if ((random_number bitand INT_MIN) == 0) { 
            //                                          "100000 + 99999                            / 2 = 99999 (99999.5)"
            //                                          "100000 + 76000                            / 2 = 88000"
            //                                          "100000 + 0                                / 2 = 50000"
            //                                                                    "Positive half" is ">= 50000"
            //                                              "10 + 9                                / 2 = 9 (9.5)"
            //                                              "10 + 7                                / 2 = 8 (8.5)"
            //                                              "10 + 0                                / 2 = 5"
            //                                                                    "Positive half" is ">= 5"
            next_timeout_ticks = (time32_t) ((RANDOM_VAL_MAX_US + random_unsigned32_in_range_us) / 2) * XS1_TIMER_MHZ; // Above half
        } else { //                                                               "Negative half" is " < 50000"
            //                                          "100000 - 24000                            / 2 = 38000"
            //                                          "100000 - 99999                            / 2 =     0 (0.5)"
            //                                                                    "Negative half" is " < 5"
            //                                              "10 - 2                                / 2 = 4"
            //                                              "10 - 9                                / 2 = 0 (0.5)"
            next_timeout_ticks = (time32_t) ((RANDOM_VAL_MAX_US - random_unsigned32_in_range_us) / 2) * XS1_TIMER_MHZ; // Below half
        }
    #else
       next_timeout_ticks = (time32_t) random_unsigned32_in_range_us * XS1_TIMER_MHZ;
    #endif

    xassert ((next_timeout_ticks bitand INT_MIN) == 0); // Delta is positive, ie. half time32_t range

    return next_timeout_ticks;
} // get_until_next_timeout_ticks_input_to_ai


// ===============================================================================================================================
// get_until_next_timeout_ticks to convert from random value as seen as signed to upper and lower half of next_timeout_ticks range
//
time32_t get_until_next_timeout_ticks_ai ( // Based on wrong Python mod div, not C99/XC which allows -999 % 10 = -99
    const random_unsigned32_t random_number) 
{ 
    time32_t next_timeout_ticks;                        
    
    #if (USE_SYMMETRIC)
        // Since the custom PRG delivers pairs of X and (2^32 - X):
        // We check the MSB (sign bit) to separate into two equal statistical halves.
        if ((random_number bitand INT_MIN) == 0) { 
            // 1. Positive half (MSB = 0): Map X uniformly to [0 ... RANDOM_VAL_MAX_US]
            // Using (MAX + 1) ensures 0 is included when the modulo matches.
            const unsigned int range_us = random_number % (RANDOM_VAL_MAX_US + 1);
            
            // Map to the UPPER half of the time range: [(MAX / 2) ... MAX]
            // Multiplying by XS1_TIMER_MHZ BEFORE dividing by 2 preserves full microsecond precision.
            next_timeout_ticks = (time32_t) (((RANDOM_VAL_MAX_US + range_us) * XS1_TIMER_MHZ) / 2);
        } else { 
            // 2. Negative half (MSB = 1): Handles the two's complement partner (2^32 - X).
            // To prevent modulo bias caused by 2^32 % MAX, we reconstruct the original positive 
            // value X by applying two's complement negation back (-random_number).
            const random_unsigned32_t original_positive = (random_unsigned32_t) -random_number;
            const unsigned int range_us = original_positive % (RANDOM_VAL_MAX_US + 1);
            
            // Map to the LOWER half of the time range: [0 ... (MAX / 2)]
            // Counting upwards instead of mirroring ensures perfectly symmetrical distribution weight.
            // Multiplying by XS1_TIMER_MHZ BEFORE dividing by 2 eliminates integer truncation errors.
            next_timeout_ticks = (time32_t) ((range_us * XS1_TIMER_MHZ) / 2);
        }
    #else
        // Non-symmetric mode: Standard uniform mapping across the full range
        const unsigned int range_us = random_number % (RANDOM_VAL_MAX_US + 1);
        next_timeout_ticks = (time32_t) range_us * XS1_TIMER_MHZ;
    #endif

    xassert ((next_timeout_ticks bitand INT_MIN) == 0); // Delta must be positive, ie. within half the time32_t range

    return next_timeout_ticks;
} // get_until_next_timeout_ticks_ai


// ===============================================================================================================================
// get_until_next_timeout_ticks to convert from random value as seen as signed to upper and lower half of next_timeout_ticks range
// 
// Key Observations from the 21k Iteration Log (Summary done by Google AI)
// XCC 1503.1 KNOCK-COME v0.949 on date Aug 10 2026 21:12:42:
// 
// * Symmetry Validation: 
//   The custom PRG effectively balances the distribution, bringing the total `RND CLK` 
//   mean to 50.151 ms (target: 50.00 ms) over a complete 21,000 transaction cycle.
// 
// * Precision Fix Impact: 
//   Shifting the `XS1_TIMER_MHZ` multiplication ahead of the `/ 2` division successfully 
//   preserved the LSB, recovering a lost 1 us per cycle caused by integer truncation.
// 
// * Time Divergence Solved: 
//   The minor variations in the `TIME` column are mathematically verified as a rounding 
//   byproduct of its 10 ms polling interval, while `RND CLK` represents the absolute 
//   64-bit hardware tick truth.

//
time32_t get_until_next_timeout_ticks (
    const random_unsigned32_t random_number) // From used generators here, all values except 0, 
    // so there is "one less" random_number % RANDOM_VAL_MAX_US = 0 than the others [1..99]. This 
    // same problem also exist on from (2ˆ32)-1 100 upper values (96,97,98,99 are missing) since
    // (2ˆ32)-1 = 4294967295 
    // Examples with RANDOM_VAL_MAX_US 100000 us (100 ms) or 10 us (no overflow problem for any)                                    
{ 
    time32_t next_timeout_ticks;                        

    const random_unsigned32_t random_unsigned32_in_range_us = //                                            1 since never 0 since random_number > 0
        (random_number % (RANDOM_VAL_MAX_US + TIMER_FACTOR_KNOCKCOME_US)) - TIMER_FACTOR_KNOCKCOME_US; // "[1..(99999+1)]-1 = [0 - 99999]"
                                                                                                       // "[1..(9+1)]-1 = [0 - 9]"
    
    #if (USE_SYMMETRIC)
        // "50" is zero point 
        if ((random_number bitand INT_MIN) == 0) { 
            //                                          "100000 + 99999                            / 2 = 99999 (99999.5)"
            //                                          "100000 + 76000                            / 2 = 88000"
            //                                          "100000 + 0                                / 2 = 50000"
            //                                                                    "Positive half" is ">= 50000"
            //                                              "10 + 9                                / 2 = 9 (9.5)"
            //                                              "10 + 7                                / 2 = 8 (8.5)"
            //                                              "10 + 0                                / 2 = 5"
            //                                                                    "Positive half" is ">= 5"
            
            // Multiplying by XS1_TIMER_MHZ BEFORE dividing by 2 to prevent any integer truncation error (seen by Google AI)
            next_timeout_ticks    = (time32_t) (((RANDOM_VAL_MAX_US + random_unsigned32_in_range_us) * XS1_TIMER_MHZ) / 2); // Above half
            // was:
            // next_timeout_ticks = (time32_t) ((RANDOM_VAL_MAX_US + random_unsigned32_in_range_us) / 2) * XS1_TIMER_MHZ; // Above half
        } else { //                                                               "Negative half" is " < 50000"
            //                                          "100000 - 24000                            / 2 = 38000"
            //                                          "100000 - 99999                            / 2 =     0 (0.5)"
            //                                                                    "Negative half" is " < 5"
            //                                              "10 - 2                                / 2 = 4"
            //                                              "10 - 9                                / 2 = 0 (0.5)"
            
            // Multiplying by XS1_TIMER_MHZ BEFORE dividing by 2 to prevent any integer truncation error (seen by Google AI)
            next_timeout_ticks    = (time32_t) (((RANDOM_VAL_MAX_US - random_unsigned32_in_range_us) * XS1_TIMER_MHZ) / 2); // Below half
            // was:
            // next_timeout_ticks = (time32_t) ((RANDOM_VAL_MAX_US - random_unsigned32_in_range_us) / 2) * XS1_TIMER_MHZ; // Below half
        }
    #else
       next_timeout_ticks = (time32_t) random_unsigned32_in_range_us * XS1_TIMER_MHZ;
    #endif

    xassert ((next_timeout_ticks bitand INT_MIN) == 0); // Delta is positive, ie. half time32_t range. Overflow or underflow not possible

    return next_timeout_ticks;
} // get_until_next_timeout_ticks


#endif // TEXT_FOLD functions..

#if TEXT_FOLD // ========== task_master ==========
// ===================================================================================================================
// task_master can send its DATA to task_slave any time, 
// but if KNOCK is received it must respond with atomic send COME to task_slave and wait for DATA from task_slave.
//
void task_master (
    chanend           ch_come_or_sdata,     // ch_come_or_sdata_t
    STREAMING chanend ch_knock,             // ch_knock_t
    port out          p1_out_purple_master, // bit0
    port out          p4_leds)              // bit0-3
{
    timer              tmr;
    time32_t           time_ticks;
    ch_come_or_sdata_t data_ch_ab_bidir;
    ch_knock_t         data_ch_ab_knock;
    unsigned           data_from_task_b_master = DATA_FIRST_AND_INC;
    unsigned           data_from_task_a_slave  = 0; // So that the first received is DATA_FIRST_AND_INC more
    cnts_t             cnts;
    randoms_t          randoms;

    init_randoms (randoms, RANDOM_SEED_MASTER); // Contains random_create_generator
    
    init_debug_cnts (cnts); // Also sets print_time_ticks
    cnts.print_tmr :> cnts.print_time_ticks;  
    cnts.from_10ms_delta_print_10ms = 0;
    exercise_p1_out_purple_master (p1_out_purple_master);

    PRINT_WELCOME_BANNER;
    PRINT_ORDERED_BANNER;
    PRINT_DEADLOCK_BANNER;
    PRINT_AND_CLEAR_CNTS (cnts, randoms);

    data_ch_ab_bidir.data.data_from_task_b_master = 0;

    tmr :> time_ticks; // Almost immediately

    while (true) {
        ORDERED_PRI_SELECT_MASTER // [[ordered]] or none
        select {
            case cnts.print_tmr when timerafter (cnts.print_time_ticks) :> void : { // No side effect, ok to have on the etop
                // Every 10 ms RESOLUTION_PRINT_TIMEOUT_MS
                cnts.print_time_ticks += PRINT_TIMEOUT_TICKS;
                cnts.from_10ms_delta_print_10ms += 1; 
            } break;

            case ch_knock :> data_ch_ab_knock : {
                xassert (data_ch_ab_knock.KnockCome_Message_Type == KC_TYP_SM_KNOCK);
                // Build response
                data_ch_ab_bidir.source = task_b;
                // No need to add any data here, so       KC_TYP_COME_DATA is never used:
                data_ch_ab_bidir.KnockCome_Message_Type = KC_TYP_COME;

                // ==============================================================
                // INSIDE THIS CASE CONTINUE WITH THIS ATOMIC KNOCK-COME SEQUENCE
                // ==============================================================

                ch_come_or_sdata <: data_ch_ab_bidir; // SEND and ATOMIC..
                ch_come_or_sdata :> data_ch_ab_bidir; // ..RECEIVE

                unsigned data_from_task_a_slave_now = data_ch_ab_bidir.data.data_from_task_a_slave;
                xassert (data_from_task_a_slave_now == (data_from_task_a_slave + DATA_FIRST_AND_INC));
                data_from_task_a_slave = data_from_task_a_slave_now;
                p4_leds <: data_from_task_a_slave_now / MEAN_LEDS_BLINKING_DIVISOR;
                cnts.rec_cnt++;
                cnts.sum_rec_cnt++;

                // Analyze reponse
                xassert (data_ch_ab_bidir.source == task_a);
                xassert (data_ch_ab_knock.KnockCome_Message_Type == KC_TYP_SM_KNOCK);
            } break;

            case tmr when timerafter (time_ticks) :> void : {       
                const random_unsigned32_t random_number = 
                    random_get_random_number_special (randoms);
                time32_t delta_ticks = get_until_next_timeout_ticks (random_number);
                time_ticks          += delta_ticks;

                cnts.sum_ticks_u64 += (uint64_t) delta_ticks;
                cnts.num_ticks++; // to 1 the first time, etc.
            
                #if (PRINT_RANDOM_VALS_MASTER == 1) // Print (not in slave)
                    #if (USE_SYMMETRIC)
                        printf ("%s%d\n", 
                        ((random_number bitand INT_MIN) == 0) ? " " : "", // space when positive, %d-sign when negative
                        (signed)random_number); 
                    #else
                        printf ("%u\n", random_number);
                    #endif
                #endif

                data_ch_ab_bidir.KnockCome_Message_Type = KC_TYP_NONE_DATA;
                data_ch_ab_bidir.source = task_b;

                data_ch_ab_bidir.data.data_from_task_b_master = data_from_task_b_master;

                ch_come_or_sdata <: data_ch_ab_bidir; // SEND
                p1_out_purple_master <: data_from_task_b_master; // bit0 (any single pulse in here is too short, just toggle on every new transaction)
                data_from_task_b_master = data_from_task_b_master + DATA_FIRST_AND_INC;

                cnts.sent_cnt++;
                cnts.sum_sent_cnt++;

                #if (SPEED_SLOW_AND_PRINT_12)
                    if (cnts.num_ticks == MAX_SUM_CNT) { 
                        PRINT_AND_CLEAR_CNTS (cnts, randoms);
                    } else {}
                #endif
            } break;
        }
    }
} // task_master
#endif // TEXT_FOLD task_master

#if TEXT_FOLD // ========== task_slave ==========
// ===================================================================================================================
// Can only KNOCK to task_master and then wait for COME from task_master and then atomic send its DATA to task_master.
// Must be able to accept DATA from task_master any time.
//
void task_slave (
    chanend           ch_come_or_sdata,       // ch_come_or_sdata_t
    STREAMING chanend ch_knock,       // ch_knock_t
    port out          p1_out_blue_slave) // bit0
{
    timer              tmr;
    time32_t           time_ticks;
    ch_come_or_sdata_t data_ch_ab_bidir;
    KnockCome_State_e  KnockCome_State;
    ch_knock_t         data_ch_ab_knock;
    unsigned           data_from_task_a_slave  = DATA_FIRST_AND_INC;
    unsigned           data_from_task_b_master = 0; // So that the first received is DATA_FIRST_AND_INC more
    randoms_t          randoms;

    init_randoms (randoms, RANDOM_SEED_SLAVE); // Contains random_create_generator

    SLAVE_SET_KNOCKCOME_STATE (KnockCome_State, KC_STATE_SLAVE_SENT_DATA_NOW_READY);
    data_ch_ab_knock.KnockCome_Message_Type = KC_TYP_SM_KNOCK;
    p1_out_blue_slave <: PORT_LOW;
    tmr :> time_ticks;

    while (true) {
        ORDERED_PRI_SELECT_SLAVE // [[ordered]] or none
        select {
            case ch_come_or_sdata :> data_ch_ab_bidir : { // RECEIVE
                bool knockCome_send_data = false;
                bool got_data            = false;

                xassert (data_ch_ab_bidir.source == task_b);

                if (data_ch_ab_bidir.KnockCome_Message_Type == KC_TYP_NONE_DATA) {
                    got_data = true; // No knock-come
                } else if (data_ch_ab_bidir.KnockCome_Message_Type == KC_TYP_COME) {
                    knockCome_send_data = true;
                } else if (data_ch_ab_bidir.KnockCome_Message_Type == KC_TYP_COME_DATA) {
                    knockCome_send_data = true;
                    got_data = true; // Piggy-backed data on Come (Not used on Master side, though)
                } else {
                    xassert (false);
                }

                if (got_data) {
                   const unsigned data_from_task_b_master_now = data_ch_ab_bidir.data.data_from_task_b_master;
                   xassert (data_from_task_b_master_now == data_from_task_b_master + DATA_FIRST_AND_INC);
                   data_from_task_b_master = data_from_task_b_master_now;

                } else if (knockCome_send_data) {
                    SLAVE_SET_KNOCKCOME_STATE (KnockCome_State, KC_STATE_SLAVE_GOT_COME);
                    // Fill data_ch_ab_bidir with data
                    data_ch_ab_bidir.source = task_a;

                    data_ch_ab_bidir.data.data_from_task_a_slave = data_from_task_a_slave;
                    ch_come_or_sdata <: data_ch_ab_bidir; // ATOMIC SEND
                    p1_out_blue_slave <: data_from_task_a_slave; // bit0 (any single pulse in here is too short, just toggle on every new transaction)
                    data_from_task_a_slave = data_from_task_a_slave + DATA_FIRST_AND_INC;

                    SLAVE_SET_KNOCKCOME_STATE (KnockCome_State, KC_STATE_SLAVE_SENT_DATA_NOW_READY);
                } else {}

            } break;

            case tmr when timerafter (time_ticks) :> void: {
                time_ticks += 
                    get_until_next_timeout_ticks (random_get_random_number_special (randoms));

                if (KnockCome_State == KC_STATE_SLAVE_SENT_DATA_NOW_READY) {
                    ch_knock <: data_ch_ab_knock; // streaming chan buffers at least two 32 bits words
                    #if (DOUBLE_KNOCK==1)
                        ch_knock <: data_ch_ab_knock; // Will be buffered as two and cause an extra COME and rash
                    #endif
                    SLAVE_SET_KNOCKCOME_STATE (KnockCome_State, KC_STATE_SLAVE_SENT_KNOCK);
                } else {}
            } break;
        }
    }
} // task_slave 
#endif // TEXT_FOLD task_slave

#if TEXT_FOLD // ========== ports ==========

// See different port syntax forms at https://www.teigfam.net/oyvind/home/technology/141-xc-is-c-plus-x/#port_construct_of_xc
//
// GPIO  PORT LED
// X0D14 P4C0 0
// X0D15 P4C1 1
// X0D20 P4C2 2
// X0D21 P4C3 3

port out p4_leds               = on tile[0]: XS1_PORT_4C; // [X0D14,X0D15,X0D20,X0D21] LEDS   0-3 (bit0-3) also as PORT_LEDS in autogenerated platform.h)
port out p1_out_blue_slave     = on tile[0]: XS1_PORT_1A; // [X0D00]                   J14 pin  2 (bit0)
port out p1_out_purple_master  = on tile[0]: XS1_PORT_1D; // [X0D11]                   J14 pin 15 (bit0)

// From XK-EVK-XU316 xcore.ai Evaluation Kit Manual (2022/7/21 XM014531A) page 10:
// 
// GPIO connector J14 (Tile 0). Note: Some shared with LEDs and BUTtons.
// P1A is 1 bit  port
// P1D is 1 bit  port
// P4C is 4 bits port
// P4C is 4 bits port
// Sum 10 pins
// 
// XMOS naming convention: XS1_PORT_1A on tile[0] X0D00, on tile[1] : X1D00
// 
// Signal Port     Pin   Signal Port      Pin
// VDDIOL            1   X0D00  P1A         2
// X0D14  P4C0(LED0) 3   GND                4
// X0D15  P4C1(LED1) 5   X0D16  P4D0(BUT0)  6
// X0D17  P4D1(BUT1) 7   GND                8
// GND               9   X0D18  P4D2       10
// X0D19  P4D3      11   X0D20  P4C2(LED2) 12
// GND              13   X0D21  P4C3(LED3) 14
// X0D11  P1D       15   GND               16

#endif // TEXT_FOLD ports

#if TEXT_FOLD // ========== DO_KNOCK_COME main ==========
#if (DO_COMPILE_RUN_MAIN == DO_KNOCK_COME)
int main()
{
    STREAMING chan ch_knock ; // ch_knock_t
    chan           ch_come_or_sdata ; // ch_come_or_sdata_t
    par {
        on tile[0]:                   // .core[1]: not combinable so cannot explicitly place on core (*)
            task_slave (              // Must wait knock response to send 
                ch_come_or_sdata,     // ch_come_or_sdata_t
                ch_knock,             // ch_knock_t
                p1_out_blue_slave);   // Pin out for scope
        on tile[0]:                   // .core[0]: This is how they end up, see on crash (*)
            task_master (             // Can send any time
                ch_come_or_sdata,     // ch_come_or_sdata_t
                ch_knock,             // ch_knock_t
                p1_out_purple_master, // Pin out for scope
                p4_leds);             // LEDS for observing activity
        // (*) Same tile[0] so streaming chan does not occupy a route through the HW switch within the scope of the task
    }
    return 0;
} // main
#endif // (DO_COMPILE_RUN_MAIN == DO_KNOCK_COME)
#endif // DO_KNOCK_COME..

#if TEXT_FOLD // ========== DO_LIB_RANDOM_EXAMPLE main ==========
#if (DO_COMPILE_RUN_MAIN == DO_LIB_RANDOM_EXAMPLE)

int main()
{
    lib_random_example();
    return 0;
} // main
#endif // (DO_COMPILE_RUN_MAIN == DO_LIB_RANDOM_EXAMPLE)
#endif // TEXT_FOLD DO_LIB_RANDOM_EXAMPLE..

#if TEXT_FOLD // ========== DO_FIND_BIT31_DROP_CNT_MAX main ==========
#if (DO_COMPILE_RUN_MAIN == DO_FIND_BIT31_DROP_CNT_MAX)
  
int main()
{
    find_max_consecutive_bit31_xorshift32 (1, p1_out_blue_slave);
    return 0;
} // main
#endif // (DO_COMPILE_RUN_MAIN == DO_FIND_BIT31_DROP_CNT_MAX)
#endif // TEXT_FOLD DO_FIND_BIT31_DROP_CNT_MAX..

#if TEXT_FOLD // ========== DO_FIND_32BITS_DROP_CNT_MAX main ==========
#if (DO_COMPILE_RUN_MAIN == DO_FIND_32BITS_DROP_CNT_MAX)

int main()
{
    find_max_consecutive_allbits_xorshift32 (1, p1_out_blue_slave);
    return 0;
} // main
#endif // (DO_COMPILE_RUN_MAIN == DO_FIND_32BITS_DROP_CNT_MAX)
#endif // TEXT_FOLD DO_FIND_32BITS_DROP_CNT_MAX..