/*
 * xc_test_knock_come.xc
 *
 * 
 *  Created on: 20. mai 2026
 *      Author: oyvindteig
 *      This knock-come pattern implementation is described in-line here.
 *
 * The algorithm / implementations are also described from these links:
 *   [The "knock-come" deadlock free pattern]
 *       https://www.teigfam.net/oyvind/home/technology/009-the-knock-come-deadlock-free-pattern/
 *   [xc_test_knock_come]
 *       https://github.com/Aclassifier/xc_test_knock_come/tree/master
 *   [My Beep-BRRR notes - Decoupling slave_task_a and master_task_b - Implementation D]
 *       https://www.teigfam.net/oyvind/home/technology/219-my-beep-brrr-notes/#implementation_d
 *
 * Some discussion here:
 * slave_task_a and master_task_b want to spontaneously send to the other part. With only synchronous non-buffered
 * channels available we either could introduce a one element buffer task in one of the channels, and make sure
 * that sending to this buffer task never overflows it. This is how it would have been solved in occam.
 * For the XC language by XMOS, on the XCORE architecture, a channel may be tagged as "streaming"
 * (see above) - making up for a one-element buffer task. This channel carries the data-less "knock" from
 * the slave_task_ak, which cannot just send data on a zero-buffered synchronous channel in fear of a deadlock
 * with a master_task_b. Both tasks trigger themselves to initiate send (knock) or actually send (data)
 * with an internal timer, with pseudo-random timeout valuse, inlcuding immediate action.
 * 
 * See the full description of the algorithm in the above referenced blog note.
 */

 #define _XTC           (XCC_VERSION_MAJOR >= 1503)
 #define _XTIMECOMPOSER (XCC_VERSION_MAJOR <  1500) // 1404 is last

#define INCLUDES
#ifdef INCLUDES
    #include <xs1.h>
    #include <platform.h> // slice
                          // For _XTC #include _PLATFORM_INCLUDE_FILE (-> xc_test_knock_come/build/autogen_headers/tgt_xc_test_knock_come/platform.h)
    #include <syscall.h>  // _XTC new for me
    #include <timer.h>    // delay_milliseconds(200), XS1_TIMER_HZ etc
    #include <stdint.h>   // uint8_t
    #include <stdio.h>    // printf
    #include <string.h>   // memcpy
    #include <xccompat.h> // REFERENCE_PARAM(my_app_ports_t, my_app_ports) -> my_app_ports_t &my_app_ports
    #include <iso646.h>   // not etc.
    #include <xassert.h>
    #include <random.h>   // A file "random_conf.h" here with #define RANDOM_ENABLE_HW_SEED 1 needs to be defined
#endif

#define KNOCK_COME_VERSION_STR "0.0.916" // x.y.zzz
#define KNOCK_COME_TIME __TIME__
#define KNOCK_COME_DATE __DATE__

// =============================================================================================
// VERSIONS / COMMITS
// =============================================================================================
// 09Jun2026 0.0.916 Possible to use ports for scope instead of logs.
//                   <syscall.h> introduced since XTC_ExampleXCommonCMake came with it
//                   PRINT_KNOCKCOME is new
//                   TIMER_FACTOR_KNOCKCOME_US is new, to enable fast scope'ing
// 27May2026 0.0.915 First commit with XTC compiled ok, CMake and CMakeLists.txt
// 26May2026 0.0.914 Welcome printing different sequence
// 26May2026 0.0.913 No code change, another XCore Exchange entry referenced. Some empty lines
// 26May2026 0.0.913 No change of code, more comments
// 26May2026 0.0.913 This file has been cleaned up with hopefully better comments. 
//                   TEST_NOT_ORDERED_PRI_SELECT is new
// 25May2026 0.0.912 was committed by GitHub desktop on macOS Tahoe and then
//                   https://github.com/Aclassifier/xc_test_knock_come/tree/master created
//                   Then ChronoSync'ed back to the xTIMEcomposer 2010 mac Mini. No code change
// 24May2026 0.0.912 URL to blog note updated
//                   Description uodated and some renaming
//                   task_a_master -> task_b_master
// 24May2026 0.0.911 print_and_clear_debug_cnts added last > = <
//                   print_welcome_banner is new
//                   Conditional printing done in macros
// 23May2026 0.0.910 ch_ba_knock -> ch_ab_knock
//                   TEST_DEADLOCK_NO_STREAMING_CHAN is new
// 21May2026 0.0.900 Initial version. Sent to Antonio
// =============================================================================================

