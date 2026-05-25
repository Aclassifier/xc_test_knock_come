/*
 * xc_test_knock_come.xc
 *
 *  Created on: 20. mai 2026
 *      Author: oyvindteig
 */

#define INCLUDES
#ifdef INCLUDES
    #include <xs1.h>
    #include <platform.h> // slice
    #include <timer.h>    // delay_milliseconds(200), XS1_TIMER_HZ etc
    #include <stdint.h>   // uint8_t
    #include <stdio.h>    // printf
    #include <string.h>   // memcpy
    #include <xccompat.h> // REFERENCE_PARAM(my_app_ports_t, my_app_ports) -> my_app_ports_t &my_app_ports
    #include <iso646.h>   // not etc.
    #include <xassert.h>
    #include <random.h>   // A file "random_conf.h" here with #define RANDOM_ENABLE_HW_SEED 1 needs to be defined
#endif

#define KNOCK_COME_VERSION_STR "0.0.912" // x.y.zzz
#define KNOCK_COME_TIME __TIME__
#define KNOCK_COME_DATE __DATE__

// =============================================================================================
// VERSIONS
// =============================================================================================
// 24May2026 0.0.912 URL to blog note updated
//                   Description uodated and some renaming
//                   task_a_master -> task_b_master
// 24May2026 0.0.911 print_and_clear_cnts added last > = <
//                   print_welcome_banner is new
//                   Conditional printing done in macros
// 23May2026 0.0.910 ch_ba_knock -> ch_ab_knock
//                   DEADLOCK_NO_STREAMING_CHAN is new
// 21May2026 0.0.900 Initial version. Sent to Antonio
// =============================================================================================

typedef enum {false,true} bool;

typedef signed int time32_t; // signed int (=signed) or unsigned int (=unsigned) both ok, as long as they are monotoneously increasing
                             // XC/XMOS 100 MHz increment every 10 ns for max 2exp32 = 4294967296,
                             // ie. divide by 100 mill = 42.9.. seconds

#define DEBUG_KNOCKCOME                  1 // 0 no printing, 1 log produced
#define DEADLOCK_NO_STREAMING_CHAN       0 // 0 (to get it to work), 1 (deadlocks)
#define TEST_STREAMING_CHAN_DOUBLE_KNOCK 0 // 0 standard single send on streaming ch_ab_knock, 1 double send will cause double COME and crash

#if (DEADLOCK_NO_STREAMING_CHAN==0)
    #define STREAMING streaming // ch_ab_knock the HW layer buffers at leat TWO 32 bits words, see TEST_STREAMING_CHAN_DOUBLE_KNOCK==1
    // https://www.xcore.com/viewtopic.php?t=3737
    //   A normal channel end sets up and closes the connection each time data is transferred.
    //   A streaming channel end sets up the connection, and keeps it open within the scope of the function.
    //   It's a bit like packet switched vs. circuit switched. It means a streaming chan is faster (although both are pretty fast) 
    //   due to not having overhead of setup and close, but it occupies a route through the switch. This is not an issue on a single 
    //   tile where you are only limited by chanends count, but in dual tile systems you typically get only 4 paths from tile to tile,
    //   so streaming channels should be used cautiously across tiles. This code uses single tile, so streaming chan use is fine.
    //   The protocol is different so you cannot mix streaming/no streaming channel end types.
#else // DEADLOCK_NO_STREAMING_CHAN 1
    #define STREAMING // ch_ab_knock not buffered will cause deadlock!
#endif

