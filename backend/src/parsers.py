from abc import ABC, abstractmethod
from xml.etree import ElementTree
from base64 import b64decode
from typing import Iterable, TypeVar, Type, Tuple

T = TypeVar('T', bound="BookParser")
ImageData = Tuple[bytes, str]

class BookParser(ABC):
    @classmethod
    @abstractmethod
    def from_bytes(cls: Type[T], data: bytes, encoding: str) -> T:
        pass

    @abstractmethod
    def get_title(self) -> str | None:
        pass

    @abstractmethod
    def get_cover(self) -> ImageData | None:
        pass

    @abstractmethod
    def get_text(self, max_length: int) -> Iterable[str]:
        pass

    @abstractmethod
    def get_title(self) -> str:
        pass

class StringBookParser(BookParser):

    def __init__(self, data: str):
        self.string = data

    @classmethod
    def from_bytes(cls, data: bytes, encoding: str = 'utf-8'):
        return cls(data.decode(encoding))

    def get_text(self, max_length: int) -> list[str]:
        dot_index = new_line_index = space_index = -1
        page_start_index = 0
        pages = []
        for i, ch in enumerate(self.string):
            if ch == '\n':
                new_line_index = i
            elif ch == '.':
                dot_index = i
            elif ch ==' ':
                space_index = i
            
            if i - page_start_index + 1 >= max_length:
                if new_line_index != -1:
                    pages.append(self.string[page_start_index:new_line_index])
                    page_start_index = new_line_index + 1
                    dot_index = -1 if new_line_index > dot_index else dot_index
                    space_index = -1 if new_line_index > space_index else space_index
                    new_line_index = -1
                elif dot_index != -1:
                    pages.append(self.string[page_start_index:dot_index + 1])
                    page_start_index = dot_index + 1
                    space_index = -1 if dot_index > space_index else space_index
                    dot_index = new_line_index = -1
                elif space_index != -1:
                    pages.append(self.string[page_start_index:space_index])
                    page_start_index = space_index + 1
                    space_index = dot_index = new_line_index = -1
                else:
                    pages.append(self.string[page_start_index:i + 1])
                    page_start_index = i + 1
                    dot_index = new_line_index = space_index = -1
        
        if page_start_index < len(self.string):
            pages.append(self.string[page_start_index:])

        return pages
    
    def get_title(self):
        return None
    
    def get_cover(self):
        return None


class FB2BookParser(BookParser):

    _namespaces = {
        'l': 'http://www.w3.org/1999/xlink'
    }
    def __init__(self, data: str):
        self.root = ElementTree.fromstring(data)

    @classmethod
    def from_bytes(cls, data: bytes, encoding: str = 'utf-8'):
        return cls(data.decode(encoding))
    @classmethod
    def from_file(cls, filename: str, encoding: str = 'utf-8'):
        with open(filename, 'r', encoding=encoding) as file:
            return cls(file.read())
        
    def get_title(self) -> str | None:
        title_el = self.root.find('{*}description/{*}title-info/{*}book-title')
        return title_el.text if title_el is not None else None
    
    def get_text(self, max_length: int) -> list[str] | None:
        body_el = self.root.find('{*}body')

        return self._pages(body_el, max_length) if body_el is not None else None
    
    def get_cover(self) -> ImageData | None:
        image = self.root.find('{*}description/{*}title-info/{*}coverpage/{*}image')
        if image is None:
            return None

        binary_id = image.get(f'{{{__class__._namespaces['l']}}}href')
        if binary_id is None:
            return None

        binary_id = binary_id[1:]

        data_el = self.root.find(f"{{*}}binary[@id='{binary_id}']")

        if data_el is None:
            return None

        return b64decode(data_el.text), binary_id.split('.')[-1]

    
    @staticmethod
    def _full_text(el: ElementTree.Element) -> str:
        text = el.text if el.text is not None else ''
        for child in el:
            text += __class__.full_text(child)
        text += el.tail if el.tail is not None else ''
        return text
    
    @staticmethod
    def _pages(el: ElementTree.Element, max_length: int) -> list[str]:
        pages = []
        if el.text:
            parser = StringBookParser(el.text)
            pages.extend(parser.get_text(max_length))

        for child in el:
            to_add = __class__._pages(child, max_length)
            if pages and to_add and len(pages[-1]) + len(to_add[0]) <= max_length:
                pages[-1] += to_add[0]
                pages.extend(to_add[1:])
            else:
                pages.extend(to_add)

        if el.tail:
            parser = StringBookParser(el.tail)
            to_add = parser.get_text(max_length)
            if pages and to_add and len(pages[-1]) + len(to_add[0]) <= max_length:
                pages[-1] += to_add[0]
                pages.extend(to_add[1:])
            else:
                pages.extend(to_add)

        return pages
    