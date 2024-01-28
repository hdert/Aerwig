#include <stdio.h>
#include <math.h>
#include <string.h>
#include <ctype.h>
#include "Stack.h"
#include "CalculatorLib.h"

bool validate_input(char *buffer, unsigned long bufferSize)
{
    bool isOperator = true;
    bool isFloat = false;
    // Start true to see if the user starts with an operator
    int paren_counter = 0;
    for (unsigned long i = 0; i < bufferSize; i++)
    {
        /* Check that character is a number, operator or space,
        and that operators are not consecutive. */
        switch (buffer[i])
        {
        case ' ':
            continue;
        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
        case 'a':
            isOperator = false;
            continue;
        case '.':
            if (isFloat)
            {
                printf("You cannot have more than one period in a floating point number!\n");
                return false;
            }
            isFloat = true;
            isOperator = false;
            continue;
        case LEFT_PAREN:
            isOperator = true;
            isFloat = false;
            paren_counter++;
            continue;
        case RIGHT_PAREN:
            isFloat = false;
            if (isOperator)
            {
                printf("You cannot end a paren with an operator!\n");
                return false;
            }
            paren_counter--;
            if (paren_counter < 0)
            {
                printf("Mismatched parentheses!\n");
                return false;
            }
            continue;
        case '\n':
        case '\r':
            buffer[i] = '\000';
            buffer[i + 1] = '\000';
            i = bufferSize;
            // Stops the for loop, i isn't referenced after this so is fine.
            continue;
        }
        // Check that operators aren't repeated
        if (isOperator)
        {
            printf("You can't enter sequential operators!\n");
            return false;
        }
        // Check if it is a valid operator
        if (!operator_precedence(buffer[i]))
        {
            printf("You have entered an invalid operator!\n");
            return false;
        }
        isOperator = true;
        isFloat = false;
        // Break triggers this which upholds that the start of
        // equation this should be set to true
    }
    // Check the input doesn't finish with an operator
    if (isOperator)
    {
        printf("You cannot finish with an operator!\n");
        return false;
    }
    return true;
}

void get_input_validate(char *buffer, unsigned long bufferSize)
{
    do
    {
        memset(buffer, 0, bufferSize);
        // Clear for if the user fails the first time
        printf("Enter your equation: ");
        fgets(buffer, (int)bufferSize, stdin);
    } while (!validate_input(buffer, bufferSize));
}

int operator_precedence(char operator_char)
{
    switch (operator_char)
    {
    case (LEFT_PAREN):
        return 1;
    case (ADDITION):
        return 2;
    case (SUBTRACTION):
        return 2;
    case (MULTIPLICATION):
        return 3;
    case (DIVISION):
        return 3;
    case (MODULUS):
        return 3;
    case (EXPONENTIATION):
        return 4;
    case (RIGHT_PAREN):
        return 5;
    default:
        return 0;
    }
}

static bool add_operator_to_stack(Stack *STACK, char operator, char * output, unsigned long *outputCounter, int outputSize)
{
    while (STACK->length > 0 && operator_precedence((char)Stack_peek(*STACK)) >= operator_precedence(operator) && *outputCounter < outputSize)
    {
        output[(*outputCounter)++] = ' ';
        output[(*outputCounter)++] = (char)Stack_pop(STACK);
    }
    output[(*outputCounter)++] = ' ';
    if (!Stack_push(STACK, operator))
    {
        Stack_free(STACK);
        return false;
    }
    return true;
}

