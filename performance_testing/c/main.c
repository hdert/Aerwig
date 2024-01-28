#include <stdio.h>
#include "CalculatorLib.h"
#include <time.h>

#define SEC_TO_NS(sec) ((sec) * 1000000000)

unsigned long long int nanos()
{
    struct timespec ts;
    timespec_get(&ts, TIME_UTC);
    unsigned long long int ns = SEC_TO_NS((unsigned long long int)ts.tv_sec) + (unsigned long long int)ts.tv_nsec;
    return ns;
}

int main(void)
{
    char input_string[] = "100+2/10+1+1+1+1+1+1+1+1+1+1+1+2+2^1";
    unsigned int loop_amount = 100000;
    unsigned int loops = loop_amount;
    char buffer[100];
    double result;

    unsigned long long int start_time = nanos();
    while (loops-- > 0)
    {
        if (!validate_input(input_string, sizeof input_string - 1))
            break;
        if (!infix_to_postfix(input_string, sizeof input_string, buffer, sizeof buffer))
            break;
        if (!evaluate_postfix(buffer, 0, &result))
            break;
    }
    unsigned long long int end_time = nanos();
    unsigned long long int time = end_time - start_time;

    printf("Runs: %d, Time: %lfs, Average Time per run: %lfms", loop_amount, (double)time / 1000000000, (double)time / loop_amount / 1000);
}