/*
 * my_random.xc
 *
 *  Created on: 28. July 2026
 *      Author: oyvindteig
 */

#define INCLUDES
#ifdef INCLUDES
    #include <xs1.h>
    #include <platform.h> // slice
                          // For _XTC #include _PLATFORM_INCLUDE_FILE (-> xc_test_knock_come/build/autogen_headers/tgt_xc_test_knock_come/platform.h)
    #include <syscall.h>  // _XTC new for me
    #include <timer.h>    // delay_milliseconds(200), XS1_TIMER_HZ etc
    #include <stdio.h>    // printf
    #include <iso646.h>   // not etc.
    #include <xassert.h>
    #include <random.h>   // A file "random_conf.h" here with #define RANDOM_ENABLE_HW_SEED 1 needs to be defined
    #include <limits.h>
    #include <stdint.h>
    #include <print.h>
    #include "__globals.h"
    #include "my_random.h"
#endif

// ===========================================================================================
// xorshift32
// Algorithm "xor" from p. 4 of Marsaglia, "Xorshift RNGs"
//
// For use when USE_RANDOM_TYPE is LOCAL_XORSHIFT32 or LOCAL_XORSHIFT32_SYMMETRIC
//
// Started from https://en.wikipedia.org/wiki/Xorshift#Example_implementation
// Linear polynomial function, a subset of the "clean" LFSR (linear-feedback-shift register).
// It does not test the BigCrush test suite.
// Non-linear functions like xorwow are better statistically.
// ===========================================================================================
//
random_unsigned32_t xorshift32 (randoms_t &randoms) {
	random_unsigned32_t x = randoms.random_ssgn; 
	x ^= x << 13;
	x ^= x >> 17;
	x ^= x << 5;
    randoms.random_ssgn = x;
	return x; // aliases randoms.random_ssgn. Somewhat strange programming practice for me
}

// =====================================================================================================
// Investigation, basically to find the longest consequtive sequence of negative number from xorshift32:
// find_max_consecutive_bit31_xorshift32 does this. This is done for the "symmetric" algorithm I have 
// "invented" for pseudorandom numbers. I did this in next_symmetric_random_get_random_number,
// and added a test there involving DROP_BIT_CNT_MAX. I had seen this to be max 21 and that's where
// asking Geoogle AI entered the sceen. I asked, what could itd value really be?
// I didn't think walking around 2ˆ32 = 4 Giga rounds was feasable. But it is, even on an XCORE.
//
// These functions iterate through the entire Xorshift32 period, prints statistics, 
// and returns the longest continuous sequence of the bit in question. 
// Just for fun I wanted to see how bit_con_seq_cnt_max would be for all bits. 
// find_max_consecutive_allbits_xorshift32 does this. Finding these values by 
// math is possible since xorshift32 is Polynomial. I will come back to this.
// =====================================================================================================

 typedef struct { // _con = consecutive
    uint32_t state; // number, value or seed, any name goes
    uint32_t bit_con_seq_cnt_max;  
    uint32_t bit_con_seq_cnt;
    uint64_t bit_round_cnt;
 } stats_t;

void init_stats (stats_t &stats, const uint32_t initial_seed) {
    stats.state               = initial_seed; // "state" is filled with "seed", math naming is rather confusing
    stats.bit_con_seq_cnt_max = 0;
    stats.bit_con_seq_cnt     = 0;
    stats.bit_round_cnt       = 0;
} // init_stats

// Local function used in 
// find_max_consecutive_bit31_xorshift32 and 
// find_max_consecutive_allbits_xorshift32
//
void do_xorshift32_etc (stats_t &stats, const uint32_t bitmask) {
    
    // Standard xorshift32 algorithm (Marsaglia triples: 13, 17, 5)
    stats.state ^= stats.state << 13;
    stats.state ^= stats.state >> 17;
    stats.state ^= stats.state << 5;
    
    // In 2's complement, a number is negative if its MSB is 1
    if (stats.state & bitmask) { 
        stats.bit_con_seq_cnt++;
        if (stats.bit_con_seq_cnt > stats.bit_con_seq_cnt_max) { // This Google AI placed when positive and finally, I place it here
            stats.bit_con_seq_cnt_max = stats.bit_con_seq_cnt;
        }
    } else { // Positive
        stats.bit_con_seq_cnt = 0;
    }           
    stats.bit_round_cnt++; 
} // do_xorshift32_etc

