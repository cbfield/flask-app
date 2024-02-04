from flask import Blueprint, make_response, render_template

web = Blueprint('web', __name__, template_folder='templates')


@web.route('/', methods=['GET'])
def index():
    return make_response(render_template('index.html', context={}), 200)
