from json import dumps
from uuid import UUID, uuid4
from typing import Type
from os import path, remove

from config import IMAGES_FOLDER, STATIC_PATH

from aiohttp.web_request import Request
from aiohttp.web_response import Response

from sqlalchemy.orm import Session

from models import User, Token, Book, Like, Base, Page, Genre, Image
from validators import validate_password, validate_username, validate_title, validate_page_text, safe_convert_to_uuid
from auth import hash_password, check_password, auth_required

async def register_user(request: Request) -> Response:
    params = await request.post()

    username = params.get('username')
    password = params.get('password')

    if not validate_username(username):
        return Response(status=400, reason="INVALID_USERNAME")
    
    if not validate_password(password):
        return Response(status=400, reason="INVALID_PASSWORD")
    
    session: Session = request.app.get('session')
    
    user = session.query(User).filter(User.username == username).first()

    if user:
        return Response(status=409, reason="USERNAME_ALREADY_EXISTS")
    
    new_user = User(
        username=username,
        password=hash_password(password)
    )
    token = Token()
    new_user.tokens.add(token)

    session.add(new_user)
    session.commit()

    return Response(status=201, headers={"Authorization": f"Bearer {token}"}, reason="SUCCESS")

async def login_user(request: Request) -> Response:
    params = await request.post()

    username = params.get('username')
    password = params.get('password')

    session: Session = request.app.get('session')

    user = session.query(User).filter(User.username == username).first()
    if not user:
        return Response(status=404, reason="USER_NOT_FOUND")
    
    if not check_password(password, user.password):
        return Response(status=401, reason="WRONG_PASSWORD")
    
    session.execute(user.tokens.update().values(active=False))
    
    token = Token()
    user.tokens.add(token)
    session.commit()

    return Response(status=200, headers={"Authorization": f"Bearer {token}"}, reason="SUCCESS")

@auth_required
async def create_book(request: Request) -> Response:

    user: User = request.get('user')

    reader = await request.multipart()

    title = None
    first_page_text = None
    genre_id = None
    image = None

    while True:
        field = await reader.next()
        if not field:
            break
        
        if field.name == 'title':
            title = (await field.read_chunk()).decode()
        
        if field.name == 'text':
            first_page_text = (await field.read_chunk()).decode()
        
        if field.name == 'genre_id':
            genre_id = (await field.read_chunk()).decode()

        if field.name == 'cover':
            filename = uuid4().hex + '.' + field.filename.split('.')[-1]
            with open(path.join(STATIC_PATH, IMAGES_FOLDER, filename), 'wb') as file:
                for _ in range(1000):
                    chank = await field.read_chunk()
                    if not chank:
                        break
                    file.write(chank)
                else:
                    file.close()
                    remove(path.join(STATIC_PATH, IMAGES_FOLDER, filename))
                    return Response(status=413, reason="IMAGE_TOO_BIG")
            image = Image(path=path.join(IMAGES_FOLDER, filename))


    if not validate_title(title):
        return Response(status=400, reason="INVALID_TITLE")
    
    if not validate_page_text(first_page_text):
        return Response(status=400, reason="INVALID_FIRST_PAGE_TEXT")
    
    session: Session = request.app.get('session')

    genre = session.query(Genre).filter(Genre.id == safe_convert_to_uuid(genre_id)).first()

    book = Book(
        title=title,
        author=user,
        genre=genre,
    )

    if image:
        session.add(image)
        session.commit()
        book.cover_image_id = image.id

    first_page = Page(
        text=first_page_text,
        book=book,
        first=True,
        author=user
    )
    
    session.add(book)
    session.add(first_page)
    session.commit()

    return Response(status=201, reason="SUCCESS", content_type='application/json', body=dumps({'book_id': str(book.id), 'first_page_id': str(first_page.id)}))

async def get_book(request: Request) -> Response:
    book_id = request.query.get('book_id', UUID(int=0).hex)

    session: Session = request.app.get('session')

    book = session.execute(Book.select(where={'id': book_id}, limit=1)).first()

    if not book:
        return Response(status=404, reason="BOOK_NOT_FOUND")
    
    return Response(status=200, reason="SUCCESS", content_type='application/json', body=dumps(book._asdict(), default=str))

