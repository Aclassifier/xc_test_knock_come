See the "knock-come" described at https://www.teigfam.net/oyvind/home/technology/009-the-knock-come-deadlock-free-pattern/

The XC language I have blogged some about, see red coloured notes at at https://www.teigfam.net/oyvind/home/technology/098-my-xmos-notes/my-xmos-pages/

This means that this code only runs on the XMOS XCORE architecture.

This code really is an exercise to demonstrate the language and the problems that systems built with tasks that communicate (almost) only over 
synchronous non-buffered channels may encounter if two of those tasks spontanenously decide to send to each other, simultaneously - causing a deadlock.

The "knock-come" pattern solves this with the addition of a data-less asynch channel (instead of a buffer task).

The main XC language description is at XMOS at https://www.xmos.com/file/xmos-programming-guide
