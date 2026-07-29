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
    #include <stdint.h>
    #include <print.h>
    #include "__globals.h"
    #include "my_random.h"
#endif


// Started from https://en.wikipedia.org/wiki/Xorshift#Example_implementation
//
// For USE_RANDOM_TYPE == LOCAL_XORSHIFT32
//
random_unsigned32_t xorshift32 (randoms_t &randoms) {
	// Algorithm "xor" from p. 4 of Marsaglia, "Xorshift RNGs"
	random_unsigned32_t x = randoms.random_ssgn; 
	x ^= x << 13;
	x ^= x >> 17;
	x ^= x << 5;
    randoms.random_ssgn = x;
	return x; // aliases randoms.random_ssgn
}

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
// would mean 5000/7=715 new random values per second. Ok for the max 100 ms (average 50). For [0..9] we 
// four bits, 5000/4=1250 per second, much too few than the 200000 needed for 5us average. However, since
// the shortest is always 0, a new random value would have to be there immediately, which completely
// outrules the ring oscillator solution. 
//
// Since update_fairness_cnts is called in task_master the theoretical values of "DT xx.yys" in the log
// is based on RANDOM_VAL_MAX_US as (49.5 ms * MAX_SUM_CNT ) / 2 = 49.5s / 2 = 24.75. However, see typical values below
//
// See https://www.xcore.com/viewtopic.php?t=9317 "Different average random values when hw or sw seed and use of LFSR" on XCore Exchange

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
    #endif

    return randoms.random_ssgn;
} // random_get_random_number_special


// 0.029 hopefully ok now
void init_randoms (
    randoms_t                 &randoms,
    const random_unsigned32_t random_seed) {

    randoms.random_ssgn = random_create_generator (random_seed); 
    
    randoms.use_random_negated = false; 
    randoms.random_ssgn_prev   = randoms.random_ssgn;
    randoms.max_loop_pos_cnt   = 0;
    randoms.max_loop_neg_cnt   = 0;
} // init_randoms


