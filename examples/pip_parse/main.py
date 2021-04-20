import requests
import glob


def version():
    return requests.__version__

def requests_wheels():
    return glob.glob("external/**/*.whl")
