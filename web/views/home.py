from flask import Blueprint, render_template

views = Blueprint('home', __name__, template_folder='../templates')


@views.route('/', methods=['GET'])
def home():
    context = {}
    return render_template('home.html', context=context)
