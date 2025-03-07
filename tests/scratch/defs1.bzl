def recursive_build(top):
    top_res = {}

    def store_final(nv):
        top_res["FINAL"] = nv

    stack = [(top.build, store_final)]
    for _ in range(10000):
        if not stack:
            break
        f, store = stack.pop()
        f(stack, store)
    print("topres=", top_res)

def Builder(**kwargs):
    self = struct(
        kwargs = {} | kwargs,
        build = lambda *a, **k: _build(self, *a, **k),
    )
    return self

def ListBuilder(*args):
    self = struct(
        values = list(args),
        build = lambda *a, **k: _build_list(self, *a, **k),
    )
    return self

def _build(self, stack, store_result):
    result = {}
    for k, v in self.kwargs.items():
        if hasattr(v, "build"):
            stack.append((v.build, (lambda nv, k = k: _set(result, k, nv))))
        else:
            result[k] = v

    store_result(result)

def _build_list(self, stack, store_result):
    list_result = []
    for v in self.values:
        if hasattr(v, "build"):
            stack.append(v.build, lambda nv: list_result.append(nv))
        else:
            list_result.append(v)
    store_result(list_result)

def _set(o, k, v):
    o[k] = v

def defs1():
    top = Builder(
        a = Builder(
            a1 = True,
        ),
        b = Builder(
            b1 = 2,
            b2 = ListBuilder(1, 2, 3),
        ),
    )

    todo = []
    recursive_build(top)