/*
State machine for the KnockCome (Knock-Come, Knock_Come) pattern

The knock-come pattern is described in the documentation of the code.
See usage in the files and in the data-flow diagram below

It is also described in these blog notes:
   [The "knock-come" deadlock free pattern]
       https://www.teigfam.net/oyvind/home/technology/009-the-knock-come-deadlock-free-pattern/
   [My Beep-BRRR notes - Decoupling slave_task_a and master_task_b - Implementation D]
       https://www.teigfam.net/oyvind/home/technology/219-my-beep-brrr-notes/#implementation_d

But here's an example as well. Purpose: slave_task_a and master_task_b want to spontaneously send to the other part:

slave_task_a and master_task_b can both spontaneously initiate sending to each other this way,
and they will never deadlock since the KNOCK channel from slave_task_a to master_task_b comprises a
streaming chan in XC. The XCORE processor has a buffer of at least one 32-bit variable for the nessage,
which

KNOCK: ch_ab_knock carries the "KNOCK" data-less "message"
    slave_task_a initiates every communication with first sending a signal (no data)
    on the signal streaming ch_ab_knock chan  (no data, it never blocks since it si streaming
    and the XCORE buffers at least one word) to master_task_b. This is the "knock".
    ("_ab_" means from slave_task_a to master_task_b)

    ch_ab_bidir carries "COME" message
    When the master_task_b is ready to take full data it sends a "come" message back. The slave_task_a
    receives this "come". ("_ba_" means from master_task_b to slave_task_a)

ch_ab_bidir carries the data
> master_task_b expects to see only the data in return, so it can wait for it in the "next line" after Come.
> slave_task_a then immediately, by contract, in the "next line" must send off the data set it originally wanted to.
> slave_task_a, after it sent knock, must be able to handle any message from master_task_b, because they may be other data, since
> master_task_b is allowed to send on ch_ab_bidir *any* time


But it's enough to use knock-come only one way. Therefore master_task_b
only needs ch_ab_bidir to send anything, at any time (and some times it's the knock message).
*/

typedef enum {           // NEEDS
    KC_TYP_NONE_DATA, // Master sends spontaneous data to Slave, not part of knock-come scheme
    KC_TYP_SM_KNOCK,     // Slave to Master (not necessary since anything on this streaning chan makes sense)
    KC_TYP_COME,      // Master sends "come!" to Slave, no piggy.backed data
    KC_TYP_COME_DATA, // Master sends "come!" to Slave, but also includes spontaneous piggy-backed data
    KC_TYP_SM_DATA       // Slave sends data to Master. Knock-Come Sequence finished
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
                xassert (PresentState == KC_STATE_SLAVE_SENT_KNOCK); // if (TEST_STREAMING_CHAN_DOUBLE_KNOCK==1) then
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

#if (DEBUG_KNOCKCOME==1)
    #define RANDOM_VAL_MAX_MS 100
#else
    #define RANDOM_VAL_MAX_MS  10
#endif

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


void init_cnts (cnts_t &cnts)
{
    cnts.sent_cnt          = 0;
    cnts.rec_cnt           = 0;
    cnts.rec_sent_cnt      = 0;
    cnts.rec_gt_sent_cnt   = 0;
    cnts.rec_eq_sent_cnt   = 0;
    cnts.rec_lt_sent_cnt   = 0;
    cnts.sum_sent_cnt      = 0;
    cnts.sum_rec_cnt       = 0;
} // init_cnts


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


void print_welcome_banner()
{
    printf ("XCC %u.%u KNOCK-COME %s on date %s %s\nTime random max %u ms, cnt events at %u (Teig)\n\n",
            XCC_VERSION_MAJOR, XCC_VERSION_MINOR,
            KNOCK_COME_VERSION_STR,
            KNOCK_COME_DATE, KNOCK_COME_TIME,
            RANDOM_VAL_MAX_MS, MAX_SUM_CNT);
} // print_welcome_banner


void print_and_clear_cnts (cnts_t &cnts)
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
} // print_and_clear_cnts


#if (DEBUG_KNOCKCOME==1)
    #define PRINT_AND_CLEAR_CNTS(cnts) print_and_clear_cnts(cnts)
    #define PRINT_WELCOME_BANNER       print_welcome_banner()
