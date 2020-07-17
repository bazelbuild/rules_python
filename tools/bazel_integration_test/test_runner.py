from pathlib import Path
import json
import os
import platform
from subprocess import Popen
import sys

from rules_python.python.runfiles import runfiles

def main(conf_file):
    with open(conf_file) as j:
        config = json.load(j)
    r = runfiles.Create()

    isWindows = platform.system() == 'Windows'
    bazelBinary = r.Rlocation(os.path.join(config['bazelBinaryWorkspace'], 'bazel.exe' if isWindows else 'bazel'))
    
    workspacePath = config['workspaceRoot']
    # Canonicalize bazel external/some_repo/foo
    if workspacePath.startswith('external/'):
        workspacePath = '..' + workspacePath[len('external'):]

    for command in config['bazelCommands']:
        bazel_args = command.split(' ')
        try:
            doubleHyphenPos = bazel_args.index('--')
            print("patch that in ", doubleHyphenPos)
        except ValueError:
            pass


        # Bazel's wrapper script needs this or you get 
        # 2020/07/13 21:58:11 could not get the user's cache directory: $HOME is not defined
        os.environ['HOME'] = str(Path.home())

        bazel_args.insert(0, bazelBinary)
        bazel_process = Popen(bazel_args, cwd = workspacePath)
        bazel_process.wait()
        if bazel_process.returncode != 0:
            # Test failure in Bazel is exit 3
            # https://github.com/bazelbuild/bazel/blob/486206012a664ecb20bdb196a681efc9a9825049/src/main/java/com/google/devtools/build/lib/util/ExitCode.java#L44
            sys.exit(3)

if __name__ == '__main__':
  main(sys.argv[1])
