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
#define LIB_RANDOM_SW_SEED                 0 // see XMOS Ticket 339260
#define LIB_RANDOM_HW_SEED                 1 // --''--
#define LIB_RANDOM_SW_SEED_LOCAL_SYMMETRIC 2 // --''-- Creates every other positive and negative value
#define LOCAL_XORSHIFT32                   3 // Creates unique values with xorshift32
#define LOCAL_XORSHIFT32_SYMMETRIC         4 // --''-- Creates every other positive and negative value with xorshift32
//
#define USE_RANDOM_TYPE LOCAL_XORSHIFT32_SYMMETRIC

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
    random_generator_t  random_ssgn;        // random (s)seed (s)state (g)generator (n)number. random_generator_t is unsigned in random.h
    random_unsigned32_t random_ssgn_prev;   // When a negative is slided in between the next _to_ the generator must be the last _from_ it
                                            // Used only for LIB_RANDOM_SW_SEED_LOCAL_SYMMETRIC and LOCAL_XORSHIFT32_SYMMETRIC
    bool                use_random_negated; // Only for LIB_RANDOM_SW_SEED_LOCAL_SYMMETRIC
    unsigned            max_loop_pos_cnt;   // debug --''--
    unsigned            max_loop_neg_cnt;   // debug --''--
} randoms_t;
//
#define DROP_NEG_CNT_MAX 25 // 20 seen. Is 31 correct (N-1)? See below.
//
// The problems here are:
//   1. If the unsigned return value from (*) is treated as a 2’s complement signed, what is the longest sequence of repeating negative values?
//   2. Is this dependent on the initial seed?
//   3. Is it possible to calculate this, or is it an NP-complete problem?
// 
// (*) xorshift32               if LOCAL_XORSHIFT32_SYMMETRIC,
//     random_get_random_number if LIB_RANDOM_SW_SEED_LOCAL_SYMMETRIC (from XMOS lib_random).
//     For other values of USE_RANDOM_TYPE the questions are not relevant
//
// Here is a Google AI answer:
// Design Notes & Bounds:
// 1. If the unsigned return value is cast to a 2's complement signed integer, 
//    what is the longest sequence of consecutive negative values?
//    - For xorshift32, this is mathematically bounded to a maximum of 31.
//    - For lib_random, it depends on the underlying LCG/CRC implementation.
// 2. Seed dependency: For xorshift32, the max run is identical for all non-zero seeds 
//    due to its maximal-length cycle properties.
// 3. Tractability: This is a linear algebra problem over finite fields (not NP-complete) 
//    and can be deterministically calculated/proven.

random_unsigned32_t xorshift32 (randoms_t &randoms);

random_unsigned32_t random_create_generator (const random_unsigned32_t random_seed);

random_unsigned32_t random_get_random_number_special (randoms_t &randoms);

void init_randoms (
    randoms_t                 &randoms,
    const random_unsigned32_t random_seed);

void next_symmetric_random_get_random_number (randoms_t &randoms);

int lib_random_example();