"""
Application Entrypoint
"""

from os import environ

from src import app

if __name__ == "__main__":
    app.run(
        debug=environ.get("FLASK_DEBUG", False),
        host=environ.get("FLASK_HOST", "0.0.0.0"),
        port=environ.get("FLASK_PORT", 5000),
    )
