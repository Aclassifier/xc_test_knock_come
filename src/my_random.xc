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

#define XMOS_ISSUE_11AUG2026 0

#define DO_FIND_32BITS_ONES_CNT  1 // Standard up to 0.947
#define DO_FIND_32BITS_ZEROS_CNT 2
//
#define DO_CNT DO_FIND_32BITS_ZEROS_CNT

typedef struct { // _con = consecutive
    uint32_t state;               // number, value or seed, any name goes
    uint32_t bit_con_seq_cnt_max; // DO_FIND_32BITS_ONES_CNT: number of 1s. DO_FIND_32BITS_ZEROS_CNT number of 0s
    uint32_t bit_con_seq_cnt;     // --''--
    uint32_t bit_round_cnt;       // counts all in 2ˆ32 up to 4294967296-1
 } stats_t;

 typedef struct {
    uint32_t bit_con_seq_cnt_max;
    uint32_t bit_round_cnt;
} con_sec_log_t;

// ===========================================================================================
// xorshift32
// Algorithm "xor" from p. 4 of Marsaglia, "Xorshift RNGs"
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


void init_stats (stats_t &stats, const uint32_t initial_seed) {
    stats.state               = initial_seed; // "state" is filled with "seed", math naming is rather confusing
    stats.bit_con_seq_cnt_max = 0;
    stats.bit_con_seq_cnt     = 0;
    stats.bit_round_cnt       = 0;
} // init_stats

// Local function used in 
// find_max_consecutive_bit31_xorshift32 and 
// find_max_consecutive_allbits_xorshift32


void do_xorshift32_and_stats (stats_t &stats, const uint32_t bitmask) {
    
    // Standard xorshift32 algorithm (Marsaglia triples: 13, 17, 5)
    stats.state ^= stats.state << 13;
    stats.state ^= stats.state >> 17;
    stats.state ^= stats.state << 5;
    
    // In 2's complement, a number is negative if its MSB is 1
    
    #if (DO_CNT == DO_FIND_32BITS_ONES_CNT)
    if ((stats.state bitand bitmask) != 0) {
        // True if bit is 1 
    #elif (DO_CNT == DO_FIND_32BITS_ZEROS_CNT)
    if ((stats.state bitand bitmask) == 0) { 
        // True if bit is 0
    #endif
        // Count consecutive bits that match the criteria
        stats.bit_con_seq_cnt++;
        if (stats.bit_con_seq_cnt > stats.bit_con_seq_cnt_max) { 
            stats.bit_con_seq_cnt_max = stats.bit_con_seq_cnt; // postive bits all go to 32 here!
        } else {}
    } else { // Positive
        stats.bit_con_seq_cnt = 0;
    }           
    stats.bit_round_cnt++; 
} // do_xorshift32_and_stats


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
    do_xorshift32_and_stats (stats, INT_MIN); // Now while-cond does not hit after 1 round

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
                do_xorshift32_and_stats (stats, INT_MIN); // INT_MIN is 0x80000000 is bit31
            } break;
        }          
    } while (stats.state != initial_seed); // Terminates when we complete the full cycle

    // All terminal outputs are now grouped together here
    printf("\n=== Simulation Complete ===\n");
    printf("After %u seconds, total numbers checked:  %llu (2^32 - 1)\n", num_seconds, (unsigned long long)stats.bit_round_cnt);
    printf("Max consecutive negatives found: %u\n", stats.bit_con_seq_cnt_max);
    
    return stats.bit_con_seq_cnt_max;
} // find_max_consecutive_bit31_xorshift32


void init_con_sec_log (con_sec_log_t &con_sec_log) {
    con_sec_log.bit_con_seq_cnt_max = 0;
    con_sec_log.bit_round_cnt       = 0;
}


