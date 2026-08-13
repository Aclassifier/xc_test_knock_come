/*
 * my_numbers.xc
 *
 *  Created on: 05 August 2026
 *      Author: oyvindteig
 */

#define INCLUDES
#ifdef INCLUDES
    #include <xassert.h>
    #include "__globals.h" // false etc.
    #include "my_numbers.h"
#endif


// Returns log10(num) or number of trailing zeroes
//
int get_trailing_zeros (const scale_factor_t num) 
{
    switch (num) {
        case scale_unity:            return 0;
        case scale_ten:              return 1;
        case scale_hundred:          return 2;
        case scale_thousand:         return 3;
        case scale_ten_thousand:     return 4;
        case scale_hundred_thousand: return 5;
         // If larger required then make a loop to count the number of trailing zeroes for the general case
        default: {
            xassert(false); // If looped then remove this
        } break;
    }

    return 0; // // ..compiler requires this even if xassert never returns
} // get_trailing_zeros


extern inline int get_integer_part (const unsigned value, const unsigned divisor) 
{
    return ((int) (value / divisor));
} // get_integer_part


extern inline int get_fraction_part (const unsigned value, const unsigned modulus) 
{
    return ((int) (value % modulus)); 
} // get_fraction_part