from src import app
from pytest import fixture

@fixture()
def app():
    yield app


@fixture()
def client(app):
    return app.test_client()
