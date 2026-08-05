/*
 * my_print.h
 *
 *  Created on: 05. august 2026
 *      Author: oyvindteig
 */

#pragma once

typedef enum {
    scale_unity            = 1,
    scale_ten              = 10,
    scale_hundred          = 100,
    scale_thousand         = 1000,
    scale_ten_thousand     = 10000,
    scale_hundred_thousand = 100000
} scale_factor_t;


int get_trailing_zeros (const scale_factor_t num);

inline int get_integer_part (const unsigned value, const unsigned divisor);

inline int get_fraction_part (const unsigned value, const unsigned modulus);