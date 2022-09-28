from os import environ
from web import app

if __name__ == "__main__":
    app.run(
        debug=environ.get('FLASK_DEBUG', False),
        host=environ.get('FLASK_HOST', '0.0.0.0'),
        port=environ.get('FLASK_PORT', 5000)
    )
