#!/usr/bin/env python3

from contextlib import redirect_stdout
from io import StringIO
import os
import tempfile

tmp = tempfile.NamedTemporaryFile(suffix=".py")
path = os.path.dirname(os.path.abspath(__file__))

with open(tmp.name, 'w') as fd:
    with open(os.path.join(path, "..", "fortran.vim"), 'r') as fi:
        for line in fi.readlines()[1:]:
            if "EOF" in line:
                break
            fd.write(line)
            if "import vim" in line:
                fd.write("from importlib import reload\n")
                fd.write("reload(vim)\n")
    fd.write("\nrun()")

template = """
def eval(c):
    if c == "filename":
        return "{}"
    elif c == "line('.')":
        return {}
    elif c == "pattern":
        return "{}"
def command(c):
    if c == ":mark Z":
        pass
    elif c != "{}":
        raise Exception("Test failed: {}:{} {} {} " + c)
error = Exception
"""

tests = [
    ("test1.f90", 19, "a", ":15"),
    ("test1.f90", 20, "b", ":6"),
    ("test1.f90", 20, "j", ":7"),
    ("test1.f90", 20, "i", ":17"),
    ("test1.f90", 19, "fun", ":26"),
    ("test1.f90", 28, "sub2", ":edit +6 {}/test2.f90".format(path)),
    ("test1.f90", 29, "sub3", ":edit +12 {}/test3.f90".format(path)),
    ("test1.f90", 21, "subb", ":32"),
    ("test1.f90", 33, "subc", ":edit +7 {}/test3.f90".format(path)),
    ("test3.f90", 14, "j", ":edit +7 {}/test1.f90".format(path)),
    ("test2.f90", 8, "y", ":2"),
    ("test1.f90", 3, "mod_test2", ":edit +1 {}/test2.f90".format(path)),
        ]

ok = True

for test in tests:
    with open("vim.py", "w") as fd:
        fd.write(template.format(*(test + test)))

    f = StringIO()
    with redirect_stdout(f):
        exec(open(tmp.name).read())
    s = f.getvalue()
    if "Test failed" in s:
        ok = False
        print(s.strip())

    os.unlink("vim.py")
    with os.scandir("__pycache__") as fs:
        for f in fs:
            os.unlink(f)

if not ok:
    raise Exception("At least one test failed")