#else
    #define PRINT_AND_CLEAR_CNTS(cnts)
    #define PRINT_WELCOME_BANNER
#endif


void print_deadlock_banner()
{
    printf ("ch_ab_knock is not buffered, system will deadlock.\n"
            "This is last print. Wait one minute to confirm.\n\n");
} // print_deadlock_banner


#if (DEADLOCK_NO_STREAMING_CHAN==1)
    #define PRINT_DEADLOCK_BANNER print_deadlock_banner()
#else
    #define PRINT_DEADLOCK_BANNER
#endif

// Must wait knock response to send
void task_a_slave (
    chanend           ch_ab_bidir, // ch_ab_bidir_t
    STREAMING chanend ch_ab_knock) // ch_ab_knock_t
{
    timer             tmr;
    time32_t          time_ticks;
    ch_ab_bidir_t     data_ch_ab_bidir;
    KnockCome_State_e KnockCome_State;
    ch_ab_knock_t     data_ch_ab_knock;
    unsigned          data_from_task_a_slave  = DATA_FIRST_AND_INC;
    unsigned          data_from_task_b_master = 0; // So that the first received is DATA_FIRST_AND_INC more
    unsigned          random_seed             = random_create_generator_from_seed(RANDOM_SEED_SLAVE); // xmos
    unsigned          random_delay_ms         = random_seed % RANDOM_VAL_MAX_MS;

    SLAVE_SET_KNOCKCOME_STATE (KnockCome_State, KC_STATE_SLAVE_SENT_DATA_NOW_READY);
    data_ch_ab_knock.KnockCome_Message_Type = KC_TYP_SM_KNOCK;

    tmr :> time_ticks;

    while (true) {
       [[ordered]] // Needed even if LIMIT_USED_TICKS used. TODO why?
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
                   ch_ab_bidir <: data_ch_ab_bidir; // SEND
                   data_from_task_a_slave = data_from_task_a_slave + DATA_FIRST_AND_INC;

                   SLAVE_SET_KNOCKCOME_STATE (KnockCome_State, KC_STATE_SLAVE_SENT_DATA_NOW_READY);
               } else {}

           } break;

           case tmr when timerafter (time_ticks) :> void: {
               ch_ab_bidir_t data_ch_ab_bidir; // Here: limits scope of struct with union

               random_delay_ms = (random_get_random_number (random_seed)) % RANDOM_VAL_MAX_MS;
               time_ticks     += (random_delay_ms * XS1_TIMER_KHZ);

               if (KnockCome_State == KC_STATE_SLAVE_SENT_DATA_NOW_READY) {

                   ch_ab_knock <: data_ch_ab_knock; // streaming chan buffers at least two 32 bits words
                   #if (TEST_STREAMING_CHAN_DOUBLE_KNOCK==1)
                       ch_ab_knock <: data_ch_ab_knock; // Will be buffered as two and cause an extra COME and rash
                   #endif

                   SLAVE_SET_KNOCKCOME_STATE (KnockCome_State, KC_STATE_SLAVE_SENT_KNOCK);

               } else {}

           } break;
       }
    }
} // task_a_slave


