#include <stdio.h>
#include <stdlib.h>
#include "Stack.h"

void Stack_print(Stack STACK)
{
    printf("{");
    if (STACK.length > 0)
    {
        printf("%lf", STACK.data[STACK.length - 1]);
    }
    for (int i = STACK.length - 2; i >= 0 && i < STACK.max_length; i--)
    {
        printf(", %lf", STACK.data[i]);
    }
    printf("}");
    // LinkedList_print(*((Head *)&STACK));
}

bool Stack_push(Stack *STACK, double value)
{
    if (STACK->length == STACK->max_length)
    {
        STACK->data = (double *)realloc(STACK->data, sizeof(double) * (STACK->max_length *= 2));
        if (STACK->data == nullptr)
        {
            *STACK = (Stack){};
            return false;
        }
    }
    STACK->data[STACK->length++] = value;
    return true;
}

double Stack_pop(Stack *STACK)
{
    double return_value = STACK->data[--STACK->length];
    STACK->data[STACK->length] = 0;
    return return_value;
}

void Stack_free(Stack *STACK)
{
    // LinkedList_free((Head *)STACK);
    free(STACK->data);
    *STACK = (Stack){};
}

double Stack_peek(Stack STACK)
{
    return STACK.data[STACK.length - 1];
}

#define DEFAULT_ARRAY_SIZE 100
bool Stack_init(Stack *STACK)
{
    double *data = (double *)calloc(DEFAULT_ARRAY_SIZE, sizeof(double));
    if (data == nullptr)
    {
        *STACK = (Stack){};
        return false;
    }
    *STACK = (Stack){0, DEFAULT_ARRAY_SIZE, data};
    return true;
}