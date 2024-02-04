from pkgutil import iter_modules
from importlib import import_module
from os import path as os_path
from sys import path as sys_path

pwd = os_path.dirname(__file__)
if pwd not in sys_path:
    sys_path.append(pwd)

blueprints = []
for module in iter_modules([pwd]):
    mod = import_module(name=module.name)

    for attr in vars(mod):
        value = getattr(mod, attr)
        if type(value).__module__ == "flask.blueprints" and type(value).__name__ == "Blueprint":
            blueprints.append(getattr(mod, attr))

if pwd in sys_path:
    sys_path.remove(pwd)
