import os
import pytest
import sys

sys.path.insert(0, os.path.abspath(
    os.path.join(os.path.dirname(__file__), '..')
))

from web import app as webapp

@pytest.fixture()
def app():
    yield webapp


@pytest.fixture()
def client(app):
    return app.test_client()
