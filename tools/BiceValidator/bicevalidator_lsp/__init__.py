"""BICE Validator as a language server, for the BlackICE Script extension for VS Code.

It speaks the Language Server Protocol over stdin and stdout through pygls, and does all
its checking through the `bicevalidator` library - the same rules the window, the command
line and the release build use.
"""
