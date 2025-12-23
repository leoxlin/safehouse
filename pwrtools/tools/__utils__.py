import sys

def stdin():
    for inp in sys.stdin:
        line = inp.rstrip('\n')
        if not line:
            continue
        yield line
