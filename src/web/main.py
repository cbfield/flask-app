from logging import getLevelName, getLogger
from os import environ

from flask import Blueprint, make_response, render_template, request

web = Blueprint("web", __name__, template_folder='templates')
log = getLogger("MyApp-Web")
if "LOG_LEVEL" in environ:
    log.setLevel(getLevelName(environ.get("LOG_LEVEL")))


@web.route('/', methods=['GET'])
def index():
    log.info("Received Request: %s" % request)
    return make_response(render_template('index.html', context={}), 200)
