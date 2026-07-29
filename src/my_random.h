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
#define DROP_NEG_CNT_MAX 25 // 20 seen

random_unsigned32_t xorshift32 (randoms_t &randoms);

random_unsigned32_t random_create_generator (const random_unsigned32_t random_seed);

random_unsigned32_t random_get_random_number_special (randoms_t &randoms);

void init_randoms (
    randoms_t                 &randoms,
    const random_unsigned32_t random_seed);

void next_symmetric_random_get_random_number (randoms_t &randoms);

int lib_random_example();