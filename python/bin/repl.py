import code
import os
from pathlib import Path

# Manually implement PYTHONSTARTUP support. We can't just invoke the python
# binary directly as it would skip the bootstrap scripts.
python_startup = os.getenv("PYTHONSTARTUP")
if python_startup:
    try:
        source = Path(python_startup).read_text()
    except Exception as error:
        print(f"{type(error).__name__}: {error}")
    else:
        compiled_code = compile(source, filename=python_startup, mode="exec")
        eval(compiled_code, {})

code.InteractiveConsole().interact()
