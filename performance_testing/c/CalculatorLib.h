#ifndef CALCULATORLIB_H
#define CALCULATORLIB_H

typedef enum
{
    ADDITION = '+',
    SUBTRACTION = '-',
    DIVISION = '/',
    // INT_DIVISION = '//',
    MULTIPLICATION = '*',
    EXPONENTIATION = '^',
    // ALT_EXPONENTIATION = '**',
    MODULUS = '%',
    LEFT_PAREN = '(',
    RIGHT_PAREN = ')'
} operators;

// bool check_valid_operator(char operator_char, bool quiet);

bool validate_input(char *buffer, unsigned long bufferSize);

void get_input_validate(char *buffer, unsigned long bufferSize);

bool infix_to_postfix(char *input, unsigned long inputSize, char *output, unsigned long outputSize);

int operator_precedence(char operator_char);

bool evaluate(char operator_char, double value_1, double value_2, double *result);

bool evaluate_postfix(char *expression, double previousAnswer, double *result);

#endif // CALCULATORLIB_H
