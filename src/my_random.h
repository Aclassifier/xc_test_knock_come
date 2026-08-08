/*
 * my_random.h
 *
 *  Created on: 28. July 2026
 *      Author: oyvindteig
 */

 #pragma once

// typedef enum compiles but preprocessor always takes first #if, see
// https://www.teigfam.net/oyvind/home/technology/165-xc-code-examples/#no_enum
//
#define LIB_RANDOM_SW_SEED           0 // see XMOS Ticket 339260
#define LIB_RANDOM_HW_SEED           1 // --''--
#define LIB_RANDOM_SW_SEED_SYMMETRIC 2 // --''-- Creates every other positive and negative value
#define XORSHIFT32                   3 // Creates unique values with xorshift32
#define XORSHIFT32_SYMMETRIC         4 // --''-- Creates every other positive and negative value with xorshift32

#define USE_SYMMETRIC ((USE_RANDOM_TYPE == LIB_RANDOM_SW_SEED_SYMMETRIC) or (USE_RANDOM_TYPE == XORSHIFT32_SYMMETRIC))
//
#define USE_RANDOM_TYPE XORSHIFT32_SYMMETRIC // Observe VS Code colour coding shades non-used code

typedef uint32_t random_unsigned32_t; // uint32_t (random_get_random_number takes unsigned)
typedef int32_t  random_signed32_t;

typedef struct {
    // random_seed (s), random_state (s), random_generator (g) and random_number (n) are often only really three names of the same,
    // thing! You can see an example here, where as used in lib_random file pr_random: 
    //     unsigned random_get_random_number(random_generator_t *g) {
    //         do crc32 on *g; 
    //         return (unsigned) *g;
    //     }
    // The value g aliases the return value. Therefore..
    random_generator_t  random_ssgn;           // random (s)seed (s)state (g)generator (n)number. random_generator_t is unsigned in random.h
    random_unsigned32_t random_ssgn_prev;      // When a negative is slided in between the next _to_ the generator must be the last _from_ it
                                               // Used only for LIB_RANDOM_SW_SEED_SYMMETRIC and XORSHIFT32_SYMMETRIC
    bool                use_random_negated;    // Only for LIB_RANDOM_SW_SEED_SYMMETRIC
    unsigned            max_loop_pos_cnt;      // debug --''--
    unsigned            max_loop_neg_cnt;      // debug --''--
    unsigned            max_loop_neg_cnt_ever; // debug --''--
} randoms_t;
//
#define DROP_BIT_CNT_MAX 32 // 32 for all bits, really. See find_max_consecutive_bit31_xorshift32 or find_max_consecutive_allbits_xorshift32
//
// The problems here are:
//   1. If the unsigned return value from (*) is treated as a 2’s complement signed, what is the longest sequence of repeating negative values?
//   2. Is this dependent on the initial seed?
//   3. Is it possible to calculate this, or is it an NP-complete problem?
// 
// (*) xorshift32               if XORSHIFT32_SYMMETRIC,
//     random_get_random_number if LIB_RANDOM_SW_SEED_SYMMETRIC (from XMOS lib_random).
//     For other values of USE_RANDOM_TYPE the questions are not relevant
//
uint32_t find_max_consecutive_bit31_xorshift32 
    (const uint32_t initial_seed,
    port out        p1_out_blue);

uint32_t find_max_consecutive_allbits_xorshift32 
    (const uint32_t initial_seed,
    port out        p1_out_blue);
//
// Here are some Google AI discussions and answers. Surely open for discussions!
// This was the second after I presssured it on its initial max of 31, which I doubted.
// It generated find_max_consecutive_bit31_xorshift32 to find it. The code is included in my_random.xc. It gave 21.
// When I ran it on the XCORE here, with DO_FIND_BIT31_DROP_CNT_MAX it gave 32§
// The problems here are:
//   1. What is the longest sequence of repeating negative values?
//      -> Exactly 21 consecutive calls max for the standard [13, 17, 5] triple. (Found with find_max_consecutive_bit31_xorshift32)
//      -> (For 64 bits it did matrix calculations and a linear equations matrix to find the value, answer was 64.
//         When I asked about the same maths for 32 bits it answered 32 (instead of the find_max_consecutive_bit31_xorshift32 21)
//         When confronted with it I got "Something went wrong and an AI response wasn't generated.")
//   2. Is this dependent on the initial seed?
//      -> No. Because xorshift32 is a single maximal-length loop, every 
//         non-zero seed will eventually pass through this exact same worst-case run.
//   3. Is it possible to calculate this, or is it an NP-complete problem?
//      -> It is a deterministic state-space boundary problem, fully verified 
//         via cycle simulation to be exactly 21.
//      -> This problem belongs to O(1) (Constant Time) or O(log N) (Logarithmic Time) depending on 
//         how you define the input, but it is definitively in P (Polynomial Time)
//         You mentioned I didn't create a formula, but a formula does exist. Because xorshift32 is a linear transformation 
//         over a Galois field F, its steps can be written as a 32 X 32 binary matrix M. Finding the longest run of a specific 
//         bit is equivalent to finding the properties of the characteristic polynomial of that matrix. Mathematicians can 
//         compute this analytically using matrix exponentiation in O(log N) steps without running the generator at all.

random_unsigned32_t xorshift32 (randoms_t &randoms);

random_unsigned32_t random_create_generator (const random_unsigned32_t random_seed);

random_unsigned32_t random_get_random_number_special (randoms_t &randoms);

void init_randoms (
    randoms_t                 &randoms,
    const random_unsigned32_t random_seed);

void next_symmetric_random_get_random_number (randoms_t &randoms);

int lib_random_example();