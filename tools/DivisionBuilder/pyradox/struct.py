import pyradox.primitive
import re
import os
import inspect
import copy

class Tree():
    """
    Tree class representing Paradox .txt files.
    Supports most features of OrderedDict and some of ElementTree.
    Keys are stored with case but are matched non-case-sensitive.
    """

    class _Item():
        """
        Internal class to keep track of items.
        pre_comments appear before the item, one per line.
        line_comments appear on the same line as the item.
        """
        def __init__(self, key, value, operator = None, in_group = False, pre_comments = None, line_comment = None):
            self.key = key
            self.value = value

            if pre_comments is None: self.pre_comments = []
            else: self.pre_comments = pre_comments

            self.line_comment = line_comment

            if operator is None: self.operator = '='
            else: self.operator = operator

            self.in_group = in_group

        def prettyprint(self, level, indent_string, include_comments):
            result = ''
            if include_comments:
                for pre_comment in self.pre_comments:
                    result += '%s#%s\n' % (indent_string * level, pre_comment)

            # Output key.
            result += '%s%s %s ' % (indent_string * level, self.key, self.operator)

            # Output value.
            if isinstance(self.value, Tree):
                result += '{\n'
                result += self.value.prettyprint(level + 1, indent_string, include_comments)
                result += indent_string * level + '}'
            else:
                result += pyradox.primitive.make_token_string(self.value)

            if include_comments and self.line_comment is not None:
                result += " #%s" % (self.line_comment)

            result += '\n'

            return result

        def prettyprint_group(self, level, indent_string, include_comments):
            """
            Some trickiness here. Assumes that any indentation for the first line has already been performed.
            If there are no comments, return (value string, False), so following values may be placed on the same line.
            Otherwise, return (string ending in newline, True).
            """
            result = ''
            need_indent = False
            has_pre_comment = False
            if include_comments:
                for pre_comment in self.pre_comments:
                    has_pre_comment = True
                    result += '\n%s#%s' % (indent_string * level, pre_comment)

            if has_pre_comment:
                result += '\n%s' % (indent_string * level)

            # Output value. At current trees are not valid inside groups.
            result += pyradox.primitive.make_token_string(self.value) + ' '

            if include_comments and self.line_comment is not None:
                need_indent = True
                result += "#%s" % (self.line_comment)

            if need_indent:
                result += '\n'

            return result, need_indent


    def __init__(self, iterator = None, end_comments = None):
        """Creates an tree from a key, value iterator if given, or an empty tree otherwise."""
        if iterator is None:
            self._data = []
        else:
            self._data = [Tree._Item(key, value) for (key, value) in iterator]

        if end_comments is None:
            self.end_comments = []
        else:
            self.end_comments = end_comments

    # iterator methods
    def keys(self):
        """Iterator over the keys of this tree."""
        for item in self._data: yield item.key

    def values(self):
        """Iterator over the values of this tree."""
        for item in self._data: yield item.value

    def items(self, comments = False):
        """
        Iterator over (key, value) pairs of this tree.
        """
        for item in self._data: yield item.key, item.value

    def item_comments(self):
        """Iterator over (pre_comments, line_comment) in this tree."""
        for item in self._data: yield item.pre_comments, item.line_comment

    def __contains__(self, key):
        """True iff key is in (the top level of) the tree."""
        return self.contains(key)

    def contains(self, key, *args, **kwargs):
        """True iff key is in the tree. recurse = True for recursive."""
        return self.find(key, *args, **kwargs) is not None

    def __iter__(self):
        """Iterator over the keys of this tree."""
        for key in self.keys(): yield key

    def __len__(self):
        """Number of key-value pairs."""
        return len(self._data)

    # read/find methods
    def at(self, i):
        """Return (key, value) by index"""
        item = self._data[i]
        return item.key, item.value

    def key_at(self, i):
        """Return the ith key."""
        return self._data[i].key

    def value_at(self, i):
        """Return the ith value."""
        return self._data[i].value

    def index(self, key, reverse = True):
        """Returns the index of the key. Last by default."""
        it = enumerate(self._data)
        if reverse: it = reversed(it)
        for i, item in it:
            if match(key, item.key): return i
        raise ValueError('Tree does not contain key %s.' % key)

    def count(self, key):
        """Count the number of items with matching key."""
        result = 0
        for i, item in enumerate(self._data):
            if match(key, item.key): result += 1
        return result

    def _find(self, key, *args, **kwargs):
        """Internal single find function. Returns a _Item."""
        it = self._find_all(key, *args, **kwargs)
        result = next(it, None)
        if result is None: raise KeyError('Key %s not found.' % key)
        return result

    def _find_all(self, key, reverse = False, recurse = False):
        """Internal iterative find function. Iterates over _Items."""
        it = self._data
        if reverse: it = reversed(it)
        for item in it:
            if match(key, item.key): yield item
            if recurse and isinstance(item.value, Tree):
                for subitem in item.value._find_all(key, reverse = reverse, recurse = recurse): yield subitem

    def find(self, key, default = None, *args, **kwargs):
        """Return the first or last value corresponding to a key or None if not found"""
        it = self.find_all(key, *args, **kwargs)
        return next(it, default)

    def find_all(self, key, tuple_length = None, *args, **kwargs):
        """Return all values corresponding to a key. If set, tuple_length parameter causes this to yield tuples."""
        if tuple_length is None:
            for item in self._find_all(key, *args, **kwargs):
                yield item.value
        else:
            partial = []
            for item in self._find_all(key, *args, **kwargs):
                partial.append(item.value)
                if len(partial) >= tuple_length:
                    yield tuple(x for x in partial)
                    partial = []

    def __getitem__(self, key):
        """Return the LAST value corresponding to a key or None if not found"""
        return self.find(key, reverse = True)

    # write methods
    def append(self, key, value, **kwargs):
        """Append a new key, value pair"""
        self._data.append(Tree._Item(key, value, **kwargs))

    def insert(self, i, key, value):
        """Insert a new key, value pair at a numeric position"""
        self._data.insert(i, Tree._Item(key, value))

    def __setitem__(self, key, value):
        """Replaces the LAST item with the key if it exists; otherwise appends it"""
        for i, item in reversed(list(enumerate(self._data))):
            if match(key, item.key):
                self._data[i] = Tree._Item(key, value)
                return
        else:
            self.append(key, value)

    def __delitem__(self, key, reverse = True):
        """Delete an item from the tree by key."""
        # TODO: delete all?
        idx = self.index(key, reverse = reverse)
        if idx is not None: del self._data[idx]

    def __iadd__(self, other):
        for item in other._data:
            self._data.append(copy.deepcopy(item))
        return self

    def __add__(self, other):
        result = copy.deepcopy(self)
        result += other
        return result

    # TODO: update

    def weak_update(self, other):
        """
        Copies all items from the other tree whose keys don't already exist in this tree.
        """
        for key, value in other.items():
            if key not in self:
                self.append(key, copy.deepcopy(value))

    def merge_item(self, key, value, merge_levels = 0):
        if key in self and isinstance(self[key], Tree):
            self[key].merge(value, merge_levels)
        else:
            self[key] = copy.deepcopy(value)

    def merge(self, other, merge_levels = 0):
        """
        Recursively merges another tree into this one.
        merge_levels = 0: Same as adding a copy of the other tree onto the end of this one.
        merge_levels > 0: Tree values will be recursively merged for this many levels, at which point it will add a copy as above.
        merge_levels = -1: Fully recursive.
        """
        if merge_levels == 0:
            self += copy.deepcopy(other)
        else:
            for key, value in other.items():
                self.merge_item(key, value, merge_levels - 1)

    # comments

    def get_pre_comments(self, key):
        return self._find(key).pre_comments

    def get_line_comment(self, key):
        return self._find(key).line_comment

    def set_pre_comments(self, key, pre_comments):
        self._find(key).pre_comments = pre_comments

    def set_line_comment(self, key, line_comment):
        self._find(key).line_comment = line_comment

    def get_pre_comments_at(self, i):
        return self._data[i].pre_comments

    def get_line_comment_at(self, i):
        return self._data[i].line_comment

    def set_pre_comments_at(self, i, pre_comments):
        self._data[i].pre_comments = pre_comments

    def set_line_comment_at(self, i, line_comment):
        self._data[i].line_comment = line_comment

    # operator

    def get_operator(self, key):
        return self._find(key).operator

    def set_operator(self, key, operator):
        self._find(key).operator = operator

    def get_operator_at(self, i):
        return self._data[i].operator

    def set_operator_at(self, i, operator):
        self._data[i].operator = operator

    # string output methods
    def __str__(self):
        """Produces a string in the original .txt format."""
        return self.prettyprint(0)

    def prettyprint(self, level = 0, indent_string = '    ', include_comments = True):
        result = ''
        group_key = None # The key corresponding to the current group. None if no group in progress.

        for item in self._data:
            if group_key is not None: # Last item was in a group.
                if item.in_group and match(item.key, group_key) and not isinstance(item.value, Tree):
                    # Continue the previous group.
                    if needs_indent:
                        result += indent_string * (level + 1)
                    group_string, needs_indent = item.prettyprint_group(level = level + 1, indent_string = indent_string, include_comments = include_comments)
                    result += group_string
                    continue
                else:
                    # End the group.
                    group_key = None
                    result += indent_string * level + '}\n'
            if item.in_group and not isinstance(item.value, Tree):
                # Start a group.
                group_key = item.key
                result += '%s%s %s { ' % (indent_string * level, item.key, item.operator)
                group_string, needs_indent = item.prettyprint_group(level = level + 1, indent_string = indent_string, include_comments = include_comments)
                result += group_string
            else:
                result += item.prettyprint(level = level, indent_string = indent_string, include_comments = include_comments)

        # If last item was in a group, close it.
        if group_key is not None:
            result += indent_string * level + '}\n'

        for end_comment in self.end_comments:
            result += '%s#%s\n' % (indent_string * level, end_comment)

        return result

    # other methods
    def at_time(self, time = False, merge_levels = -1):
        """
        Returns a deep copy of this tree with all date blocks at or before the specified date deep copied and promoted to the top and the rest omitted.
        if date is True, use all date blocks.
        if date is False, use no date blocks.
        """
        # cast to date
        if time not in (True, False):
            time = pyradox.primitive.Time(time)

        result = Tree()
        # non-dates
        for item in self._data:
            if not isinstance(item.key, pyradox.primitive.Time):
                result.append(item.key, copy.deepcopy(item.value))

        # dates
        if time is False: return result

        for item in self._data:
            if isinstance(item.key, pyradox.primitive.Time):
                if time is True or item.key <= time:
                    result.merge(item.value, merge_levels = merge_levels)
        return result

def match(x, spec):
    if isinstance(spec, str) and isinstance(x, str): return x.lower() == spec.lower()
    else: return x == spec