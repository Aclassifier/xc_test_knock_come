// Variables
int nOfActiveReaders = 0;
int nOfWaitingAdders = 0; // This will also count the active adder as waiti
bool activeAdder = false;
int waitingDeleters = 0; // This will also count the active deleter as wait
bool activeDeleter = false;
// Semaphores
Semaphore mutex(1); // Protects access to the variables
Semaphore readerTurnStile(0);
Semaphore adderSlot(0);
Semaphore deleterSlot(0);
readerEntry()
{
    // a reader wants access
    wait(mutex);
    if (nOfActiveReaders == 0)
    {
        // I am the first one! I may need to unlock the turnstile.
        if (waitingDeleters == 0)
            signal(readerTurnstile);
    }
    nOfActiveReaders++;
    signal(mutex);
    wait(readerTurnStile);
    signal(readerTurnStile);
}
readerExit()
{
    // I certainly have been running, so there is no active
    // deleters and we know that the turnstile is open
    wait(mutex);
    nOfActiveReaders--;
    if (nOfActiveReaders == 0)
    {
        // I am the last one! I may have some duties...
        // Close the turnstile (... we know this to be open).
        wait(readerTurnstile);
        // Possibly wake a waiting deleter
        if (nOfWaitingDeleters > 0 and activeAdder == false)
        {
            signal(deleterSlot);
        }
    }
    signal(mutex);
}
adderEntry()
{
    wait(mutex);
    nOfWaitingAdders++;
    if (not activeAdder and waitingDeleters == 0)
    {
        // I may allow myself to run
        activeAdder = true;
        signal(adderSlot);
    }
    signal(mutex);
    wait(adderSlot);
}
adderExit()
{
    wait(mutex);
    nOfWaitingAdders--;
    activeAdder = false;
    // Do the duties
    if (nOfWaitingDeleters > 0)
    {
        // Possibly wake a waiting deleter
        if (nOfActiveReaders == 0)
            signal(deleterSlot);
    }
    else if (nOfWaitingAdders > 0)
    {
        // If not, possibly kickstart any next waiting adder.
        activeAdder = true;
        signal(adderSlot);
    }
    signal(mutex);
}
deleterEntry()
{
    wait(mutex);
    nOfWaitingDeleters++;
    if (not activeDeleter and not activeAdder and nOfActiveReaders == 0)
    {
        // I may allow myself to run
        signal(deleterSlot);
        activeDeleter = true;
    }
    signal(mutex);
    wait(deleterSlot);
}
deleterExit()
{
    // I was running, so nobody else was running.
    wait(mutex);
    nOfWaitingDeleters--;
    if (nOfWaitingDeleters == 0)
    {
        activeDeleter = false;
    }
    else
    {
        signal(deleterSlot);
    }
    signal(mutex);
}

== == == == == == == == == == == ==

class ListGuard
{
    // Local variables
    int nActiveReaders = 0;
    bool adderActive = false;
    bool nDeleterWaiting = 0;
    bool deleterActive = false;
    synchronized readEntry()
    {
        while (nDeleterWaiting > 0)
            wait();
        nActiveReaders++;
    }
    synchronized readExit()
    {
        nActiveReaders--;
        notifyAll();
    }
    synchronized addEntry()
    {
        while (not adderActive and nDeleterWaiting > 0)
            wait();
        adderActiv4e = true;
    }
    synchronized addExit()
    {
        adderActive = false;
        notifyAll();
    }
    synchronized deleteEntry()
    {
        nDeleterWaiting++;
        while (not adderActive and nActiveReaders > 0)
            wait();
        deleterActive = true;
    }
    synchronized deleteExit()
    {
        deleterActive = false;
        nDeleterWaiting--;
        notifyAll();
    }
}

== == == == == == == == == =

protected object ListGuard
{
    int nActiveReaders = 0;
    bool adderActive = false;
    bool nDeleterWaiting = 0;
    bool deleterActive = false;
    entry readEntry() when not deleterActive and deleteEntry’count == 0
    {
        nActiveReaders++;
    }
    procedure readExit()
    {
        nActiveReaders--;
    }
    entry addEntry()
            when not deleterActive and not adderActive and deleteEntry’count == 0
    {
        nAdderActive = true;
    }
    procedure addExit()
    {
        nAdderActive = false;
    }
    entry deleteEntry()
            when not deleterActive and not adderActive and nActiveReaders == 0
    {
        deleterActive = true;
    }
    procedure readExit()
    {
        deleterActive = false;
    }
}