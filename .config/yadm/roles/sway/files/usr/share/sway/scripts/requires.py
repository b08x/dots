#!/usr/bin/python3
"""
Collect the dependency specification comments from a sway config,
following the `include` directives.

The script can handle the declaration style we use in this project:
```
# Requires: the-package
# Recommends: the-other-package
```
but it is in no way a complete sway config parser (or a complete
rpm-style dependency parser).
"""

from __future__ import annotations

import logging
import re
import sys
from dataclasses import dataclass
from glob import iglob
from os.path import abspath, basename, expandvars, relpath
from typing import Sequence

LOG = logging.getLogger()
# Resolve paths without actually installing the snippets
MAPPINGS = {  #
    "/etc/sway/config.d": abspath("sway"),
    "/usr/share/sway/config.d": abspath("sway/config.d"),
}
INCLUDE_RE = re.compile(r"^include\s+(.*?)\s*$")
DIRECTIVE_RE = re.compile(r"^#\s*([A-Z]\w+):\s*(.*)\s*$")
DEPENDENCY_RE = re.compile(r"^([^\s<=>]+)")
DEPENDENCY_SEP_RE = re.compile(r",\s*")

files: set[str] = set()
dependencies: dict[str, Dependency] = {}


@dataclass
class Dependency:
    """RPM-style dependency specification"""

    __raw: str
    name: str
    weak: bool = False

    def __init__(self, raw: str, weak: bool = False):
        self.__raw = raw
        self.weak = weak
        if match := DEPENDENCY_RE.match(raw):
            self.name = match[1]
        else:
            raise Exception(f"Failed to parse dependency spec {raw}")

    def __hash__(self):
        return self.name.__hash__()

    def __lt__(self, other):
        """Sort order: weak deps first, then alphabetic"""
        return self.weak if self.weak != other.weak else self.name < other.name

    def __str__(self):
        return ("Recommends: " if self.weak else "Requires: ") + self.__raw

    def stronger(self, other: Dependency):
        """
        Checks that the current dependency is for the same package, but
        stronger than the other.
        """
        if self.name != other.name:
            return False

        return other.weak and not self.weak

    @staticmethod
    def parse(string: str, **args) -> Sequence[Dependency]:
        """Read one or multiple dependency specifications from string"""
        return [Dependency(v, **args) for v in DEPENDENCY_SEP_RE.split(string)]


def handle_directive(directive: str, value: str):
    if directive in ("Requires", "Recommends"):
        weak = directive == "Recommends"
        for dependency in Dependency.parse(value, weak=weak):
            existing = dependencies.get(dependency.name, None)
            if existing and not dependency.stronger(existing):
                continue
            dependencies[dependency.name] = dependency


def handle_include(value: str, root_dir: str = None):
    # hack to support scripts/sway/layered-include
    if value.startswith("'$("):
        value = abspath("sway/config.d/*.conf")
    value = expandvars(value)
    for prefix, subst in MAPPINGS.items():
        if value.startswith(prefix):
            value = value.replace(prefix, subst)
    for inc in iglob(value, root_dir=root_dir):
        handle_file(inc)


def handle_file(path: str):
    """Parse configuration snippet file"""
    if path in files:
        return
    files.add(path)
    LOG.info("processing %s", relpath(path))

    try:
        with open(path, "r", encoding="utf-8") as file:
            for line in file:
                if match := INCLUDE_RE.match(line):
                    handle_include(match[1], basename(path))
                elif match := DIRECTIVE_RE.match(line):
                    handle_directive(match[1], match[2])
    except IOError:
        LOG.exception("Failed to read %s", path)


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)

    for arg in sys.argv[1:]:
        handle_file(arg)

    for dep in sorted(dependencies.values()):
        print(dep)