bool infix_to_postfix(char *input, unsigned long inputSize, char *output, unsigned long outputSize)
{
    memset(output, 0, outputSize);
    Stack STACK = {};
    if (!Stack_init(&STACK))
    {
        return false;
    }
    bool isNumber = false;
    bool wasNumber = false;
    unsigned long outputCounter = 0;
    for (unsigned long i = 0; i < inputSize && outputCounter < outputSize; i++)
    {
        // This switch statement is supposedly for performance reasons, over a bunch of if statements.
        // The empty cases run the case code afterwards, so all numbers trigger the code in case 9.
        switch (input[i])
        {
        case '\000':
            i = inputSize;
            continue;
        case ' ':
            wasNumber = isNumber;
            continue;
        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
        case '.':
            if (wasNumber)
            {
                wasNumber = false;
                if (!add_operator_to_stack(&STACK, MULTIPLICATION, output, &outputCounter, outputSize))
                {
                    return false;
                }
            }
            isNumber = true;
            output[outputCounter++] = input[i];
            continue;
        case 'a':
            if (isNumber)
            {
                if (!add_operator_to_stack(&STACK, MULTIPLICATION, output, &outputCounter, outputSize))
                {
                    return false;
                }
            }
            output[outputCounter++] = input[i];
            isNumber = true;
            wasNumber = true;
            continue;
        case LEFT_PAREN:
            if (isNumber)
            {
                isNumber = false;
                wasNumber = false;
                if (!add_operator_to_stack(&STACK, MULTIPLICATION, output, &outputCounter, outputSize))
                {
                    return false;
                }
            }
            if (!Stack_push(&STACK, LEFT_PAREN))
            {
                Stack_free(&STACK);
                return false;
            }
            continue;
        case RIGHT_PAREN:
            wasNumber = true;
            while (Stack_peek(STACK) != LEFT_PAREN && outputCounter < outputSize)
            {
                output[outputCounter++] = ' ';
                output[outputCounter++] = (char)Stack_pop(&STACK);
            }
            Stack_pop(&STACK);
            continue;
        }
        if (!add_operator_to_stack(&STACK, input[i], output, &outputCounter, outputSize))
        {
            return false;
        }
        isNumber = false;
        wasNumber = false;
    }

    while (STACK.length > 0 && outputCounter < outputSize)
    {
        output[outputCounter++] = ' ';
        output[outputCounter++] = (char)Stack_pop(&STACK);
        // strcat(output, (char)Stack_pop(&STACK));
    }
    Stack_free(&STACK); // This always should run (Check early returns)

    if (outputCounter >= outputSize)
    {
        printf("Error (infix_to_postfix): insufficient output buffer size.\n");
        return false;
    }
    return true;
}

bool evaluate(char operator_char, double value_1, double value_2, double *result)
{
    switch (operator_char)
    {
    case ADDITION:
        *result = value_1 + value_2;
        return true;
    case SUBTRACTION:
        *result = value_1 - value_2;
        return true;
    case DIVISION:
        if (value_2 == 0)
        {
            printf("Cannot divide by 0\n");
            return false;
        }
        *result = value_1 / value_2;
        return true;
    case MULTIPLICATION:
        *result = value_1 * value_2;
        return true;
    case EXPONENTIATION:
        *result = pow(value_1, value_2);
        return true;
    case MODULUS:
        if (value_2 == 0)
        {
            printf("Cannot divide by 0\n");
            return false;
        }
        *result = fmod(value_1, value_2);
        return true;
    default:
        printf("That wasn't a valid operator\n");
        return false;
    }
}

bool evaluate_postfix(char *expression, double previousAnswer, double *result)
{
    Stack STACK = {};
    if (!Stack_init(&STACK))
    {
        return false;
    }
    char *token = strtok(expression, " "); // TODO: An array would be better here
    double value;
    while (token != NULL)
    {
        if (operator_precedence(*token))
        {
            value = Stack_pop(&STACK);
            if (!evaluate(*token, Stack_pop(&STACK), value, &value))
            {
                // The condition works because evaluate computes
                // value_1 + value_2 before assigning the
                // result to value, so no weirdness occurs.
                Stack_free(&STACK);
                return false;
            }
            if (!Stack_push(&STACK, value))
            {
                Stack_free(&STACK);
                return false;
            }
        }
        else if (*token == 'a')
        {
            if (!Stack_push(&STACK, previousAnswer))
            {
                Stack_free(&STACK);
                return false;
            }
        }
        else
        {
            sscanf(token, "%lf", &value);
            if (!Stack_push(&STACK, value))
            {
                Stack_free(&STACK);
                return false;
            }
        }
        token = strtok(NULL, " ");
    }
    *result = Stack_pop(&STACK);
    Stack_free(&STACK); // This should always run (Check early returns)
    return true;
}
