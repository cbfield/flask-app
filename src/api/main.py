from flask import Blueprint, make_response

api = Blueprint("api", __name__)


@api.route('/', methods=['GET'])
def index():
    response = make_response({
        "body": "Hello, World!"
    }, 200)
    response.headers["Content-Type"] = "application/json"
    return response
