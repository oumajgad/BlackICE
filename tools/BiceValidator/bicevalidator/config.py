"""The project's validator settings: which rules are hidden, and where the baseline is.

Kept in `tools/BiceValidator/validator.json` inside the mod checkout, so that the window,
the command line and the release pipeline all hide the same things - and so that the
bundled exe, whose own files live in a temporary folder while it runs, finds and saves
them in the checkout it is pointed at. What only matters to one person - window size,
the last filter typed - is the GUI's own business and lives in its QSettings instead.
"""

import json
import os
from dataclasses import dataclass, field

# Where the tool sits inside a BlackICE checkout.
TOOL_IN_MOD = os.path.join("tools", "BiceValidator")
CONFIG_NAME = "validator.json"

# What stops a release build: faults that leave a file unreadable from that point on.
# Everything else is reported by the build but does not stop it, so adopting the validator
# does not mean fixing six hundred existing findings first.
DEFAULT_RELEASE_BLOCKING = ["BV001", "BV002", "BV003", "BV004", "BV005", "BV008"]


def path_for(root):
    """The config file for the mod at \\p root.

    In a checkout - one with this tool in it - the file is the committed one, shared by
    everyone. Any other mod folder, such as an installed copy under the game's tfh/mod,
    gets one in the user's own application data instead: the game folder is not the
    validator's to write in, and an installed copy has no tool folder to put it in.
    """
    in_mod = os.path.join(root, TOOL_IN_MOD)
    if os.path.isdir(in_mod):
        return os.path.join(in_mod, CONFIG_NAME)
    import hashlib
    base = os.environ.get("APPDATA") or os.path.expanduser("~")
    absolute = os.path.normcase(os.path.abspath(root))
    tag = hashlib.sha1(absolute.encode("utf-8")).hexdigest()[:8]
    name = "".join(c if c.isalnum() or c in " -_." else "_" for c in os.path.basename(absolute))
    return os.path.join(base, "BICE Validator", "mods", "%s-%s" % (name, tag), CONFIG_NAME)


@dataclass
class Config:
    path: str
    hidden_rules: set = field(default_factory=set)
    baseline: str = "baseline.json"     # relative to the config file
    release_blocking: list = field(default_factory=lambda: list(DEFAULT_RELEASE_BLOCKING))

    @property
    def baseline_path(self):
        return os.path.join(os.path.dirname(self.path), self.baseline)

    @classmethod
    def for_mod(cls, root):
        return cls.load(path_for(root))

    @classmethod
    def load(cls, path):
        config = cls(path=path)
        if os.path.exists(path):
            with open(path, encoding="utf-8") as handle:
                data = json.load(handle)
            config.hidden_rules = set(data.get("hidden_rules", ()))
            config.baseline = data.get("baseline", config.baseline)
            config.release_blocking = list(data.get("release_blocking",
                                                    config.release_blocking))
        return config

    def save(self):
        data = {"hidden_rules": sorted(self.hidden_rules), "baseline": self.baseline,
                "release_blocking": self.release_blocking}
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        with open(self.path, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(data, handle, indent=2)
            handle.write("\n")
