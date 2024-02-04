def test_web_root(client):
    response = client.get("/")
    assert response.mimetype == "text/html" and response.status_code == 200
