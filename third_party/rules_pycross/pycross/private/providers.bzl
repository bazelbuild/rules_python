"""Pycross providers."""

PycrossWheelInfo = provider(
    doc = "Information about a Python wheel.",
    fields = {
        "name_file": "File: A file containing the canonical name of the wheel.",
        "wheel_file": "File: The wheel file itself.",
    },
)

PycrossTargetEnvironmentInfo = provider(
    doc = "A target environment description.",
    fields = {
        "python_compatible_with": "A list of constraints used to select this platform.",
        "file": "The JSON file containing target environment information.",
    },
)
