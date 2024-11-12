from uuid import UUID

def validate_password(password: str):
    if not password: return False
    if len(password) < 8 or len(password) > 32:
        return False
    if not any(char.isalpha() for char in password):
        return False
    if not any(char.isdigit() for char in password):
        return False
    return True

def validate_username(username: str):
    if not username: return False
    if len(username) < 3 or len(username) > 32:
        return False
    return True

def validate_title(title: str):
    if not title: return False
    if len(title) > 100:
        return False
    return True

def validate_page_text(text: str):
    if not text: return False
    if len(text) > 10000:
        return False
    return True

def safe_convert_to_uuid(uuid: str):
    try:
        return UUID(hex=uuid)
    except ValueError and TypeError:
        return UUID(int=0)