// Algorithm invented by me, Øyvind Teig in June 2026
// Not yet tested. For every even number of pseudorandom values asked for,
// the mean value will be half the value of the UINT_MAX range
//
// For USE_RANDOM_TYPE == LIB_RANDOM_SW_SEED_LOCAL_SYMMETRIC
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
        unsigned max_loop_pos_cnt    = 1;
        unsigned max_loop_neg_cnt    = 0;

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
                xassert (false); 
            #endif
            if (randoms.random_ssgn < (UINT_MAX/2)) {
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
                } else {}
                xassert (randoms.max_loop_neg_cnt <= DROP_NEG_CNT_MAX);
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
    // ERROR?
    // With 256 there is a repetion every 33th, like for this run (comma and newline added by me). Only one run needed since software seed
    // 3375822939, 2150272105, 303195149, 3382463290, 2172644011, 280537481, 3435778098, 2345983163, 99534249, 3865380978, 3733810235, 2942149801, 1291597197, 1950410810, 87642964, 3888784776,
    // 3721607119, 2850100033, 1099258461, 1857173402, 819784724, 2348899080, 172346063, 4180874942, 3760279971, 3523600281, 3058484205, 2128542469, 268793130, 3451021684, 2300816951, 8369,
    // 3988308546,

    printstr("\n= bytes =\n");
    // Create a generator with a hardware seed
    random_generator_t rg_hw = random_create_generator_from_hw_seed();

    // Generate a set of random bytes and print them
    uint8_t rand_buf[RAND_BUF_LEN];
    random_get_random_bytes(rg_hw, rand_buf, RAND_BUF_LEN); // was &rg_sw (C-code)

    for (int idx = 0; idx < RAND_BUF_LEN; ++idx) {
        printuintln(rand_buf[idx]);
    }
    // ERROR?
    // With 256 there is a repetion every 33th, like for these two runs (comma and newline added by me)
    // 251, 41, 141, 58, 171, 137, 50, 187, 169, 114, 59, 169, 141, 58, 84, 136,
    // 48, 191, 161, 157, 229, 21, 245, 202, 75, 182, 76, 184, 175, 126, 35, 153,
    // 18,
    //
    // 111, 1, 221, 154, 235, 9, 50, 187, 169, 114, 59, 169, 141, 58, 84, 119,
    // 206, 67, 166, 147, 249, 45, 122, 212, 136, 207, 65, 162, 100, 23, 14, 60,
    // 88,
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

    /* Log, pretty-printed with AI
    Running xc_test_knock_come.xe
    26Jul2026 16.21
    = unsigned =
    3375822939  2150272105  303195149   3382463290  2172644011  280537481   3435778098  2345983163  99534249    3865380978  3733810235  2942149801  1291597197  1950410810  87642964    3888784776  
    3721607119  2850100033  1099258461  1857173402  819784724   2348899080  172346063   4180874942  3760279971  3523600281  3058484205  2128542469  268793130   3451021684  2300816951  8369        
    3988308546  3375822939  2150272105  303195149   3382463290  2172644011  280537481   3435778098  2345983163  99534249    3865380978  3733810235  2942149801  1291597197  1950410810  87642964    
    3888784776  3721607119  2850100033  1099258461  1857173402  819784724   2348899080  172346063   4180874942  3760279971  3523600281  3058484205  2128542469  268793130   3451021684  2300816951  
    8369        3988308546  3375822939  2150272105  303195149   3382463290  2172644011  280537481   3435778098  2345983163  99534249    3865380978  3733810235  2942149801  1291597197  1950410810  
    87642964    3888784776  3721607119  2850100033  1099258461  1857173402  819784724   2348899080  172346063   4180874942  3760279971  3523600281  3058484205  2128542469  268793130   3451021684  
    2300816951  8369        3988308546  3375822939  2150272105  303195149   3382463290  2172644011  280537481   3435778098  2345983163  99534249    3865380978  3733810235  2942149801  1291597197  
    1950410810  87642964    3888784776  3721607119  2850100033  1099258461  1857173402  819784724   2348899080  172346063   4180874942  3760279971  3523600281  3058484205  2128542469  268793130   
    3451021684  2300816951  8369        3988308546  3375822939  2150272105  303195149   3382463290  2172644011  280537481   3435778098  2345983163  99534249    3865380978  3733810235  2942149801  
    1291597197  1950410810  87642964    3888784776  3721607119  2850100033  1099258461  1857173402  819784724   2348899080  172346063   4180874942  3760279971  3523600281  3058484205  2128542469  
    268793130   3451021684  2300816951  8369        3988308546  3375822939  2150272105  303195149   3382463290  2172644011  280537481   3435778098  2345983163  99534249    3865380978  3733810235  
    2942149801  1291597197  1950410810  87642964    3888784776  3721607119  2850100033  1099258461  1857173402  819784724   2348899080  172346063   4180874942  3760279971  3523600281  3058484205  
    2128542469  268793130   3451021684  2300816951  8369        3988308546  3375822939  2150272105  303195149   3382463290  2172644011  280537481   3435778098  2345983163  99534249    3865380978  
    3733810235  2942149801  1291597197  1950410810  87642964    3888784776  3721607119  2850100033  1099258461  1857173402  819784724   2348899080  172346063   4180874942  3760279971  
    = bytes =
    195         89          109         250         43          137         50          187         169         114         59          169         141         58          84          136         
    207         190         163         153         237         5           42          139         201         178         68          87          113         194         164         151         
    14          195         89          109         250         43          137         50          187         169         114         59          169         141         58          84          
    136         207         190         163         153         237         5           42          139         201         178         68          87          113         194         164         
    151         14          195         89          109         250         43          137         50          187         169         114         59          169         141         58          
    84          136         207         190         163         153         237         5           42          139         201         178         68          87          113         194         
    164         151         14          195         89          109         250         43          137         50          187         169         114         59          169         141         
    58          84          136         207         190         163         153         237         5           42          139         201         178         68          87          113         
    194         164         151         14          195         89          109         250         43          137         50          187         169         114         59          169         
    141         58          84          136         207         190         163         153         237         5           42          139         201         178         68          87          
    113         194         164         151         14          195         89          109         250         43          137         50          187         169         114         59          
    169         141         58          84          136         207         190         163         153         237         5           42          139         201         178         68          
    87          113         194         164         151         14          195         89          109         250         43          137         50          187         169         114         
    59          169         141         58          84          136         207         190         163         153         237         5           42          139         201         
    = bits =
    1100100011  
    */

}