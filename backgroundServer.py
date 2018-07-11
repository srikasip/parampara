from flask import Flask, redirect
from flask import render_template
from flask import render_template_string
from flask import request
from flask import jsonify
import json
from datetime import datetime
import connectToDB as dbHand
import os

app = Flask(__name__)
#app = Flask(__name__, instance_relative_config=True)
#app.config.from_pyfile('.env', silent=True)

# @app.before_request
# def before_request():
#   #if request.url.startswith('http://'):
#   if not request.is_secure:
#     url = request.url.replace('http://', 'https://', 1)
#     code = 301
#     return redirect(url, code=code)

@app.route('/')
def home():
  return render_template("home.html")


if __name__ == '__main__':
  context = os.environ.get('APP_CD_CONTEXT', default='development')
  if context == 'development':
    app.run(ssl_context='adhoc')
  else:
    app.run()
  