def indent(level, line):
    indent = '  ' * level
    return indent + line


def indent_lines(lines, level=1, append=''):
    indent = '  ' * level

    return [
        '\n'.join(indent + x for x in line.split('\n')) + append
        for line in lines
    ]


def indent_text(text, **kwargs):
    return '\n'.join(indent_lines(text.split('\n'), **kwargs))


def identity(x):
    return x


def emit_string(str):
    return '"%s"' % str


def emit_label(workspace, package, target):
    return emit_string('@%s//%s:%s' % (workspace, package, target))


def emit_block(open, close, items, multiline=True, sep=',', **kwargs):
    if multiline and len(items) >= 2:
        items = indent_lines(items, append=sep, level=1)

        return '%s\n%s\n%s' % (open, '\n'.join(items), close)

    return '%s%s%s' % (open, (sep + ' ').join(items), close)


def emit_dict_key_value(key, value, emit_key=emit_string, emit_value=identity):
    return '%s: %s' % (emit_key(key), emit_value(value))


def emit_arg_key_value(key, value, emit_key=identity, emit_value=identity):
    return '%s = %s' % (emit_key(key), emit_value(value))


def emit_dict(dict, multiline=True, **kwargs):
    kvs = [
        emit_dict_key_value(key, value, **kwargs)
        for key, value in dict.items()
    ]

    return emit_block('{', '}', kvs, multiline=multiline)


def emit_list(list, emit_value=identity, multiline=False):
    items = [
        emit_value(str)
        for str in list
    ]

    return emit_block('[', ']', items, multiline=multiline)


def emit_rule(name, attrs, multiline=True, **kwargs):
    kvs = [
        emit_arg_key_value(key, value, **kwargs)
        for key, value in attrs.items()
    ]

    return emit_block('%s(' % name, ')', kvs, multiline=multiline)


def emit_string_list(list, **kwargs):
    return emit_list(list, emit_value=emit_string, **kwargs)


def emit_string_dict(dict, **kwargs):
    return emit_dict(dict, emit_value=emit_string, **kwargs)
