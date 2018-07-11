import psycopg2
import json
from operator import itemgetter
import os


context = os.environ.get('APP_CD_CONTEXT', default='development')

if context == 'development':
  database = "ClinicDashDB"
  user = "srikasip"
  host = "localhost"
  port =''
  password = ''

else:
  database = os.environ.get("APP_DB", default=None)
  user = os.environ.get("APP_USER", default=None)
  host = os.environ.get("APP_HOST", default=None)
  port = os.environ.get("APP_PORT", default=None)
  password = os.environ.get("APP_PASSWORD", default=None)


def connectToDB(command):
  conn = psycopg2.connect("dbname='"+database+"' user='"+user+"' host='"+host+"' password='"+password+"' port="+port)
  cur = conn.cursor()
  cur.execute(command)
  allData = cur.fetchall()[0][0]

  conn.commit()
  cur.close()
  conn.close()
  return allData