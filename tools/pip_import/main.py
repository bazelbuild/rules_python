import sys
from tools.utils.par_helper import extract_packages

# In case we're running as a PAR archive, extract dependencies
# that aren't happy running as a zipfile.
extract_packages(['certifi'])

# Note: Can only be imported after extract_packages
# fmt:off
from tools.pip_import.pip_import import main
# fmt:on

if __name__ == "__main__":
    sys.exit(main())
