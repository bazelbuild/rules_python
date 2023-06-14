def convert_installation_reports_to_intermediate(repository_ctx, installation_reports):
    intermediate = {}

    for report_label, config_setting in installation_reports.items():
        report = json.decode(repository_ctx.read(report_label))
        for install in report["install"]:
            download_info = install["download_info"]
            metadata = install["metadata"]
            name = metadata["name"]

            info = intermediate.setdefault(name, {}).setdefault(config_setting, {})
            info["url"] = download_info["url"]
            hash = download_info["archive_info"].get("hash", "")
            if hash and hash.startswith("sha256="):
                info["sha256"] = hash.split("=", 1)[1]
            else:
                fail("unknown integrity check: " + str(download_info["archive_info"]))

    return intermediate

def generate_pypi_package_load(repository_ctx):
    lines = [
        """load("@rules_python//python:pypi.bzl", _load_pypi_packages_internal="load_pypi_packages_internal")""",
        """load("@{}//:intermediate.bzl", "INTERMEDIATE")""".format(repository_ctx.name),
        """def load_pypi_packages(**kwargs):""",
        """    _load_pypi_packages_internal(INTERMEDIATE, **kwargs)""",
    ]
    repository_ctx.file("packages.bzl", "\n".join(lines), executable=False)

