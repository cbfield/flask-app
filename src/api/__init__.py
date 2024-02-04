from pkgutil import iter_modules
from importlib import import_module
from os import path

blueprints = []
for module in iter_modules([path.dirname(__file__)]):
    mod = import_module(name=".%s" % module.name, package=__package__)

    for attr in vars(mod):
        value = getattr(mod, attr)
        if type(value).__module__ == "flask.blueprints" and type(value).__name__ == "Blueprint":
            blueprints.append(getattr(mod, attr))
