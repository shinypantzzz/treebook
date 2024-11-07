from sqlalchemy import ForeignKey, func, select, Select, desc, and_, Delete, delete
from sqlalchemy.orm import DeclarativeBase, Mapped, WriteOnlyMapped, mapped_column, relationship
from sqlalchemy.types import String
from sqlalchemy.sql.elements import ColumnElement
from sqlalchemy.sql import alias

from uuid import uuid4, UUID
from datetime import datetime
from typing import Optional, Callable

class Base(DeclarativeBase):

    __order_by_options__: set[str] = set()
    __filter_options__: dict[str, Callable[[str], ColumnElement[bool]]] = {}
    
    @staticmethod
    def select(order_by: str | None = None, where: dict[str, str] = {}, desc_: bool = False, offset: int = 0, limit: int = 20) -> Select:
        pass

    @staticmethod
    def delete(where: dict[str, str] = {}) -> Delete:
        pass
    

class User(Base):
    __tablename__ = 'users'

    id: Mapped[UUID] = mapped_column(primary_key=True, insert_default=uuid4)
    username: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    password: Mapped[str]
    books: Mapped[list["Book"]] = relationship(back_populates="author")
    pages: Mapped[list["Page"]] = relationship(back_populates="author")
    tokens: WriteOnlyMapped[list["Token"]] = relationship(back_populates="user")
    likes: Mapped[list["Like"]] = relationship(back_populates='user')

class Token(Base):
    __tablename__ = 'tokens'

    id: Mapped[UUID] = mapped_column(primary_key=True, insert_default=uuid4)
    active: Mapped[bool] = mapped_column(insert_default=True)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id"))
    user: Mapped["User"] = relationship(back_populates="tokens")
    created_at: Mapped[datetime] = mapped_column(insert_default=datetime.now)

    def __str__(self):
        return str(self.id)
    
    def __repr__(self) -> str:
        return self.__str__()

class Book(Base):
    __tablename__ = 'books'

    __filter_options__ = {
        "author_id": lambda author_id: Book.author_id == UUID(hex=author_id),
        "id": lambda id: Book.id == UUID(hex=id),
    }

    __order_by_options__ = {
        'created_at',
        'title',
        'likes_count'
    }


    id: Mapped[UUID] = mapped_column(primary_key=True, insert_default=uuid4)
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    author_id: Mapped[UUID] = mapped_column(ForeignKey("users.id"))
    author: Mapped["User"] = relationship(back_populates="books")
    genre_id: Mapped[Optional[UUID]] = mapped_column(ForeignKey("genres.id"))
    genre: Mapped[Optional["Genre"]] = relationship(back_populates="books")
    created_at: Mapped[datetime] = mapped_column(insert_default=datetime.now)
    pages: WriteOnlyMapped[list["Page"]] = relationship(back_populates="book")
    likes: WriteOnlyMapped[list["Like"]] = relationship(back_populates='book')

    @staticmethod
    def select(order_by: str | None = None, where: dict[str, str] = {}, desc_: bool = False, offset: int = 0, limit: int = 20) -> Select:
        _where = []
        for op, ex in __class__.__filter_options__.items():
            if op in where:
                _where.append(ex(where[op]))

        _order_by = order_by

        if _order_by not in __class__.__order_by_options__:
            _order_by = None
        
        if desc_:
            _order_by = desc(_order_by)

        _offset = offset

        _limit = limit
        if _limit > 200:
            _limit = 20
 
        return (
            select(
                *__class__.__table__.columns, 
                func.count(Like.user_id).label("likes_count"), 
                User.username.label("author"), 
                Page.id.label("first_page_id"),
                Genre.name.label("genre")
            )
            .join_from(__class__, Like, __class__.id == Like.book_id, isouter=True)
            .join(User, __class__.author_id == User.id)
            .join(Page, and_(__class__.id == Page.book_id, Page.first == True), isouter=True)
            .join(Genre, __class__.genre_id == Genre.id, isouter=True)
            .group_by(__class__.id)
            .where(True, *_where)
            .order_by(_order_by)
            .offset(_offset)
            .limit(_limit)
        )
        


