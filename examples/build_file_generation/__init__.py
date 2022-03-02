import requests

def main(url):
    r = requests.get(url)
    print(r.text)
