def test_api_root(client):
    response = client.get("/api/v1/")
    assert response.mimetype == "application/json" and response.status_code == 200