// Soleley to find by brute force the value I need for DROP_BIT_CNT_MAX as needed in next_symmetric_random_get_random_number
//
// After 3064 seconds, total numbers checked:  4294967295 (2^32 - 1)
// Max consecutive negatives found: 32 (=DROP_BIT_CNT_MAX)
//
uint32_t find_max_consecutive_bit31_xorshift32 
    (const uint32_t initial_seed,
    port out        p1_out_blue) {
    
    stats_t  stats;
    timer    tmr;
    time32_t time_ticks;
    unsigned num_seconds = 0;
    bool     p1_val = false;

    printf("Starting full state-space simulation with seed %u in code at %s %s. Please wait about 52 minutes...\nmins:\n\n", initial_seed, __TIME__, __DATE__);

    init_stats (stats, initial_seed);

    tmr :> time_ticks;
    p1_out_blue <: p1_val;
    do_xorshift32_etc (stats, INT_MIN); // Now while-cond does not hit after 1 round

    do {
        [[ordered]] 
        select {
            case tmr when timerafter (time_ticks) :> void: {
                time_ticks += XS1_TIMER_HZ;
                num_seconds++;
                if ((num_seconds % 60) == 0) {
                    printf("%u\n", num_seconds / 60);
                }
            } break;
            default: {               
                p1_out_blue <: p1_val; // Every (1.43 us / 2) * 4294967296 (32 bits full range) = 3064 secs = 51.07 mins
                p1_val = not p1_val;
                do_xorshift32_etc (stats, INT_MIN); // INT_MIN is 0x80000000 is bit31
            } break;
        }          
    } while (stats.state != initial_seed); // Terminates when we complete the full cycle

    // All terminal outputs are now grouped together here
    printf("\n=== Simulation Complete ===\n");
    printf("After %u seconds, total numbers checked:  %llu (2^32 - 1)\n", num_seconds, (unsigned long long)stats.bit_round_cnt);
    printf("Max consecutive negatives found: %u\n", stats.bit_con_seq_cnt_max);
    
    return stats.bit_con_seq_cnt_max;
} // find_max_consecutive_bit31_xorshift32

// Find by brute force the values for "DROP_BIT_CNT_MAX" for all 32 bits. Those for bit0..bit30 are not really needed, this is just for fun.
// That one for bit31 is DROP_BIT_CNT_MAX, but it's already found in find_max_consecutive_bit31_xorshift32.
//
// ALL BIT'S MAXRUN SEQUENCES ARE 32 LONG:
//
// Pretty-printed (by Google AI) log, as of 02Aug2026 v0.936
// Simulation hours
// Row 1: 1-16, Row 2: 17-24
// 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
// 17, 18, 19, 20, 21, 22, 23, 24

// Max consecutive bit sequences found
// Row 1: Indices 0-15, Row 2: Indices 16-31
// 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
// 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32

