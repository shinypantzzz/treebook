from config import DB_PATH, STATIC_PATH

from aiohttp import web
import asyncio
import aiohttp_cors

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

import handlers
from cleanups import tokens_cleanup

engine = create_engine(f"sqlite:///{DB_PATH}", echo=True)
loop = asyncio.new_event_loop()

with Session(engine) as session:

    app = web.Application()
    app['session'] = session

    app.add_routes([
        web.post  ('/register_user', handlers.register_user),
        web.post  ('/login_user', handlers.login_user),
        web.post  ('/book', handlers.create_book),
        web.post  ('/book/from_file/{file_type}', handlers.create_book_from_file),
        web.get   ('/book', handlers.get_book),
        web.get   ('/books', handlers.get_books),
        web.post  ('/book/like', handlers.like_book),
        web.delete('/book/like', handlers.unlike_book),
        web.post  ('/page', handlers.create_page),
        web.get   ('/page', handlers.get_page),
        web.get   ('/pages', handlers.get_pages),
        web.post  ('/page/like', handlers.like_page),
        web.delete('/page/like', handlers.unlike_page),
        web.get   ('/genres', handlers.get_genres),
        web.static('/static', STATIC_PATH, name='static')
    ])

    cors = aiohttp_cors.setup(app, defaults={
        "*": aiohttp_cors.ResourceOptions(
            allow_credentials=True,
            expose_headers="*",
            allow_headers="*",
            allow_methods="*",
        )
    })

    for route in list(app.router.routes()):
        cors.add(route)

    loop.create_task(tokens_cleanup(session))

    web.run_app(app, port=80, loop=loop)