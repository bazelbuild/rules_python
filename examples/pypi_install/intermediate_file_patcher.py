import json
import sys
from pathlib import Path

UPDATES = {
    "requests": {
        "patches": [
            "@//third_party:requests/hello.patch",
        ],
        "patch_args": [
            "-p1",
        ],
        "patch_dir": "library/site-packages",
    },
}

def patch_intermediate_file(content):
    for package, info_per_config in content.items():
        for config, info in info_per_config.items():
            if package in UPDATES:
                info.update(UPDATES[package])

def main(argv):
    intermediate_file = Path(argv[1])

    with intermediate_file.open("r") as file:
        content = json.load(file)

    patch_intermediate_file(content)

    with intermediate_file.open("w") as file:
        json.dump(content, file, indent=4)
        file.write("\n")

if __name__ == "__main__":
    sys.exit(main(sys.argv))