// Simulation metadata:
// Start: 10:11:16 Aug 1 2026
// Duration: 89170 seconds
// Total checked: 4294967295 (2^32 - 1)
//
uint32_t find_max_consecutive_allbits_xorshift32 
    (const uint32_t initial_seed,
    port out        p1_out_blue) {
   
    timer    tmr;
    time32_t time_ticks;
    unsigned num_seconds = 0;
    bool     p1_val = false;

    printf("Starting full state-space simulation with seed %u in code at %s %s. Please wait some 25 hours...\nhours:\n\n", initial_seed, __TIME__, __DATE__);
    stats_t stats [BITSNUM32];

    for (unsigned ix=0; ix<BITSNUM32; ix++){
       init_stats (stats[ix], initial_seed);
    }

    tmr :> time_ticks;
    p1_out_blue <: p1_val;

    for (unsigned ix=0; ix<BITSNUM32; ix++){
       do_xorshift32_etc (stats[ix], 1<<ix);
    }
    // Now while-cond does not hit after 1 round
    do {
        [[ordered]] 
        select {
            case tmr when timerafter (time_ticks) :> void: {
                time_ticks += XS1_TIMER_HZ;
                num_seconds++;
                if ((num_seconds % 3600) == 0) {
                    printf("%u\n", num_seconds / 3600);
                }
            } break;
            default: {               
                p1_out_blue <: p1_val; // Every (21 us) * 4294967296 (32 bits full range) = 89170 secs = 24.77 hours (as printed out, see above)
                p1_val = not p1_val;
                for (unsigned ix=0; ix<BITSNUM32; ix++){
                    do_xorshift32_etc (stats[ix], 1<<ix);
                }
            } break;
        }          
    } while (stats[0].state != initial_seed); // Terminates when we complete the full cycle
    // } while (stats[0].bit_round_cnt < 1000); To test

    // All terminal outputs are now grouped together here
    printf("\n=== Simulation Complete ===\n");
    printf("After %u seconds, total numbers checked:  %llu (2^32 - 1)\n", num_seconds, (unsigned long long)stats[0].bit_round_cnt);
    printf("Max consecutive negatives found:\n");

    for (unsigned ix=0; ix<BITSNUM32; ix++){
        printf ("[%u]=%u\n", ix, stats[ix].bit_con_seq_cnt_max);
    }
    
    return stats[0].bit_con_seq_cnt_max;

} // find_max_consecutive_allbits_xorshift32

// =========================================================================================================================
// Functions used by xc_test_knock_come.xc
//
// The below at the start was concentrated aroun XMOS lib_random. This caused me to issue a ticket to XMOS, since I saw
// an error in it. See https://github.com/xmos/lib_random/issues/33
// 
// See https://www.xmos.com/documentation/XM-011312-UG/html/doc/rst/lib_random.html
//
// random_get_random_number: New value of random_seed or just let random_get_random_number use the one that it stores in
// random seed yields the same result
//
// Use of random_create_generator_from_seed or random_create_generator_from_hw_seed 
// Both create pesudo random numbers, and starting point is not interesting here, so I chose the second (starting at 0.0.917).
// It uses a 32-bit LFSR (linear-feedback-shift register) to generate a pseudo random string of random bits.
// The alternative slower (*) method in lib_random uses the on-chip ring oscillators to create a random bit
// after some time has elapsed. I have not set this generation off to a saparate task, so I won't use it.
// (*) Slower means RANDOM_RO_MIN_TIME_FOR_ONE_BIT gives 5000 bits/second, ie. [0-99] is seven bits, so it 
// would mean 5000/7=715 new random values per second. Ok for the max 100 ms (average 50). For [0..9] we have
// four bits, 5000/4=1250 per second, much too few than the 200000 needed for 5us average. However, since
// the shortest is always 0, a new random value would have to be there immediately, which completely
// outrules the ring oscillator solution.
//
// Since update_fairness_cnts is called in task_master the theoretical values of "DT xx.yys" in the log
// is based on RANDOM_VAL_MAX_US as (49.5 ms * MAX_SUM_CNT ) / 2 = 49.5s / 2 = 24.75. However, see typical values below
//
// See https://www.xcore.com/viewtopic.php?t=9317 "Different average random values when hw or sw seed and use of LFSR" on XCore Exchange
// =========================================================================================================================

// Different methods of random_create_generator needed during development phase
//
random_unsigned32_t random_create_generator (const random_unsigned32_t random_seed) {
    xassert (random_seed != 0);
    random_unsigned32_t random_generator = random_seed; // Some value when not used
    
    #if (USE_RANDOM_TYPE == LIB_RANDOM_SW_SEED)
        random_generator = random_create_generator_from_seed(random_seed);
    #elif (USE_RANDOM_TYPE == LIB_RANDOM_HW_SEED)
        random_generator = random_create_generator_from_hw_seed(random_seed); 
    #elif (USE_RANDOM_TYPE == LIB_RANDOM_SW_SEED_LOCAL_SYMMETRIC)
        random_generator = random_seed;
    #elif (USE_RANDOM_TYPE == LOCAL_XORSHIFT32)
        random_generator = random_seed;  
    #elif (USE_RANDOM_TYPE == LOCAL_XORSHIFT32_SYMMETRIC)
        random_generator = random_seed; 
    #else
        #error
    #endif

    return random_generator; // See random_ssgn
} // random_create_generator

