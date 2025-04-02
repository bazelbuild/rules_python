import os
from pathlib import Path

def start_repl():
    # Simulate Python's behavior when a valid startup script is defined by the
    # PYTHONSTARTUP variable. If this file path fails to load, print the error
    # and revert to the default behavior.
    if (startup_file := os.getenv("PYTHONSTARTUP")):
        try:
            source_code = Path(startup_file).read_text()
        except Exception as error:
            print(f"{type(error).__name__}: {error}")
        else:
            compiled_code = compile(source_code, filename=startup_file, mode="exec")
            eval(compiled_code, {})

    try:
        # If the user has made ipython available somehow (e.g. via
        # `repl_lib_dep`), then use it.
        import IPython
        IPython.start_ipython()
    except ModuleNotFoundError:
        # Fall back to the default shell.
        import code
        code.interact(local=dict(globals(), **locals()))

if __name__ == "__main__":
    start_repl()
