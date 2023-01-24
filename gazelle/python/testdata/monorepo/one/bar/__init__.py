import os

import boto3

_ = boto3


def bar():
    return os.path.abspath(__file__)
