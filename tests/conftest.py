from importlib import import_module
from pathlib import Path
from sys import path

from pytest import fixture

path.append(str(Path(__file__).parent.parent))
src = import_module("src", package="src")

@fixture()
def app():
    yield src.app


@fixture()
def client(app):
    return app.test_client()