// Different methods of random_get_random_number_special needed during development phase
//
random_unsigned32_t random_get_random_number_special (randoms_t &randoms) {
    #if (USE_RANDOM_TYPE == LIB_RANDOM_SW_SEED)
        random_get_random_number (randoms.random_ssgn); // randoms.random_ssgn old value in and new value out (ignoring return value)
    #elif (USE_RANDOM_TYPE == LIB_RANDOM_HW_SEED)
        random_get_random_number (randoms.random_ssgn); 
    #elif (USE_RANDOM_TYPE == LIB_RANDOM_SW_SEED_LOCAL_SYMMETRIC)
        next_symmetric_random_get_random_number (randoms); // Uses random_get_random_number internally. Updates all of randoms because it needs it itself
    #elif (USE_RANDOM_TYPE == LOCAL_XORSHIFT32)
        xorshift32 (randoms); // // Updates randoms.random_ssgn only
    #elif (USE_RANDOM_TYPE == LOCAL_XORSHIFT32_SYMMETRIC)
        next_symmetric_random_get_random_number (randoms); // Uses xorshift32 internally. Updates all of randoms because it needs it itself
    #else
        #error
    #endif

    return randoms.random_ssgn;
} // random_get_random_number_special

// Only called at startup of tasks
//
void init_randoms (
    randoms_t                 &randoms,
    const random_unsigned32_t random_seed) {

    randoms.random_ssgn = random_create_generator (random_seed); 
    
    randoms.use_random_negated    = false; 
    randoms.random_ssgn_prev      = randoms.random_ssgn;
    randoms.max_loop_pos_cnt      = 0;
    randoms.max_loop_neg_cnt      = 0;
    randoms.max_loop_neg_cnt_ever = 0;
} // init_randoms

