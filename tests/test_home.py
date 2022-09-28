from context import app, client


def test_home(client):
    response = client.get("/")
    assert response.status_code == 200
