from src.web import blueprints as web_blueprints
from src.api import blueprints as api_blueprints
from flask import Flask
from os import urandom

app = Flask(__name__)
app.config['SECRET_KEY'] = urandom(12)

for blueprint in web_blueprints:
    app.register_blueprint(blueprint)

for blueprint in api_blueprints:
    app.register_blueprint(blueprint, url_prefix="/api/v1/")