typedef enum {false,true} bool;

typedef signed int time32_t; // signed int (=signed) or unsigned int (=unsigned) both ok, as long as they are monotoneously increasing
                             // XC/XMOS 100 MHz increment every 10 ns for max 2exp32 = 4294967296,
                             // ie. divide by 100 mill = 42.9.. seconds

typedef enum {PORT_LOW, PORT_HIGH} port_val_e;

#define DEBUG_KNOCKCOME                  1 // 0 default, 1 test of state transitions
#define PRINT_KNOCKCOME                  0 // 0 default no printing and nice for FAST SCOPE, 1 log produced and ok for ROLL SCOPE
#define TEST_DEADLOCK_NO_STREAMING_CHAN  0 // 0 default to get it to work, 1 deadlocks
#define TEST_STREAMING_CHAN_DOUBLE_KNOCK 0 // 0 default single spontaneous send on streaming ch_ab_knock, 1 double send will cause double COME and crash
#define TEST_NOT_ORDERED_PRI_SELECT      0 // 0 default, 1 to test

#define TIMER_FACTOR_KNOCKCOME_US 1 // microseconds, but not zero

#if ((TEST_DEADLOCK_NO_STREAMING_CHAN==0) or (DEBUG_KNOCKCOME==0)) 
    #define STREAMING streaming // Default. ch_ab_knock the HW layer buffers at leat TWO 32 bits words, see TEST_STREAMING_CHAN_DOUBLE_KNOCK==1
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
    #define STREAMING // ch_ab_knock not buffered will cause deadlock!
    #warning Not streaming knock chan!
#endif

#if ((TEST_STREAMING_CHAN_DOUBLE_KNOCK==0) or (DEBUG_KNOCKCOME==0))
    #define DOUBLE_KNOCK 0 // Default
#else 
    #define DOUBLE_KNOCK 1
    #warning Double knock!
#endif

#if ((TEST_NOT_ORDERED_PRI_SELECT==0) or (DEBUG_KNOCKCOME==0)) 
    #define ORDERED_PRI_SELECT [[ordered]] // Default. Probably not necessary (but not proven), since KnockCome_State_e, and
    //                                        since "unspecified" below probably is implemented as ordered anyhow
    // 
    // XMOS Programming Guide (2015/9/18)
    //   Ordering
    //     Generally there is no priority on the events in a select. If more than one event is
    //     ready when the select executes, the chosen event is unspecified.
    //     Sometimes it is useful to force a priority by using the [[ordered]] attribute which
    //     says that a select is presented with events ordered in priority from highest to lowest.
#else
    #define ORDERED_PRI_SELECT // Seems to run just as good as the alternative
    #warning Not [[ordered]] pri selects
#endif


typedef enum {        // NEEDS
    KC_TYP_NONE_DATA, // Master sends spontaneous data to Slave, not part of knock-come scheme
    KC_TYP_SM_KNOCK,  // Slave to Master (not necessary since anything on this streaning chan makes sense)
    KC_TYP_COME,      // Master sends "come!" to Slave, no piggy.backed data
    KC_TYP_COME_DATA, // Master sends "come!" to Slave, but also includes spontaneous piggy-backed data
    KC_TYP_SM_DATA    // Slave sends data to Master. Knock-Come Sequence finished
} KnockCome_Message_Type_e;


typedef struct {
    KnockCome_Message_Type_e KnockCome_Message_Type; // KC_TYP_SM_KNOCK only
} ch_ab_knock_t;


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
    KC_STATE_MASTER_SENT_COME          = 0x2C, // 44            --> KC_STATE_MASTER_GOT_DATA_NOW_READY
    //
} KnockCome_State_e;


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


typedef enum {
    task_a,
    task_b
} ab_src_e;


