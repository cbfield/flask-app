from web.views import blueprints
from flask import Flask
from os import environ

app = Flask(__name__)
app.config['SECRET_KEY'] = environ.get('FLASK_SECRET_KEY')

for blueprint in blueprints:
    app.register_blueprint(blueprint)
