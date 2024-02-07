from pytest import fixture
from importlib import import_module

from src import app as flaskapp

@fixture()
def app():
    yield flaskapp


@fixture()
def client(app):
    return app.test_client()
