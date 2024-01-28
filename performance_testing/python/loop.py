from stack import Stack
# from queue122 import Queue
# from deque import Deque
import re
import doctest

# uncomment the following line if you have problems with strange characters
# import os
# os.environ['TERM'] = 'linux' # Suppress ^[[?1034h


# -------------- IMPORTANT NOTE -------------------------------
# OP_PREC is handy for checking if a token is an operand
# ie, if token not in OP_PREC then it is an operand
OP_PREC = {"(": 1,
           "+": 2,
           "-": 2,
           "*": 3,
           "/": 3,
           "^": 4,
           ")": 5}


def tokens_from_string(expression):
    """
    Split postfix string into tokens.
    Tokens should be integer values.
    Returns a list of tokens, as strings.
    For example:
    '12 34 +' => ['12', '34', '+']
    '2 + 3 * 4' => ['2', '+', '3', '*', '4']
    Don't worry about how this works
    """
    token_list = re.findall(r'(\d+|[a-z]+|\*|\+|\/|\-|\)|\(|\^)', expression)
    return token_list


def calculate(operator, param1, param2):
    """
    Returns the result of a calculation between param1 and param2 using the
    given operator.
    Note: results may be floats...
    Supported operators: *, /, +, -
    NOTE: Including the ^ operator is an optinal extra
          We will use ^ to indicate ** for this exercise

    >>> calculate('*', 2, 3)
    6
    >>> calculate('*', 2.0, 3)
    6.0
    >>> calculate('+', 2, 3)
    5
    >>> calculate('-', 2, 3)
    -1
    """
    if operator == '*':
        return param1 * param2
    elif operator == '/':
        return param1 / param2
    elif operator == '+':
        return param1 + param2
    elif operator == '-':
        return param1 - param2
    elif operator == '^':
        return param1 ** param2
    else:
        raise Exception(operator + " is an invalid operator!")


def evaluate_postfix(expression):
    """
    Evaluates an expression in postfix notation.
    The expression is provided as a string with spaces between tokens, eg,
    '4 + 5 * 6'

    Operands in the given expression must be integers (this make parsing easier).
    But, you should convert operands to floats before pushing onto the stack.

    You can use the following to check if a token is an operator
         if token in OP_PREC:
    sure it will match ( or ) but postfix expressions don't have these :)

    IMPORTANT NOTE:
    Make sure you operate on operands in the right order
    For example:  3 2 -   should be 3 - 2, not 2 - 3

    >>> evaluate_postfix('2 3 +')
    5.0
    >>> evaluate_postfix('2 3 4 * +')
    14.0
    >>> evaluate_postfix('12 3 4 * +')
    24.0
    >>> evaluate_postfix('2 3 + 4 *')
    20.0
    >>> evaluate_postfix('2 3 2 * + 5 -')
    3.0
    >>> evaluate_postfix('2 3 + 2 5 - *')
    -15.0
    >>> evaluate_postfix('2 3 + 5 2 / *')
    12.5
    >>> evaluate_postfix('2 3 4 8 + * + 1 + 4 * 5 -')
    151.0
    """
    # Code to evaluate the postfix expression and return the result goes here
    # NOTE: Convert operands to floats before pushing onto the stack
    tokens = tokens_from_string(expression)
    # ---start student section---
    s = Stack()
    for token in tokens:
        if token in OP_PREC:
            popped = s.pop()
            s.push(calculate(token, s.pop(), popped))
            continue
        s.push(float(token))
    return s.pop()

    # ===end student section===


