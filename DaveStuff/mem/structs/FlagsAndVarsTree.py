from pymem import Pymem


class FlagsAndVarsTree:

    @classmethod
    def build_names_from_tree_recursive(cls, pm: Pymem, res: list, node_ptr: int, current_name: str = ""):
        character = pm.read_char(node_ptr + 0x4)
        next_sibling_node = pm.read_uint(node_ptr + 0xC)
        child_node = pm.read_uint(node_ptr + 0x10)
        # print(f"{node_ptr=} - {current_name=} - {character=} - {next_sibling_node=} - {child_node=}")
        new_name = current_name + character
        if child_node != 0:
            cls.build_names_from_tree_recursive(pm, res, child_node, new_name)
        if child_node == 0:
            # print(f"{node_ptr=} - {new_name=}")
            res.append(new_name)
        if next_sibling_node != 0:
            cls.build_names_from_tree_recursive(pm, res, next_sibling_node, current_name)

    @classmethod
    def traverse_tree_depth_first(cls, pm: Pymem, node_ptr: int, res: list) -> list[int]:
        if node_ptr != 0:
            character = pm.read_char(node_ptr + 0x4)
            parent_node = pm.read_uint(node_ptr + 0x8)
            if parent_node != 0:
                # if a new flag/var is added the first node pointer is not changed, instead it has a parent pointer set
                cls.traverse_tree_depth_first(pm=pm, node_ptr=parent_node, res=res)

            next_sibling_node = pm.read_uint(node_ptr + 0xC)
            child_node = pm.read_uint(node_ptr + 0x10)
            element_ptr = pm.read_uint(node_ptr)
            # print(f"{node_ptr=} - {character=} - {next_sibling_node=} - {child_node=}")
            if element_ptr != 0:
                # print(f"{node_ptr=} - {element_ptr=}")
                res.append(element_ptr)
            if child_node != 0:
                cls.traverse_tree_depth_first(pm=pm, node_ptr=child_node, res=res)
            if next_sibling_node != 0:
                cls.traverse_tree_depth_first(pm=pm, node_ptr=next_sibling_node, res=res)
        return res
