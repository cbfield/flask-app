"""
Routing for API requests
"""

from logging import getLevelName, getLogger
from os import environ

from flask import Blueprint, make_response, request

api = Blueprint("api", __package__)
log = getLogger(f"{__package__}-API-v1")
if "LOG_LEVEL" in environ:
    log.setLevel(getLevelName(environ.get("LOG_LEVEL")))


@api.route("/", methods=["GET"])
def index():
    """
    Handles requests for API path: /
    """

    log.info("Received Request: %s", request)
    response = make_response({"body": "Hello, World!"}, 200)
    response.headers["Content-Type"] = "application/json"
    return response