// Between task_a_slave and task_b_master
// task_a_slave sends important data and task_b_master some times adds like new menu changes
//
typedef struct {
    ab_src_e source;
    KnockCome_Message_Type_e KnockCome_Message_Type;
    union {
        unsigned data_from_task_a_slave;  // KC_TYP_SM_DATA source is task_a_slave
        unsigned data_from_task_b_master; // KC_TYP_NONE_DATA or KC_TYP_COME_DATA source is task_b_master
    } data;
} ch_ab_bidir_t;




#if (PRINT_KNOCKCOME==1)
    #define RANDOM_VAL_MAX_US          (TIMER_FACTOR_KNOCKCOME_US * 100000) // 100 ms nbsically for printing
    #define MEAN_LEDS_BLINKING_DIVISOR 10 // (*)
#else
    #define RANDOM_VAL_MAX_US          (TIMER_FACTOR_KNOCKCOME_US * 10) // 10 us for SCOPE
    #define MEAN_LEDS_BLINKING_DIVISOR 100000 // (*)
#endif
//
// (*) Since timimg is random then blinking also is (but divided by some factor it behaves rather average or mean)

#define MAX_SUM_CNT 1000

#define RANDOM_SEED_SLAVE  5678
#define RANDOM_SEED_MASTER 8765

#define DATA_FIRST_AND_INC 1

typedef struct {
    unsigned sent_cnt;
    unsigned rec_cnt;
    unsigned rec_sent_cnt;
    unsigned rec_gt_sent_cnt;
    unsigned rec_eq_sent_cnt;
    unsigned rec_lt_sent_cnt;
    unsigned sum_sent_cnt;
    unsigned sum_rec_cnt;
} cnts_t;


void init_debug_cnts (cnts_t &cnts)
{
    cnts.sent_cnt        = 0;
    cnts.rec_cnt         = 0;
    cnts.rec_sent_cnt    = 0;
    cnts.rec_gt_sent_cnt = 0;
    cnts.rec_eq_sent_cnt = 0;
    cnts.rec_lt_sent_cnt = 0;
    cnts.sum_sent_cnt    = 0;
    cnts.sum_rec_cnt     = 0;
} // init_debug_cnts


void update_fairness_cnts (cnts_t &cnts)
{
    if (cnts.rec_cnt > cnts.sent_cnt) {
        cnts.rec_gt_sent_cnt++;
    } else if (cnts.rec_cnt < cnts.sent_cnt) {
        cnts.rec_lt_sent_cnt++;
    } else {
        cnts.rec_eq_sent_cnt++;
    }
} // update_fairness_cnts

// #if (PRINT_KNOCKCOME==1)
void print_and_clear_debug_cnts (cnts_t &cnts)
{
   printf ("REC %u\t%s\tSENT %u\t(>%u =%u <%u)\tSUM (REC %u %s SENT %u)\n",
           cnts.rec_cnt,
           cnts.rec_cnt ? ">" : cnts.sent_cnt ? "<" : "=",
           cnts.sent_cnt,
           cnts.rec_gt_sent_cnt, cnts.rec_eq_sent_cnt, cnts.rec_lt_sent_cnt,
           cnts.sum_rec_cnt,
          (cnts.sum_rec_cnt > cnts.sum_sent_cnt) ? ">" : cnts.sum_rec_cnt < cnts.sum_sent_cnt ? "<" : "=",
           cnts.sum_sent_cnt);

   cnts.sent_cnt        = 0;
   cnts.rec_cnt         = 0;
   cnts.rec_sent_cnt    = 0;
   cnts.rec_gt_sent_cnt = 0;
   cnts.rec_eq_sent_cnt = 0;
   cnts.rec_lt_sent_cnt = 0;
   // cnts.sum_sent_cnt, cnts.rec_cnt don't touch
} // print_and_clear_debug_cnts