// Find by brute force the values for "DROP_BIT_CNT_MAX" for all 32 bits. Those for bit0..bit30 are not really needed, this is just for fun.
// That one for bit31 is DROP_BIT_CNT_MAX, but it's already found in find_max_consecutive_bit31_xorshift32.
//
// Loops every (30.51 us) as of _log.txt commited at 10AUg2026 0.946  since 4294967296 (2ˆ32 range) / 131028 secs
// However, pasted this log also here, so it wont't get lost in futire deleted commits:
// 
/* With DO_FIND_32BITS_ONES_CNT (standard up to then)
Starting full state-space simulation with seed 1 in code at 16:22:07 Aug  5 2026. Please wait some 25 hours...
Counting ones (would have been the printput if 0.947)
hours:
1..36 (131028 seconds = 36,39666667 hours, not 25 hours which was from a simpler version)
=== Simulation Complete ===
After 131028 seconds, total numbers checked:  4294967295 (2^32 - 1)
Max consecutive negatives found:
Sorted increasing in "time" and with hex values. 

[19] = 32 into 32 at   67059875	(0x03FF40A3)
[18] = 32 into 32 at   79871304	(0x04C2BD48)
[31] = 32 into 32 at   91727762	(0x0577A792)
 [5] = 32 into 32 at  229497610	(0x0DADDB0A)
[26] = 32 into 32 at  329338273	(0x13A14DA1)
 [0] = 32 into 32 at  570083945	(0x21FACA69)
 [8] = 32 into 32 at  665196542	(0x27A617FE)
[14] = 32 into 32 at  917200618	(0x36AB5EEA)
[16] = 32 into 32 at  921328759	(0x36EA5C77)
[29] = 32 into 32 at  926908272	(0x373F7F70)
[25] = 32 into 32 at 1136896000	(0x43C3A800)
[21] = 32 into 32 at 1182526841	(0x467BED79)
 [3] = 32 into 32 at 1436339208	(0x559CCC08)
 [2] = 32 into 32 at 1665547751	(0x63463DE7)
 [1] = 32 into 32 at 1827454906	(0x6CECBFBA)
 [9] = 32 into 32 at 1965317362	(0x75245CF2)
[30] = 32 into 32 at 2311618314	(0x89C87F0A)
[28] = 32 into 32 at 2686348475	(0xA01E6CBB)
[22] = 32 into 32 at 2695346524	(0xA0A7B95C)
[12] = 32 into 32 at 2696019181	(0xA0B1FCED)
[20] = 32 into 32 at 2945898530	(0xAF96D822)
[13] = 32 into 32 at 3030703402	(0xB4A4DD2A)
[17] = 32 into 32 at 3150364078	(0xBBC6BDAE)
[27] = 32 into 32 at 3345244218	(0xC764603A)
[11] = 32 into 32 at 3632521665	(0xD883E1C1)
[23] = 32 into 32 at 3693418465	(0xDC2517E1)
[24] = 32 into 32 at 3700734019	(0xDC94B843)
[10] = 32 into 32 at 3950232966	(0xEB73C586)
[15] = 32 into 32 at 4177502203	(0xF8FF9FFB)
 [7] = 32 into 32 at 4206662089	(0xFABC91C9)
 [6] = 32 into 32 at 4207409591	(0xFAC7F9B7)
 [4] = 32 into 32 at 4277065801	(0xFEEED849)
*/
uint32_t find_max_consecutive_allbits_xorshift32 
    (const uint32_t initial_seed, // is 1
    port out        p1_out_blue) {
   
    timer    tmr;
    time32_t time_ticks;
    unsigned num_seconds = 0;
    bool     p1_val = false;

    printf("Starting full state-space simulation with seed %u in code at %s %s.\nCounting %s\nPlease wait some 36 hours...\nhours:\n\n", 
        initial_seed, __TIME__, __DATE__,
        (DO_CNT == DO_FIND_32BITS_ONES_CNT)  ? "ones"  :
        (DO_CNT == DO_FIND_32BITS_ZEROS_CNT) ? "zeros" : "?");

    stats_t       stats       [BITSNUM32];
    con_sec_log_t con_sec_log [BITSNUM32];

    for (unsigned ix=0; ix<BITSNUM32; ix++){
       init_stats       (stats[ix], initial_seed);
       init_con_sec_log (con_sec_log[ix]);
    }

    tmr :> time_ticks;
    p1_out_blue <: p1_val;

    for (unsigned ix=0; ix<BITSNUM32; ix++){
       do_xorshift32_and_stats (stats[ix], 1<<ix);
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
                p1_out_blue <: p1_val; // See loop time above
                p1_val = not p1_val;
                for (unsigned ix=0; ix<BITSNUM32; ix++){
                    uint32_t bit_con_seq_cnt_max_pre = stats[ix].bit_con_seq_cnt_max;
                    uint32_t bit_round_cnt_pre       = stats[ix].bit_round_cnt;
                    
                    do_xorshift32_and_stats (stats[ix], 1<<ix);
                    
                    if (stats[ix].bit_con_seq_cnt_max > bit_con_seq_cnt_max_pre) {
                        con_sec_log[ix].bit_con_seq_cnt_max = stats[ix].bit_con_seq_cnt_max; // New
                        con_sec_log[ix].bit_round_cnt       = bit_round_cnt_pre; // The old, not after increment
                    }
                }
            } break;
        }          
    } while (stats[0].state != initial_seed); // Terminates when we complete the full cycle
    // } while (stats[0].bit_round_cnt < 1000); // To test

    // All terminal outputs are now grouped together here
    printf("\n=== Simulation Complete ===\n");
    printf("After %u seconds, total numbers checked:  %llu (2^32 - 1)\n", num_seconds, (unsigned long long)stats[0].bit_round_cnt);
    printf("Max consecutive negatives found:\n");

    for (unsigned ix=0; ix<BITSNUM32; ix++){
        printf ("[%u]=\t%u\tinto\t%u\tat\t%u\n", ix, stats[ix].bit_con_seq_cnt_max, con_sec_log[ix].bit_con_seq_cnt_max, con_sec_log[ix].bit_round_cnt);
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
// is based on random_consts. random_val_max_us as (49.5 ms * MAX_SUM_CNT ) / 2 = 49.5s / 2 = 24.75. However, see typical values below
//
// See https://www.xcore.com/viewtopic.php?t=9317 "Different average random values when hw or sw seed and use of LFSR" on XCore Exchange
// =========================================================================================================================

// Different methods of random_create_generator needed during development phase

random_unsigned32_t random_create_generator (
    const use_random_type_e   use_random_type,
    const random_unsigned32_t random_seed) 
{
    xassert (random_seed != 0);
    random_unsigned32_t random_generator = random_seed; // Some value when not used
    
    switch (use_random_type) {
        case use_lib_random_sw_seed: {
            random_generator = random_create_generator_from_seed (random_seed);
        } break;
            
        case use_lib_random_hw_seed: {
            random_generator = random_create_generator_from_hw_seed (); 
        } break;
            
        case use_lib_random_sw_seed_symmetric: {
            random_generator = random_seed;
        } break;
            
        case use_xorshift32: {
            random_generator = random_seed;  
        } break;
            
        case use_xorshift32_symmetric: {
            random_generator = random_seed; 
        } break;
            
        default: {
            xassert(0); // XMOS_ISSUE_11AUG2026 crashes here with value 5678
        } break;
    }

    return random_generator; // See random_ssgn
} // random_create_generator


// Different methods of random_get_random_number_special needed during development phase
//
random_unsigned32_t random_get_random_number_special (
    const use_random_type_e use_random_type,
    randoms_t               &randoms)
{
    switch (use_random_type) {
        case use_lib_random_sw_seed: {
            random_get_random_number (randoms.random_ssgn); // randoms.random_ssgn old value in and new value out (ignoring return value)
        } break;
            
        case use_lib_random_hw_seed: {
            random_get_random_number (randoms.random_ssgn); 
        } break;
            
        case use_lib_random_sw_seed_symmetric: {
            next_random_number_symmetric (use_random_type, randoms); // Uses random_get_random_number internally. Updates all of randoms because it needs it itself
        } break;
            
        case use_xorshift32: {
            xorshift32 (randoms); // // Updates randoms.random_ssgn only
        } break;
            
        case use_xorshift32_symmetric: {
            next_random_number_symmetric (use_random_type, randoms); // Uses xorshift32 internally. Updates all of randoms because it needs it itself
        } break;
            
        default: {
            xassert(0);
        } break;
    }

    return randoms.random_ssgn;
} // random_get_random_number_special


// Only called at startup of tasks
//
void init_randoms (
    const use_random_type_e   use_random_type,     
    randoms_t                 &randoms,
    const random_unsigned32_t random_seed)
{
    #if (XMOS_ISSUE_11AUG2026 == 1)
        #warning XMOS_ISSUE_11AUG2026 (Ticket # 341285 at XMOS)
        // Both compile:
        randoms.random_ssgn = random_create_generator (use_random_type, random_seed); // Correct
        randoms.random_ssgn = random_create_generator (random_seed, use_random_type); // Compiles and runs with run-time crash on xassert in random_create_generator
    #else
        randoms.random_ssgn = random_create_generator (use_random_type, random_seed); 
    #endif    
    randoms.use_random_negated        = false; 
    randoms.random_ssgn_prev          = randoms.random_ssgn;
    randoms.max_loop_pos_cnt          = 0;
    randoms.max_loop_neg_cnt          = 0;
    randoms.max_loop_neg_cnt_ever     = 0;
} // init_randoms


void init_random_consts (
    random_consts_t           &random_consts,
    const random_unsigned32_t random_val_max_us,
    const random_unsigned32_t timer_factor_knockcome_us) 
{
    random_consts.random_val_max_us         = random_val_max_us;
    random_consts.timer_factor_knockcome_us = timer_factor_knockcome_us;
}


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
void next_random_number_symmetric (
    const use_random_type_e use_random_type,
    randoms_t               &randoms) 

    {
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
            
            if (use_random_type == use_lib_random_sw_seed_symmetric) {
                random_get_random_number (randoms.random_ssgn); // randoms.random_ssgn old value in and new value out (ignoring return value)
            } else if (use_random_type == use_xorshift32_symmetric) {
                xorshift32 (randoms); // Updates randoms.random_ssgn
            } else {
                xassert (false); // One that's not symmetric
            }
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


// ================================================================================================
// get_until_next_timeout_ticks_symmentric to convert from random value as seen as signed to upper 
// and lower half of next_timeout_ticks range
// ==========
// Key Observations from the 73k Iteration Log (Summary done by Google AI)
// XCC 1503.1 KNOCK-COME v0.949 on date Aug 10 2026 21:12:42:
// 
// * Symmetry Validation: 
//   The custom PRG effectively balances the distribution, bringing the total `RND CLK` 
//   mean to 50.036 ms (target: 50.00 ms) over a comprehensive 73,000 transaction cycle.
// 
// * Precision Fix Impact: 
//   Shifting the `XS1_TIMER_MHZ` multiplication ahead of the `/ 2` division successfully 
//   preserved the LSB, recovering a lost 1 us per cycle caused by integer truncation.
// 
// * Time Divergence Solved: 
//   The minor variations in the `TIME` column are mathematically verified as a rounding 
//   byproduct of its 10 ms polling interval, while `RND CLK` represents the absolute 
//   64-bit hardware tick truth.
//  ==========
// Comment about the input param random_number
//   From used generators here, all values except 0, so there is "one less"
//   random_number % random_consts. random_val_max_us = 0 than the others [1..99]. This 
//   same problem also exist on from (2ˆ32)-1 100 upper values (96,97,98,99 are missing) since
//   (2ˆ32)-1 = 4294967295 
//   Examples with random_consts. random_val_max_us 100000 us (100 ms) or 10 us (no overflow problem for any)
//
time32_t get_until_next_timeout_ticks_symmentric (
    const random_unsigned32_t random_number,
    const random_consts_t     random_consts)                            
{ 
    time32_t next_timeout_ticks;                        

    const random_unsigned32_t random_unsigned32_in_range_us = // "[1..(99999+1)]-1 = [0 - 99999]" or "[1..(9+1)]-1 = [0 - 9]"
        (random_number % (random_consts. random_val_max_us + random_consts. timer_factor_knockcome_us)) - 
        random_consts. timer_factor_knockcome_us;  
    
    if ((random_number bitand INT_MIN) == 0) { //   "100000 + 99999                            / 2 = 99999 (99999.5)"
        //                                          "100000 + 76000                            / 2 = 88000"
        //                                          "100000 + 0                                / 2 = 50000"
        //                                                                    "Positive half" is ">= 50000"
        //                                              "10 + 9                                / 2 = 9 (9.5)"
        //                                              "10 + 7                                / 2 = 8 (8.5)"
        //                                              "10 + 0                                / 2 = 5"
        //                                                                    "Positive half" is ">= 5"
        
        // Multiplying by XS1_TIMER_MHZ BEFORE dividing by 2 to prevent any integer truncation error 
        next_timeout_ticks = (time32_t) (((random_consts. random_val_max_us + random_unsigned32_in_range_us) * XS1_TIMER_MHZ) / 2); // Above half
    } else { //                                                               "Negative half" is " < 50000"
        //                                          "100000 - 24000                            / 2 = 38000"
        //                                          "100000 - 99999                            / 2 =     0 (0.5)"
        //                                                                    "Negative half" is " < 5"
        //                                              "10 - 2                                / 2 = 4"
        //                                              "10 - 9                                / 2 = 0 (0.5)"
        
        // Multiplying by XS1_TIMER_MHZ BEFORE dividing by 2 to prevent any integer truncation error 
        next_timeout_ticks = (time32_t) (((random_consts. random_val_max_us - random_unsigned32_in_range_us) * XS1_TIMER_MHZ) / 2); // Below half
    }

    xassert ((next_timeout_ticks bitand INT_MIN) == 0); // Delta is positive, ie. half time32_t range. Overflow or underflow not possible

    return next_timeout_ticks;
} // get_until_next_timeout_ticks_symmentric


time32_t get_until_next_timeout_ticks_rng (
    const random_unsigned32_t random_number,
    const random_consts_t     random_consts)                                  
{ 
    time32_t next_timeout_ticks;                        

    const random_unsigned32_t random_unsigned32_in_range_us = // "[1..(99999+1)]-1 = [0 - 99999]" or "[1..(9+1)]-1 = [0 - 9]"
        (random_number % (random_consts. random_val_max_us + random_consts. timer_factor_knockcome_us)) - 
        random_consts. timer_factor_knockcome_us;                                                                                                  

    next_timeout_ticks = (time32_t) random_unsigned32_in_range_us * XS1_TIMER_MHZ;

    xassert ((next_timeout_ticks bitand INT_MIN) == 0); // Delta is positive, ie. half time32_t range. Overflow or underflow not possible

    return next_timeout_ticks;
} // get_until_next_timeout_ticks_rng


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