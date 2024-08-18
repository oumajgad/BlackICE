namespace HDS {
    struct CVariable
    {
        std::string name;
        int32_t value;
    };

    struct LinkedListNodeSingle
    {
        uintptr_t data;
        uintptr_t prev;
        uintptr_t next;
    };
}