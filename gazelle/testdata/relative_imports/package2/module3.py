from . import Class1
from .subpackage1.module5 import function5


def function3():
    c1 = Class1()
    return "function3 " + c1.method1() + " " + function5()
