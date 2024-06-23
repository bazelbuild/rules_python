"""Extensions for bzlmod."""

load(":repositories.bzl", "uv_register_toolchains")

_DEFAULT_NAME = "uv"

uv_toolchain = tag_class(attrs = {
    "name": attr.string(doc = """\
Base name for generated repositories, allowing more than one uv toolchain to be registered.
Overriding the default is only permitted in the root module.
""", default = "uv"),
    "uv_version": attr.string(doc = "Explicit version of uv.", mandatory = True),
})

def _uv_toolchain_extension(module_ctx):
    registrations = {}
    for mod in module_ctx.modules:
        for toolchain in mod.tags.uv_toolchain:
            if toolchain.name != _DEFAULT_NAME and not mod.is_root:
                fail("""\
                Only the root module may override the default name for the uv toolchain.
                This prevents conflicting registrations in the global namespace of external repos.
                """)
            if toolchain.name not in registrations.keys():
                registrations[toolchain.name] = []
            registrations[toolchain.name].append(toolchain.uv_version)
    for name, versions in registrations.items():
        if len(versions) > 1:
            # TODO: should be semver-aware, using MVS
            selected = sorted(versions, reverse = True)[0]

            # buildifier: disable=print
            print("NOTE: uv toolchain {} has multiple versions {}, selected {}".format(name, versions, selected))
        else:
            selected = versions[0]

        uv_register_toolchains(
            name = name,
            uv_version = selected,
            register = False,
        )

uv = module_extension(
    implementation = _uv_toolchain_extension,
    tag_classes = {"toolchain": uv_toolchain},
)