// #if (PRINT_KNOCKCOME==0 or 1)
void print_welcome_banner()
{
    printf ("XCC %u.%u KNOCK-COME %s on date %s %s\nTime random max %u us, cnt events at %u (Teig)\n\n",
            XCC_VERSION_MAJOR, XCC_VERSION_MINOR,
            KNOCK_COME_VERSION_STR,
            KNOCK_COME_DATE, KNOCK_COME_TIME,
            RANDOM_VAL_MAX_US, MAX_SUM_CNT);
} // print_welcome_banner


// #if (TEST_DEADLOCK_NO_STREAMING_CHAN==1)
void print_deadlock_banner()
{
    printf ("ch_ab_knock is not buffered, system will deadlock.\n"
            "This is last print. Wait one minute to confirm.\n\n");
} // print_deadlock_banner


// #if (TEST_NOT_ORDERED_PRI_SELECT==1)
void print_ordered_banner()
{
    printf ("[[ordered]] not used in select statements seems to have no effect\n"
            "But watch out for stopped log\n");
} // print_ordered_banner

#define PRINT_WELCOME_BANNER  print_welcome_banner() // Always print this

#if (PRINT_KNOCKCOME==1)
    #define PRINT_AND_CLEAR_CNTS(cnts) print_and_clear_debug_cnts(cnts) 
#else
    #define PRINT_AND_CLEAR_CNTS(cnts)
#endif

#if (TEST_DEADLOCK_NO_STREAMING_CHAN==1)
    #define PRINT_DEADLOCK_BANNER print_deadlock_banner()
#else
    #define PRINT_DEADLOCK_BANNER
#endif

#if (TEST_NOT_ORDERED_PRI_SELECT==1)
    #define PRINT_ORDERED_BANNER print_ordered_banner()
#else
    #define PRINT_ORDERED_BANNER
#endif


// =========================================================================================================================
// Can only KNOCK to task_b_master and then wait for COME from task_b_master and then atomic send its DATA to task_b_master.
// Must be able to accept DATA from task_b_master any time.
//
void task_a_slave (
    chanend           ch_ab_bidir,       // ch_ab_bidir_t
    STREAMING chanend ch_ab_knock,       // ch_ab_knock_t
    port out          p1_out_blue_slave) // bit0
{
    timer             tmr;
    time32_t          time_ticks;
    ch_ab_bidir_t     data_ch_ab_bidir;
    KnockCome_State_e KnockCome_State;
    ch_ab_knock_t     data_ch_ab_knock;
    unsigned          data_from_task_a_slave  = DATA_FIRST_AND_INC;
    unsigned          data_from_task_b_master = 0; // So that the first received is DATA_FIRST_AND_INC more
    unsigned          random_seed             = random_create_generator_from_seed(RANDOM_SEED_SLAVE); // xmos
    unsigned          random_delay_us         = random_seed % RANDOM_VAL_MAX_US;

    SLAVE_SET_KNOCKCOME_STATE (KnockCome_State, KC_STATE_SLAVE_SENT_DATA_NOW_READY);
    data_ch_ab_knock.KnockCome_Message_Type = KC_TYP_SM_KNOCK;
    p1_out_blue_slave <: PORT_LOW;
    tmr :> time_ticks;

    while (true) {
        ORDERED_PRI_SELECT // [[ordered]] or none
        select {
            case ch_ab_bidir :> data_ch_ab_bidir : { // RECEIVE
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
                    ch_ab_bidir <: data_ch_ab_bidir; // ATOMIC SEND
                    p1_out_blue_slave <: data_from_task_a_slave; // bit0 (any single pulse in here is too short, just toggle on every new transaction)
                    data_from_task_a_slave = data_from_task_a_slave + DATA_FIRST_AND_INC;

                    SLAVE_SET_KNOCKCOME_STATE (KnockCome_State, KC_STATE_SLAVE_SENT_DATA_NOW_READY);
                } else {}

            } break;

            case tmr when timerafter (time_ticks) :> void: {
                ch_ab_bidir_t data_ch_ab_bidir; // Here: limits scope of struct with union

                random_delay_us = (random_get_random_number (random_seed)) % RANDOM_VAL_MAX_US;
                time_ticks     += (random_delay_us * XS1_TIMER_MHZ);

                if (KnockCome_State == KC_STATE_SLAVE_SENT_DATA_NOW_READY) {
                    ch_ab_knock <: data_ch_ab_knock; // streaming chan buffers at least two 32 bits words
                    #if (DOUBLE_KNOCK==1)
                        ch_ab_knock <: data_ch_ab_knock; // Will be buffered as two and cause an extra COME and rash
                    #endif
                    SLAVE_SET_KNOCKCOME_STATE (KnockCome_State, KC_STATE_SLAVE_SENT_KNOCK);
                } else {}
            } break;
        }
    }
} // task_a_slave 


