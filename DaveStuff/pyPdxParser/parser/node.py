from typing import Optional, Any


class Node:
    def __init__(self, key: str):
        self.key: str = key
        self.parent: Optional["Node"] = None
        self.children: list["Node"] = []
        self.scalar_type: Optional[Any] = None
        self.scalar_value: Optional[Any] = None

    def __str__(self):
        return f"{self.key=} {self.scalar_value=}"

    @classmethod
    def from_parsed(cls, parsed: Any, parent: "Node" = None, key: str = "data") -> "Node":
        this_node = cls(key=key)
        this_node.parent = parent
        if isinstance(parsed, dict):
            for k, v in parsed.items():
                if isinstance(v, list):
                    if len(v) == 0:
                        continue
                    if isinstance(v[0], dict) or isinstance(v[0], list):
                        for y in v:
                            child_node = cls.from_parsed(parsed=y, parent=this_node, key=k)
                            this_node.children.append(child_node)
                    else:
                        for y in v:
                            child_node = cls(key=k)
                            child_node.parent = this_node
                            child_node.scalar_type = int
                            child_node.scalar_value = y
                            this_node.children.append(child_node)
                else:
                    child_node = cls.from_parsed(parsed=v, parent=this_node, key=k)
                    this_node.children.append(child_node)
        else:
            this_node.scalar_type = type(parsed)
            this_node.scalar_value = parsed
        return this_node

    def find_by_key(self, key: str) -> Optional[list["Node"]]:
        res = []
        if self.key == key:
            res.append(self)
        if len(self.children) > 0:
            for child in self.children:
                x = child.find_by_key(key=key)
                if x:
                    res.extend(x)
        return res

    def find_by_key_single(self, key: str) -> Optional["Node"]:
        res = self.find_by_key(key)
        if len(res) > 0:
            return res[0]
        return None

    def get_parent_by_key(self, key: str) -> Optional["Node"]:
        if self.parent is not None:
            if self.parent.key == key:
                return self.parent
            else:
                return self.parent.get_parent_by_key(key)
