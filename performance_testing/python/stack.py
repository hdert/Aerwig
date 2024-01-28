""" Stacks of fun """
import doctest

# uncomment the following two lines if you have problems with strange characters
# import os
# os.environ['TERM'] = 'linux' # Suppress ^[[?1034h


class Stack(object):
    """Provides a stack with associated stack operations.
    Internally the stack is stored as plain Python list.
    The top of the stack is the last item in _data and the bottom is at _data[0]
    _data is a private variable inside each stack instance and should normally
    only be accessed from methods within the class - although you might want
    to check it directly when you are playing around under the hood.

    >>> s = Stack()
    >>> s.push('a')
    >>> s.peek()
    'a'
    >>> s.pop()
    'a'
    >>> s.push('a')
    >>> s.push('b')
    >>> s.peek()
    'b'
    >>> len(s)
    2
    >>> s.pop()
    'b'
    >>> len(s)
    1
    >>> s.pop()
    'a'
    >>> s.pop()
    Traceback (most recent call last):
    ...
    IndexError: Can't pop from empty stack!
    >>> print(s.peek())
    None
    >>> s.push('a')
    >>> s.push('b')
    >>> s.push('c')
    >>> s.push('a')
    >>> print(s)
    Bottom -> ['a', 'b', 'c', 'a'] <- Top
    >>> s.pop()
    'a'
    >>> print(s)
    Bottom -> ['a', 'b', 'c'] <- Top
    >>> s = Stack() # make s an empty Stack
    >>> s.push(22)
    >>> s.push(29)
    >>> a = s.pop()
    >>> s.push(15)
    >>> s.push(41)
    >>> b = s.pop()
    >>> s.push(23)
    >>> s.push(24)
    >>> s.push(42)
    >>> c = s.pop()
    >>> print(a, b, c)
    29 41 42
    """

    def __init__(self):
        self._data = []

    def push(self, item):
        """Push a new item onto the stack."""
        # ---start student section---
        self._data.append(item)
        # ===end student section===

    def pop(self):
        """ Pop an item off the top of the stack and return it.
        Python has a method to remove and return the last item
        from a list, can you guess what it is?
        Raise IndexError if empty - see comments below.
        """
        if self.is_empty():
            raise IndexError('Can\'t pop from empty stack!')
        else:
            # not empty so write your code to remove the last
            # item from the data list and return it
            # ---start student section---
            return self._data.pop()
            # ===end student section===

    def peek(self):
        """Return the item on the top of the stack, but don't remove it.
        Returns None if the stack is empty
        """
        # ---start student section---
        return None if self.is_empty() else self._data[-1]
        # ===end student section===

    def is_empty(self):
        """ Returns True if empty """
        return len(self._data) == 0

    def __len__(self):
        """ Returns the number of items in the stack """
        return len(self._data)

    def __str__(self):
        """ Returns a nice string representation of the Stack """
        return "Bottom -> " + repr(self._data) + " <- Top"

    def __repr__(self):
        """ Returns a representation, simply the __str__
        This is useful for displaying the Stack in the shell
        """
        return str(self)


if __name__ == '__main__':

    # failed doctests will show you what you need to fix/write
    # If everything works then the doctests will output nothing...
    doctest.testmod()