// To assure correct scope channel for pin. Start scope in roll mode and auto trig
//
void exercise_p1_out_purple_master (port out p1_out_purple_master) {
    
    for (unsigned ix=0; ix<100; ix++) {
        p1_out_purple_master <: ix;
        delay_milliseconds (10); // 10 ms * 100 = 1 sec, so 50 pulses,
    }
    p1_out_purple_master <: PORT_LOW; // Since 99 yields a '1' PORT_HIGH
} // exercise_p1_out_purple_master


// ===================================================================================================================
// task_b_master can send its DATA to task_a_slave any time, 
// but if KNOCK is received it must respond with atomic send COME to task_a_slave and wait for DATA from task_a_slave.
//
void task_b_master (
    chanend           ch_ab_bidir,          // ch_ab_bidir_t
    STREAMING chanend ch_ab_knock,          // ch_ab_knock_t
    port out          p1_out_purple_master, // bit0
    port out          p4_leds)              // bit0-3
{
    timer         tmr;
    time32_t      time_ticks;
    ch_ab_bidir_t data_ch_ab_bidir;
    ch_ab_knock_t data_ch_ab_knock;
    unsigned      data_from_task_b_master = DATA_FIRST_AND_INC;
    unsigned      data_from_task_a_slave  = 0; // So that the first received is DATA_FIRST_AND_INC more
    unsigned      random_seed             = random_create_generator_from_seed(RANDOM_SEED_MASTER); // xmos
    unsigned      random_delay_us         = random_seed % RANDOM_VAL_MAX_US;
    cnts_t        cnts;

    init_debug_cnts (cnts);
    exercise_p1_out_purple_master (p1_out_purple_master);

    PRINT_WELCOME_BANNER;
    PRINT_ORDERED_BANNER;
    PRINT_DEADLOCK_BANNER;
    PRINT_AND_CLEAR_CNTS (cnts);

    data_ch_ab_bidir.data.data_from_task_b_master = 0;

    tmr :> time_ticks; // Immediately

    while (true) {
        ORDERED_PRI_SELECT // [[ordered]] or none
        select {
            case ch_ab_knock :> data_ch_ab_knock : {
                xassert (data_ch_ab_knock.KnockCome_Message_Type == KC_TYP_SM_KNOCK);
                // Build response
                data_ch_ab_bidir.source = task_b;
                // No need to add any data here, so       KC_TYP_COME_DATA is never used:
                data_ch_ab_bidir.KnockCome_Message_Type = KC_TYP_COME;

                // ==============================================================
                // INSIDE THIS CASE CONTINUE WITH THIS ATOMIC KNOCK-COME SEQUENCE
                // ==============================================================

                ch_ab_bidir <: data_ch_ab_bidir; // SEND and ATOMIC..
                ch_ab_bidir :> data_ch_ab_bidir; // ..RECEIVE

                unsigned data_from_task_a_slave_now = data_ch_ab_bidir.data.data_from_task_a_slave;
                xassert (data_from_task_a_slave_now == (data_from_task_a_slave + DATA_FIRST_AND_INC));
                data_from_task_a_slave = data_from_task_a_slave_now;
                p4_leds <: data_from_task_a_slave_now / MEAN_LEDS_BLINKING_DIVISOR;
                cnts.rec_cnt++;
                cnts.rec_sent_cnt++;
                cnts.sum_rec_cnt++;

                // Analyze reponse
                xassert (data_ch_ab_bidir.source == task_a);
                xassert (data_ch_ab_knock.KnockCome_Message_Type == KC_TYP_SM_KNOCK);

                #if (PRINT_KNOCKCOME==1)
                    update_fairness_cnts (cnts);
                    if (cnts.rec_sent_cnt == MAX_SUM_CNT) {
                        print_and_clear_debug_cnts (cnts);
                    } else {}
                #endif
            } break;

            case tmr when timerafter (time_ticks) :> void : {
                random_delay_us = (random_get_random_number (random_seed)) % RANDOM_VAL_MAX_US;
                time_ticks     += (random_delay_us * XS1_TIMER_MHZ);

                data_ch_ab_bidir.KnockCome_Message_Type = KC_TYP_NONE_DATA;
                data_ch_ab_bidir.source = task_b;

                data_ch_ab_bidir.data.data_from_task_b_master = data_from_task_b_master;

                ch_ab_bidir <: data_ch_ab_bidir; // SEND
                p1_out_purple_master <: data_from_task_b_master; // bit0 (any single pulse in here is too short, just toggle on every new transaction)
                data_from_task_b_master = data_from_task_b_master + DATA_FIRST_AND_INC;

                cnts.sent_cnt++;
                cnts.rec_sent_cnt++;
                cnts.sum_sent_cnt++;

                #if (PRINT_KNOCKCOME==1)
                    update_fairness_cnts (cnts);
                    if (cnts.rec_sent_cnt == MAX_SUM_CNT) {
                        print_and_clear_debug_cnts (cnts);
                    } else {}
                #endif
            } break;
        }
    }
} // task_b_master

