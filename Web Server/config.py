SECRET_KEY = 'you-will-never-guess'
CLIENT_ID = '704562d42a754b50a52a77c754d13ad6'
AUTH_TOKEN_TTL = 100

# Database Config
import os
basedir = os.path.abspath(os.path.dirname(__file__))

SQLALCHEMY_DATABASE_URI = 'sqlite:///' + os.path.join(basedir, 'app.db')
SQLALCHEMY_MIGRATE_REPO = os.path.join(basedir, 'db_repository')
