from uuid import uuid4, UUID
from hashlib import sha256
from datetime import datetime

from aiohttp.typedefs import Handler
from aiohttp.web_request import Request
from aiohttp.web_response import Response

from sqlalchemy.orm import Session

from models import Token

def hash_password(password: str):
    salt = uuid4().hex
    return sha256((password + salt).encode()).hexdigest() + ':' + salt

def check_password(user_password: str, hashed_password: str):
    password, salt = hashed_password.split(':', 1)
    return password == sha256((user_password + salt).encode()).hexdigest()

def auth_required(handler: Handler):
    async def wrapper(request: Request):
        auth_token = request.headers.get('Authorization')

        if not auth_token:
            return Response(status=401, reason="Unauthorized")
        
        auth_token = auth_token.split()[-1]
        auth_token = UUID(hex=auth_token)

        session: Session = request.app.get('session')

        token = session.query(Token).filter(Token.id == auth_token).first()

        if not token or not token.active or (datetime.now() - token.created_at).total_seconds() > 18000:
            return Response(status=401, reason="Unauthorized")
        
        request['user'] = token.user

        return await handler(request)
    
    return wrapper