class Page(Base):
    __tablename__ = 'pages'

    __filter_options__ = {
        'id': lambda id: Page.id == UUID(hex=id),
        'next_for': lambda prev_page_id: Page.previous_page_id == UUID(hex=prev_page_id)
    }

    __order_by_options__ = {
        'created_at',
        'likes_count'
    }

    id: Mapped[UUID] = mapped_column(primary_key=True, insert_default=uuid4)
    text: Mapped[str] = mapped_column(String(10000))
    book_id: Mapped[UUID] = mapped_column(ForeignKey("books.id"))
    book: Mapped["Book"] = relationship(back_populates="pages")
    first: Mapped[bool] = mapped_column(nullable=False, default=False)
    last: Mapped[bool] = mapped_column(nullable=False, default=False)
    previous_page_id: Mapped[Optional[UUID]] = mapped_column(ForeignKey("pages.id"))
    previous_page: Mapped[Optional["Page"]] = relationship(back_populates="next_pages", remote_side=[id])
    next_pages: Mapped[list["Page"]] = relationship(back_populates="previous_page")
    author_id: Mapped[UUID] = mapped_column(ForeignKey("users.id"))
    author: Mapped["User"] = relationship(back_populates="pages")
    created_at: Mapped[datetime] = mapped_column(insert_default=datetime.now)
    likes: WriteOnlyMapped[list["Like"]] = relationship(back_populates='page')

    @staticmethod
    def select(order_by: str | None = None, where: dict[str, str] = {}, desc_: bool = False, offset: int = 0, limit: int = 20) -> Select:
        _where = []
        for op, ex in __class__.__filter_options__.items():
            if op in where:
                _where.append(ex(where[op]))

        _order_by = order_by

        if _order_by not in __class__.__order_by_options__:
            _order_by = None
        
        if desc_:
            _order_by = desc(_order_by)

        _offset = offset

        _limit = limit
        if _limit > 200:
            _limit = 20

        parent_pages = alias(Page, name='parent_pages')
 
        return (
            select(*__class__.__table__.columns, func.count(Like.user_id).label("likes_count"), User.username.label("author"), Page.id.label("prev_page_id"))
            .join_from(__class__, Like, __class__.id == Like.page_id, isouter=True)
            .join(User, __class__.author_id == User.id)
            .join(parent_pages, __class__.previous_page_id == parent_pages.columns.get('id'), isouter=True)
            .group_by(__class__.id)
            .where(True, *_where)
            .order_by(_order_by)
            .offset(_offset)
            .limit(_limit)
        )

class Like(Base):
    __tablename__ = 'likes'

    __filter_options__ = {
        "user_id": lambda user_id: Like.user_id == UUID(hex=user_id),
        "book_id": lambda book_id: Like.book_id == UUID(hex=book_id),
        "page_id": lambda page_id: Like.page_id == UUID(hex=page_id),
    }

    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id"), primary_key=True)
    user: Mapped["User"] = relationship(back_populates="likes")
    book_id: Mapped[UUID] = mapped_column(ForeignKey("books.id"), insert_default=UUID(int=0), primary_key=True)
    book: Mapped["Book"] = relationship(back_populates="likes")
    page_id: Mapped[UUID] = mapped_column(ForeignKey("pages.id"), insert_default=UUID(int=0), primary_key=True)
    page: Mapped["Page"] = relationship(back_populates="likes")

    @staticmethod
    def delete(where: dict[str, str] = {}) -> Delete:
        _where = []
        for op, ex in Like.__filter_options__.items():
            if op in where:
                _where.append(ex(where[op]))

        return delete(Like).where(True, *_where)
    

class Genre(Base):
    __tablename__ = 'genres'

    id: Mapped[UUID] = mapped_column(primary_key=True, insert_default=uuid4)
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    books: Mapped[list["Book"]] = relationship(back_populates="genre")