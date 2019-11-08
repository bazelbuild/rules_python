rm -rf ./python

pip install -U -r requirements.txt -t ./python -I

# We don't use any of these packages as executables.
rm -rf ./python/bin
