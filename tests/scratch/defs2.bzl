def AttrBuilder(values):
    return struct(
        values = values,
    )

def Attr(builder_factory):
    return struct(
        built = builder_factory(),
        to_builder = lambda: builder_factory(),
    )

NEW_THING_BUILDER = lambda: AttrBuilder(values = ["asdf"])
THING = Attr(NEW_THING_BUILDER)

D = {"x": None}