// Can send any time
void task_b_master (
    chanend           ch_ab_bidir, // ch_ab_bidir_t
    STREAMING chanend ch_ab_knock) // ch_ab_knock_t
{
    timer         tmr;
    time32_t      time_ticks;
    ch_ab_bidir_t data_ch_ab_bidir;
    ch_ab_knock_t data_ch_ab_knock;
    unsigned      data_from_task_b_master = DATA_FIRST_AND_INC;
    unsigned      data_from_task_a_slave  = 0; // So that the first received is DATA_FIRST_AND_INC more
    unsigned      random_seed             = random_create_generator_from_seed(RANDOM_SEED_MASTER); // xmos
    unsigned      random_delay_ms         = random_seed % RANDOM_VAL_MAX_MS;
    cnts_t        cnts;

    init_cnts (cnts);

    PRINT_WELCOME_BANNER;
    PRINT_AND_CLEAR_CNTS (cnts);
    PRINT_DEADLOCK_BANNER;

    data_ch_ab_bidir.data.data_from_task_b_master = 0;

    tmr :> time_ticks; // Immediately

    while (true) {
        [[ordered]] // Ok, but not strictly necessary
        select {
            case ch_ab_knock :> data_ch_ab_knock : {
                xassert (data_ch_ab_knock.KnockCome_Message_Type == KC_TYP_SM_KNOCK);
                // Build response
                data_ch_ab_bidir.source = task_b;
                // No need to add any data here, so       KC_TYP_COME_DATA is never used:
                data_ch_ab_bidir.KnockCome_Message_Type = KC_TYP_COME;

                // =============================================================
                // INSIDE THIS CASE CONTIUE WITH THIS ATOMIC KNOCK-COME SEQUENCE
                // =============================================================

                ch_ab_bidir <: data_ch_ab_bidir; // SEND
                ch_ab_bidir :> data_ch_ab_bidir; // RECEIVE

                unsigned data_from_task_a_slave_now = data_ch_ab_bidir.data.data_from_task_a_slave;
                xassert (data_from_task_a_slave_now == (data_from_task_a_slave + DATA_FIRST_AND_INC));
                data_from_task_a_slave = data_from_task_a_slave_now;

                cnts.rec_cnt++;
                cnts.rec_sent_cnt++;
                cnts.sum_rec_cnt++;

                // Analyze reponse
                xassert (data_ch_ab_bidir.source == task_a);
                xassert (data_ch_ab_knock.KnockCome_Message_Type == KC_TYP_SM_KNOCK);

                #if (DEBUG_KNOCKCOME==1)
                    update_fairness_cnts (cnts);
                    if (cnts.rec_sent_cnt == MAX_SUM_CNT) {
                        print_and_clear_cnts (cnts);
                    } else {}
                #endif
            } break;

            case tmr when timerafter (time_ticks) :> void : {
                random_delay_ms = (random_get_random_number (random_seed)) % RANDOM_VAL_MAX_MS;
                time_ticks     += (random_delay_ms * XS1_TIMER_KHZ);

                data_ch_ab_bidir.KnockCome_Message_Type = KC_TYP_NONE_DATA;
                data_ch_ab_bidir.source = task_b;

                data_ch_ab_bidir.data.data_from_task_b_master = data_from_task_b_master;
                ch_ab_bidir <: data_ch_ab_bidir; // SEND
                data_from_task_b_master = data_from_task_b_master + DATA_FIRST_AND_INC;

                cnts.sent_cnt++;
                cnts.rec_sent_cnt++;
                cnts.sum_sent_cnt++;

                #if (DEBUG_KNOCKCOME==1)
                    update_fairness_cnts (cnts);
                    if (cnts.rec_sent_cnt == MAX_SUM_CNT) {
                        print_and_clear_cnts (cnts);
                    } else {}
                #endif
            } break;
        }
    }
} // task_b_master


int main()
{
    STREAMING chan ch_ab_knock ; // ch_ab_knock_t
    chan           ch_ab_bidir ; // ch_ab_bidir_t or ch_ab_struct_with_array_t
    par {
        on tile[0]:           // .core[1]: not combinable so cannot explicitly place on core (*)
            task_a_slave (    // Must wait knock response to send 
                ch_ab_bidir,  // ch_ab_bidir_t
                ch_ab_knock); // ch_ab_knock_t
        on tile[0]:           // .core[0]: This is how they end up, see on crash (*)
            task_b_master (   // Can send any time
                ch_ab_bidir,  // ch_ab_bidir_t
                ch_ab_knock); // ch_ab_knock_t
        // (*) Same tile[0] so streaming chan does not  occupy a route through the HW switch within the scope of the task
    }
    return 0;
} // main

