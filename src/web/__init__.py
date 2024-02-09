# pylint: disable=duplicate-code
"""
Handle web requests
"""

from importlib import import_module
from os import path
from pkgutil import iter_modules

blueprints = []
for module in iter_modules([path.dirname(__file__)]):
    mod = import_module(name=f".{module.name}", package=__package__)

    for attr in vars(mod):
        value = getattr(mod, attr)
        if (
            type(value).__module__ == "flask.blueprints"
            and type(value).__name__ == "Blueprint"
        ):
            blueprints.append(getattr(mod, attr))
