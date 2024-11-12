from os import path

self_path = path.dirname(__file__)

DB_PATH = path.normpath(path.join(self_path, path.pardir, 'db', 'treebook.db'))
STATIC_PATH = path.normpath(path.join(self_path, path.pardir, 'static'))
IMAGES_FOLDER = 'user_images'