// See different port syntax forms at https://www.teigfam.net/oyvind/home/technology/141-xc-is-c-plus-x/#port_construct_of_xc

// GPIO  PORT LED
// X0D14 P4C0 0
// X0D15 P4C1 1
// X0D20 P4C2 2
// X0D21 P4C3 3
port out p4_leds     = on tile[0]: XS1_PORT_4C; // [X0D14,X0D15,X0D20,X0D21] LEDS   0-3 (bit0-3) also as PORT_LEDS in autogenerated platform.h)
port out p1_out_blue_slave = on tile[0]: XS1_PORT_1A; // [X0D00]                   J14 pin  2 (bit0)
port out p1_out_purple_master  = on tile[0]: XS1_PORT_1D; // [X0D11]                   J14 pin 15 (bit0)

/* 
From XK-EVK-XU316 xcore.ai Evaluation Kit Manual (2022/7/21 XM014531A) page 10:

GPIO connector J14 (Tile 0). Note: Some shared with LEDs and BUTtons.
P1A is 1 bit  port
P1D is 1 bit  port
P4C is 4 bits port
P4C is 4 bits port
Sum 10 pins

XMOS naming convention: XS1_PORT_1A on tile[0] X0D00, on tile[1] : X1D00

Signal Port     Pin   Signal Port      Pin
VDDIOL            1   X0D00  P1A         2
X0D14  P4C0(LED0) 3   GND                4
X0D15  P4C1(LED1) 5   X0D16  P4D0(BUT0)  6
X0D17  P4D1(BUT1) 7   GND                8
GND               9   X0D18  P4D2       10
X0D19  P4D3      11   X0D20  P4C2(LED2) 12
GND              13   X0D21  P4C3(LED3) 14
X0D11  P1D       15   GND               16
*/

int main()
{
    STREAMING chan ch_ab_knock ; // ch_ab_knock_t
    chan           ch_ab_bidir ; // ch_ab_bidir_t or ch_ab_struct_with_array_t


    par {
        on tile[0]:          // .core[1]: not combinable so cannot explicitly place on core (*)
            task_a_slave (   // Must wait knock response to send 
                ch_ab_bidir, // ch_ab_bidir_t
                ch_ab_knock, // ch_ab_knock_t
                p1_out_blue_slave);
        on tile[0]:           // .core[0]: This is how they end up, see on crash (*)
            task_b_master (   // Can send any time
                ch_ab_bidir,  // ch_ab_bidir_t
                ch_ab_knock, // ch_ab_knock_t
                p1_out_purple_master, 
                p4_leds);
        // (*) Same tile[0] so streaming chan does not  occupy a route through the HW switch within the scope of the task
    }
    return 0;
} // main

