#pragma once
#ifndef NOT_CODE_FOLD
#define NOT_CODE_FOLD 0 // Always 0, for VS Code "folding", not to compile
#endif 

#if NOT_CODE_FOLD // ========== COMMITS OLDER ==========
/*
09Aug2026 0.946
Layout and VS Code explicit "folding". Test with "command K 0" and "command K J"
Also removed conditional compilation in random_get_random_number_special (will do more of the sort)

08Aug2026 0.945
Same code but moved parts around. Now enum, struct, functions etc. grouped and "folding" added "region" and 
"endregion". See def of TEXT_FOLD
05Aug2026 0.944
* Detail in find_max_consecutive_allbits_xorshift32
* DO_FIND_32BITS_DROP_CNT_MAX added index as where changes happen, con_sec_log_t new in my_random.xc
05Aug2026 0.943
Now "0.000" not "0.  0" in prints. Tested. I can test the appearance later with an extended DO_FIND_32BITS_DROP_CNT_MAX
05Aug2026 0.942
print syntax with "%u.%*u", integer, decimals, fraction used. New files: my_numbers.h and my_numbers.xc
Not tested since I want to run 0.941 to see randoms.max_loop_neg_cnt develop over days. Compiles.

04Aug2026 0.941
* non-essential detail
* print_and_clear_debug_cnts and cnts_t much shorter, and perhaps clearer
04Aug2026 0.940
Last long _log.txt. Next version will have considerably less max verbose log

03Aug2026 0.940
print_and_clear_debug_cnts has got caller_id, perhaps the change in DT values comes from the id. See _log.txt
03Aug2026 0.939
* Ref for Claude, to analyse my code, since SPEED_SLOW_AND_PRINT_LESS with less printing did not help with
the small changes. Maybe it's knock-come by itself, since from_10ms_delta_print_10ms and arr_delta_print_10ms counts
the changes caused by both task_slave and task_master
03Aug2026 0.938
* Analysis of the log with Claude Sonnet 5 medium in _log.txt
* All "LOCAL_".. removed. like LIB_RANDOM_SW_SEED_LOCAL_SYMMETRIC -> LIB_RANDOM_SW_SEED_SYMMETRIC
get_until_next_timeout_ticks to convert from random value as seen as signed to upper and lower 
half of next_timeout_ticks range. See _log.txt. New layout of this list, easier to paste into Git changes

02Aug2026 0.937 Just running as DO_KNOCK_COME and XORSHIFT32_SYMMETRIC. print_welcome_banner extended
02Aug2026 0.936 Quite some new names that I hope carry the semantics better, without being extraordinary long.
Like find_max_consecutive_allbits_xorshift32 now (for DO_FIND_32BITS_DROP_CNT_MAX). The result is
that every bit has a max consecutive sequence of DROP_BIT_CNT_MAX = 32 (was DROP_NEG_CNT_MAX)

01Aug2026 0.935 DO_FIND_32BITS_DROP_CNT_MAX is new, and so is find_max_consecutive_allbits_xorshift32 (should take some 25h)

31Jul2026 0.934 Experimenting with DO_FIND_BIT31_DROP_CNT_MAX, see _log.txt

30Jul2026 0.934 max_loop_neg_cnt_ever is new

29Jul2026 0.933 DO_FIND_BIT31_DROP_CNT_MAX is new
29Jul2026 0.932 find_max_consecutive_bit31_xorshift32 by Google AI is new. For DROP_BIT_CNT_MAX (More on the sort)
29Jul2026 0.931 DROP_BIT_CNT_MAX questions stated
29Jul2026 0.931 max_loop_pos_cnt was initialised to 1, should be 0. So now "P 1" as it should in _log.txt
29Jul2026 0.930 DROP_BIT_CNT_MAX 20 -> 25 since 20 seen (tested with 200)
29Jul2026 0.929 Init and symmetric modes hopefulley fixed. Follow random_ssgn_prev

28Jul2026 0.928 XORSHIFT32_SYMMETRIC is new (see _log.txt). APP_COMPILER_FLAGS instead of XCC_FLAGS_DEBUG
28Jul2026 0.927 This file had become messy, moved some into new files __globals.h my_random.h and my_random.xc

27Jul2026 0.926 XORSHIFT32 using xorshift32 creates unique values. See _log.txt.
27Jul2026 0.925.1 Moved /workspace one level down, under a new /xc to /xc/workspace. Quit VS Code and GitHub desktop
first, then after, GitHub desktop "locate" and VS Code just deleting the /build directory fixed everything

26Jul2026 0.925.1 DO_LIB_RANDOM_EXAMPLE is new, testing XMOS lib_random, will be sent to XMOS
XMOS Ticket 339260 "lib_random seems to give repeated pattern"

24Jul2026 0.925 New version naming. USE_ORDERED_PRI_SELECT_SLAVE, USE_ORDERED_PRI_SELECT_MASTER new
Names of tasks and channels more corresponding with Rust code, like task_b_master -> task_master
and PRINT_OR_SCOPE. USE_RANDOM_TYPE=1 compiles and runs but algorithm not verified yet

02Jul2026 0.0.924 next_symmetric_pseudo_random_number -> next_symmetric_random_get_random_number
02Jul2026 0.0.923 next_symmetric_pseudo_random_number is new, but algorithm not verified yet

30Jun2026 0.0.922 typo
30Jun2026 0.0.922 USE_RANDOM_TYPE 0 and 1 new and see _log.txt
30Jun2026 0.0.921 Using random_generator_t from lib_random, but randoms_t not finished
30Jun2026 0.0.920 randoms_t new, not used yet

24Jun2026 0.0.919 Welcome tesxt now "0.0.918" -> "v0.0.919"
24Jun2026 0.0.918 URL til XCore Exchange forum added ().. random ..) and updated _log.txt
24Jun2026 0.0.918 USE_RANDOM_TYPE is new. Observe somewhat different "DT xx.yys" from this!

23Jun2026 0.0.917 Time for each log added, similar to rust_test_knock_come.rs "DT 23.87s"

10Jun2026 0.0.916 Prettier

09Jun2026 0.0.916 Removed three not needed include files
09Jun2026 0.0.916 Prettier code file here 
09Jun2026 0.0.916 Possible to use ports for scope instead of logs.
<syscall.h> introduced since XTC_ExampleXCommonCMake came with it
PRINT_OR_SCOPE is new. TIMER_FACTOR_KNOCKCOME_US is new, to enable fast scope'ing

27May2026 0.0.915 First commit with XTC compiled ok, CMake and CMakeLists.txt

26May2026 0.0.914 Welcome printing different sequence
26May2026 0.0.913 No code change, another XCore Exchange entry referenced. Some empty lines
26May2026 0.0.913 No change of code, more comments
26May2026 0.0.913 This file has been cleaned up with hopefully better comments. 
USE_ORDERED_PRI_SELECT_MASTER is new

25May2026 0.0.912 was committed by GitHub desktop on macOS Tahoe and then
https://github.com/Aclassifier/xc_test_knock_come/tree/master created
Then ChronoSync'ed back to the xTIMEcomposer 2010 mac Mini. No code change

24May2026 0.0.912 URL to blog note updated
Description uodated and some renaming. task_a_master -> task_master

24May2026 0.0.911 print_and_clear_debug_cnts added last > = <
print_welcome_banner is new. Conditional printing done in macros

23May2026 0.0.910 ch_ba_knock -> ch_knock
TEST_DEADLOCK_NO_STREAMING_CHAN is new

21May2026 0.0.900 Initial version
*/
#endif // TEXT_FOLD COMMITS