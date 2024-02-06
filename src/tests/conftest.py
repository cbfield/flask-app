from pytest import fixture

from src import app


@fixture()
def app():
    yield app


@fixture()
def client(app):
    return app.test_client()
