def convert_installation_reports_to_intermediate(repository_ctx, installation_reports):
    result = {}

    for report_label, config_setting in installation_reports.items():
        report = json.decode(repository_ctx.read(report_label))
        for install in report["install"]:
            download_info = install["download_info"]
            metadata = install["metadata"]
            name = metadata["name"]

            info = result.setdefault(name, {}).setdefault(config_setting, {})
            info["url"] = download_info["url"]
            hash = download_info["archive_info"].get("hash", "")
            if hash and hash.startswith("sha256="):
                info["sha256"] = hash.split("=", 1)[1]

    return result