async def get_list(request: Request, Model: Type[Base]) -> Response:
    
    params = request.query

    where = {}
    order_by = None
    desc_ = False
    offset = 0
    limit = 20

    for param in params:
        if param.endswith("_f"):
            where[param[-2]] = params[param]
        elif param == 'order_by':
            order_by = params[param]
        elif param == 'desc':
            desc_ = True
        elif param == 'offset' and params[param].isdecimal():
            offset = int(params[param])
        elif param == 'limit' and params[param].isdecimal():
            limit = int(params[param])

    session: Session = request.app.get('session')

    items = session.execute(Model.select(where=where, order_by=order_by, desc_=desc_, offset=offset, limit=limit)).all()
    
    return Response(status=200, reason='SUCCESS', content_type='application/json', body=dumps([row._asdict() for row in items], default=str))

async def get_books(request: Request) -> Response:
    return await get_list(request, Book)

@auth_required
async def like_book(request: Request) -> Response:
    params = await request.post()
    book_id = params.get('book_id', UUID(int=0).hex)
    user: User = request.get('user')

    session: Session = request.app.get('session')

    if session.query(Like).filter(Like.book_id == UUID(hex=book_id), Like.user_id == user.id).first():
        return Response(status=409, reason="BOOK_ALREADY_LIKED")

    book = session.query(Book).filter(Book.id == UUID(hex=book_id)).first()
    if not book:
        return Response(status=404, reason="BOOK_NOT_FOUND")

    like = Like(
        book=book,
        user=user
    )
    
    session.add(like)
    session.commit()

    return Response(status=200, reason="SUCCESS")

@auth_required
async def unlike_book(request: Request):
    params = await request.post()
    book_id = params.get('book_id', UUID(int=0).hex)
    user: User = request.get('user')

    session: Session = request.app.get('session')

    session.execute(Like.delete(where={'book_id': book_id, 'user_id': user.id.hex}))

    return Response(status=200, reason='SUCCESS')

@auth_required
async def create_page(request: Request):
    user: User = request.get('user')
    params = await request.post()

    last = 'last' in params

    text = params.get('text')

    if not validate_page_text(text):
        return Response(status=400, reason="INVALID_PAGE_TEXT")
    
    prev_page_id = params.get('prev_page_id', UUID(int=0).hex)

    session: Session = request.app.get('session')
    prev_page = session.query(Page).filter(Page.id == UUID(hex=prev_page_id)).first()

    if not prev_page:
        return Response(status=404, reason="PREV_PAGE_NOT_FOUND")
    
    if prev_page.last:
        return Response(status=409, reason="LAST_PAGE_REFERENCE")
    
    new_page = Page(
        text=text,
        book=prev_page.book,
        author=user,
        previous_page=prev_page,
        last=last
    )

    session.add(new_page)
    session.commit()

    return Response(status=201, reason="SUCCESS", content_type='application/json', body=dumps({'page_id': str(new_page.id)}))


async def get_page(request: Request):
    page_id = request.query.get('page_id', UUID(int=0).hex)
    session: Session = request.app.get('session')

    page = session.execute(Page.select(where={'id': page_id}, limit=1)).first()

    if not page:
        return Response(status=404, reason="PAGE_NOT_FOUND")
    
    return Response(status=200, reason="SUCCESS", content_type='application/json', body=dumps(page._asdict(), default=str))

async def get_pages(request: Request):
    return await get_list(request, Page)

@auth_required
async def like_page(request: Request) -> Response:
    params = await request.post()
    page_id = params.get('page_id', UUID(int=0).hex)
    user: User = request.get('user')

    session: Session = request.app.get('session')

    if session.query(Like).filter(Like.page_id == UUID(hex=page_id), Like.user_id == user.id).first():
        return Response(status=409, reason="PAGE_ALREADY_LIKED")

    page = session.query(Page).filter(Page.id == UUID(hex=page_id)).first()
    if not page:
        return Response(status=404, reason="PAGE_NOT_FOUND")

    like = Like(
        page=page,
        user=user
    )
    
    session.add(like)
    session.commit()

    return Response(status=200, reason="SUCCESS")


@auth_required
async def unlike_page(request: Request):
    params = await request.post()
    page_id = params.get('page_id', UUID(int=0).hex)
    user: User = request.get('user')

    session: Session = request.app.get('session')

    session.execute(Like.delete(where={'page_id': page_id, 'user_id': user.id.hex}))

    return Response(status=200, reason='SUCCESS')


