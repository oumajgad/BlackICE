"""Naming a place in a file by its structure rather than its line number.

`country_event 14883 > option "Give Permission"` stays true while lines are added above
it, which is what lets the baseline recognise a known finding after the file has changed.
"""


def _label(node):
    if node.key is None:
        return "{}"
    label = node.key
    if node.is_block:
        low = node.lkey
        if low in ("country_event", "province_event", "event"):
            ident = node.child("id")
            if ident is not None and ident.value is not None:
                label += " " + ident.value
        elif low == "option":
            name = node.child("name")
            if name is not None and name.value is not None:
                label += ' "%s"' % name.value
    return label


def describe(node):
    """The chain of blocks from the top of the file down to \\p node, inclusive."""
    parts = []
    while node is not None and (node.key is not None or node.parent is not None):
        parts.append(_label(node))
        node = node.parent
    return " > ".join(reversed(parts))


def describe_parent(node):
    return describe(node.parent) if node.parent is not None else ""