def infix_to_postfix(infix_expression):
    """
    Converts an infix expression to a postfix expression.
    Operands in the given expression must be integers.

    >>> infix_to_postfix('2 + 3')
    '2 3 +'
    >>> infix_to_postfix('12 + 34')
    '12 34 +'
    >>> infix_to_postfix('2 + 3 * 4')
    '2 3 4 * +'
    >>> infix_to_postfix('(2 + 3) * 4')
    '2 3 + 4 *'
    >>> infix_to_postfix('2 + 3 * 2 - 5')
    '2 3 2 * + 5 -'
    >>> infix_to_postfix('(2 + 3) * (2 - 5)')
    '2 3 + 2 5 - *'
    >>> infix_to_postfix('(2 + 3) * (5 / 2)')
    '2 3 + 5 2 / *'
    >>> infix_to_postfix('2 + 3 * 4 / (6 - 4) + 1')
    '2 3 4 * 6 4 - / + 1 +'
    """
    # Code to process tokens and return the postfix string goes here
    # Hint: if token not in OP_PREC then it is an operand
    tokens = tokens_from_string(infix_expression)
    # ---start student section---
    output = []
    s = Stack()
    for token in tokens:
        if token == '(':
            s.push(token)
            continue
        if token == ')':
            while s.peek() != '(':
                output.append(s.pop())
            s.pop()
            continue
        if token in OP_PREC:
            while s.peek() in OP_PREC and OP_PREC[s.peek()] >= OP_PREC[token]:
                output.append(s.pop())
            s.push(token)
            continue
        output.append(token)
    for _ in range(len(s)):
        output.append(s.pop())
    return " ".join(output)
    # ===end student section===


def evaluate_infix(infix_expression):
    """
    Evaluates an infix expression.
    Operands in the given expression must be integers.

    >>> evaluate_infix('2 + 3 * 4')
    14.0
    >>> evaluate_infix('2 + (3 * 4)')
    14.0
    >>> evaluate_infix('(2 + 3) * 4')
    20.0
    >>> evaluate_infix('2 + 3 * 2 - 5')
    3.0
    >>> evaluate_infix('(2 + 3) * (2 - 5)')
    -15.0
    >>> evaluate_infix('(2 + 3) * (5 / 2)')
    12.5
    """

    # Code to process tokens and evaluate the infix expression
    # See the Extras section of the handout.
    # As an extra exercise students can write code here that
    # evaluates infix directly (ie without converting to postfix first).
    tokens = tokens_from_string(infix_expression)
    # ---start student section---
    pass
    # ===end student section===


def evaluate_prefix(prefix_expression):
    """
    Evaluates a prefix expression directly, using a Deque.
    Operands must be integers and are initialy cast as ints.

    NOTE: Intermediate values may be floats (eg, 3/4 gives 0.75)
    so don't cast anything to int after the input phase.

    >>> evaluate_prefix('+ 2 4')
    6.0
    >>> evaluate_prefix('+ 2 * 4 3')
    14.0
    >>> evaluate_prefix('* + 2 * 1 2 8')
    32.0
    >>> evaluate_prefix('* - + 2 1 2 8')
    8.0
    >>> evaluate_prefix('+ / 8 - 6 2 4')
    6.0
    """

    # Split prefix string into tokens.
    tokens = tokens_from_string(prefix_expression)

    # add everything to a queue
    dq = Deque()
    for token in tokens:
        if token not in OP_PREC:
            # is a number so convert to a float
            token = float(token)
        dq.enqueue_rear(token)

    # etc
    # etc
    # etc
    # etc...
    # feel free to do this:)
    # and write some doctests to test that it works...


def prefix_to_postfix(prefix_expression):
    """Converts a prefix expression to postfix
    >>> prefix_to_postfix('* - a b c')
    'a b - c *'
    >>> prefix_to_postfix('* - a - b c d')
    'a b c - - d *'
    """
    tokens = tokens_from_string(prefix_expression)
    output = ''
    stack = Stack()
    # Complete this function for extra fun :)
    # ---start student section---
    pass
    # ===end student section===


if __name__ == '__main__':
    import time
    input_string = "100+2/10+1+1+1+1+1+1+1+1+1+1+1+2+2^1"
    loop_amount = 100_000
    loops = loop_amount

    start_time = time.perf_counter_ns()
    while (loops > 0):
        loops -= 1
        evaluate_postfix(infix_to_postfix(input_string))
    end_time = time.perf_counter_ns()
    time = end_time - start_time

    print(f"Python: Runs: {loop_amount}, Time: {time / 1_000_000_000}s, Average Time per run: {time / loop_amount / 1_000}ms")

    # Uncomment the call to testmod to run the tests
    # Can enter an infinite loop if your Stack isn't implemented correctly
    # doctest.testmod()

    # Or you can test each thing separately
    # doctest.run_docstring_examples(calculate, None)
    # doctest.run_docstring_examples(evaluate_postfix, None)
    # doctest.run_docstring_examples(infix_to_postfix, None)
    # doctest.run_docstring_examples(evaluate_infix, None)
    # doctest.run_docstring_examples(evaluate_prefix, None)


