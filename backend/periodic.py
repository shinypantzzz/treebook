from typing import Callable
from asyncio import sleep

def periodic(interval: int):
    def wrapper(func: Callable):
        async def wrapper(*args, **kwargs):
            func(*args, **kwargs)
            await sleep(interval)
            await wrapper()

        return wrapper

    return wrapper
    