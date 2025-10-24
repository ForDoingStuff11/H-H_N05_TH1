from flask import Flask, render_template
from controllers.text_controller import text_bp
from controllers.file_controller import file_bp
from werkzeug.middleware.proxy_fix import ProxyFix

app = Flask(__name__)
app.secret_key = "secret"
app.wsgi_app = ProxyFix(app.wsgi_app, x_proto=1, x_host=1)

# register routes
app.register_blueprint(text_bp, url_prefix="/text")
app.register_blueprint(file_bp, url_prefix="/file")

@app.route("/")
def index():
    return render_template("layout.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
