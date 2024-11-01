from datetime import datetime, timedelta

from sqlalchemy.orm import Session
from sqlalchemy import delete, or_

from periodic import periodic
from models import Token

@periodic(3600)
def tokens_cleanup(session: Session):
    session.execute(delete(Token).where(or_(Token.active == False, Token.created_at < datetime.now() - timedelta(hours=5))))
    session.commit()