// ============================================================================
// next_symmetric_random_get_random_number
//
// Algorithm invented by me, Øyvind Teig in June 2026
//
// When the generator returns a "negative" number, ie. unsigned bit31 set,
// it is dropped until a positive number is returned. Use that postive number,
// but for the next value, use "the negative" as 2's complement of the just used
// positive number. Then repeat.
// All dropped negative numbers will sooner or later appear.
// For every EVEN number of pseudorandom values asked for,
// the mean value will now be half the value of the UINT_MAX range = "SYMMETRIC"
//
// It will probably have lower statistical quality than the subset of LFSR in xorshift32 or clean LFSR in lib_random, 
// since every other value is deducted from the previous, such that it's also possibel to deuce the previous value. 
// xorshift32 does not pass the BigCrush test suite, as would not this function either, then.
// But if like xorwow were used in next_symmetric_random_get_random_number, maybe?
//
// For use when USE_RANDOM_TYPE is LIB_RANDOM_SW_SEED_LOCAL_SYMMETRIC or LOCAL_XORSHIFT32_SYMMETRIC
//
void next_symmetric_random_get_random_number (randoms_t &randoms) {
    if (randoms.use_random_negated) {
        // Use negative value of last positive
        // This makes it symmetric around zero, seen as signed, however..
        // .. seem as unsigned it is symmetric on half the number range
        random_signed32_t random_signed32;
      
        random_signed32            = (random_signed32_t) randoms.random_ssgn;
        randoms.random_ssgn        = (random_unsigned32_t) (-random_signed32);
        randoms.use_random_negated = false;

    } else { // randoms.use_random_negated false
        unsigned max_loop_pos_cnt = 0;
        unsigned max_loop_neg_cnt = 0;

        // From limits.h plus here
        // __INT_MAX__ =                                          2147483647
        //
        // UINT_MAX    = (INT_MAX * 2U + 1) = (2147483647*2)+1 =  4294967295 = 0xffffffff (-1 signed ) 
        // INT_MAX     = __INT_MAX__        =                     2147483647 = 0x7fffffff (UINT_MAX/2)
        // UINT_MIN    =                                                   0 = 0x00000000
        // INT_MIN     = (-INT_MAX-1)       = -2147483647-1    = -2147483648 = 0x80000000
        
        randoms.random_ssgn = randoms.random_ssgn_prev; // Restore previous used in the generator
        
        while (randoms.use_random_negated == false) {  // Either it goes to true or the xassert
            
            #if (USE_RANDOM_TYPE == LIB_RANDOM_SW_SEED_LOCAL_SYMMETRIC)
                random_get_random_number (randoms.random_ssgn); // randoms.random_ssgn old value in and new value out (ignoring return value)
            #elif (USE_RANDOM_TYPE == LOCAL_XORSHIFT32_SYMMETRIC)
                xorshift32 (randoms); // Updates randoms.random_ssgn
            #else
                xassert (false); // One that's not _SYMMETRIC
            #endif
            // Was < (UINT_MAX/2)) { which spelt out to < 0x7fffffff which should have been <=
            if ((randoms.random_ssgn bitand INT_MIN) != 0) { // INT_MIN = 0x80000000, ie bit32 set for negative numbers in 2's complement
                // Use postive value, but next time, use the negative value of it
                randoms.use_random_negated = true;                // Use as negative next time in next_symmetric_random_get_random_number
                randoms.random_ssgn_prev   = randoms.random_ssgn; // But after that, use this here
                max_loop_pos_cnt++;
                if (max_loop_pos_cnt > randoms.max_loop_pos_cnt) {
                    randoms.max_loop_pos_cnt = max_loop_pos_cnt;
                } else {}
            } else {
                // Drop negative value
                // If like "n" dropped here those calls have been "used up", but since each number 
                // is reached once, and only once, it will be balanced with "n" calls that
                // will return positive values
                max_loop_neg_cnt++;
                if (max_loop_neg_cnt > randoms.max_loop_neg_cnt) {
                    randoms.max_loop_neg_cnt = max_loop_neg_cnt; // new max
                    if (max_loop_neg_cnt > randoms.max_loop_neg_cnt_ever) {
                        randoms.max_loop_neg_cnt_ever = max_loop_neg_cnt; // new max ever
                    } else {}                 
                } else {}
                xassert (randoms.max_loop_neg_cnt <= DROP_BIT_CNT_MAX);
            }
        }

    }
} // next_symmetric_random_get_random_number

// Taken from  /Users/teig/Documents/_Dokumenter/Oyvind/_PROSJEKT/GitHub/workspace/lib_random/examples/app_random/src/main.c 
// See XMOS Ticket 339260 "lib_random seems to give repeated pattern" by me 26Jul2026
//
int lib_random_example() {
    #define RAND_SEED (8369)
    #define RAND_BUF_LEN (256) // Was 8. Since byte, it should not be repeated

    printstr("\n26Jul2026 16.21\n= unsigned =\n");
    // Create a generator with a software seed
    random_generator_t rg_sw = random_create_generator_from_seed(RAND_SEED);

    // Generate a single random value and print it. Was printing of single value
    for (unsigned ix=0; ix <RAND_BUF_LEN; ix++ ) {
        unsigned rand_val = random_get_random_number(rg_sw); // was &rg_sw (C-code)
        printuintln(rand_val);
    }
    // Last log seen here is with v0.935

    printstr("\n= bytes =\n");
    // Create a generator with a hardware seed
    random_generator_t rg_hw = random_create_generator_from_hw_seed();

    // Generate a set of random bytes and print them
    uint8_t rand_buf[RAND_BUF_LEN];
    random_get_random_bytes(rg_hw, rand_buf, RAND_BUF_LEN); // was &rg_sw (C-code)

    for (int idx = 0; idx < RAND_BUF_LEN; ++idx) {
        printuintln(rand_buf[idx]);
    }
    // Last log seen here is with v0.935

    printstr("\n= bits =\n");
    random_ro_init();
    for (int i = 0; i < 10; ++i) {
        int bit;
        do {
            bit = random_ro_get_bit();
            // You could sleep here for -bit timer ticks.
        } while(bit < 0);
        printint(bit);
    }
    random_ro_uninit();
    printstr("\n= done =\n");

    return 0;

    // Last log seen here is with v0.935
}