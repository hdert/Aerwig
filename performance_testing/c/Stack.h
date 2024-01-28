#ifndef STACK_H
#define STACK_H

typedef struct Stack
{
    int length;
    int max_length;
    double *data;
} Stack;

void Stack_print(Stack STACK);

bool Stack_push(Stack *STACK, double value);

double Stack_pop(Stack *STACK);

double Stack_peek(Stack STACK);

void Stack_free(Stack *STACK);

bool Stack_init(Stack *STACK);

#endif // STACK_H
