def parse_common_args(parser):
    parser.add_argument(
        "--repo",
        action="store",
        required=True,
        help="The external repo name to install dependencies. In the format '@{REPO_NAME}'",
    )
    parser.add_argument(
        "--extra_pip_args", action="store", help="Extra arguments to pass down to pip.",
    )
    parser.add_argument(
        "--pip_data_exclude",
        action="store",
        help="Additional data exclusion parameters to add to the pip packages BUILD file.",
    )
    parser.add_argument(
        "--enable_implicit_namespace_pkgs",
        action="store_true",
        help="Disables conversion of implicit namespace packages into pkg-util style packages.",
    )
    return parser
