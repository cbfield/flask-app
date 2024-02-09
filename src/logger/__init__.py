"""
Logger Configurations

This module defines one custom formatter and one custom filter.

JsonLinesFormatter - Format logs into JSON lines
RegexFilter        - Replace regex needles with string haystacks in log messages
"""

from datetime import datetime, timezone
from json import dumps as json_dumps
from logging import Filter, Formatter, LogRecord
from re import sub


class JsonLinesFormatter(Formatter):
    """
    Format Logs as JSON lines
    """

    def format(self, record: LogRecord) -> str:
        msg = {
            "function": record.funcName,
            "level": record.levelname,
            "line": record.lineno,
            "logger": record.name,
            "message": record.message,
            "path": record.pathname,
            "thread_name": record.threadName,
            "timestamp": datetime.fromtimestamp(
                record.created, tz=timezone.utc
            ).isoformat(),
        }

        if record.exc_info is not None:
            msg.update({"exc_info": self.formatException(record.exc_info)})

        if record.stack_info is not None:
            msg.update({"stack_info": self.formatStack(record.stack_info)})

        return json_dumps(msg, default=str)


class RegexFilter(Filter):  # pylint: disable=too-few-public-methods
    """
    Replace needles with haystacks
    Args:
        pattern: str - string to search for
        substitute: str - string to insert in place of original
    """

    def __init__(self, pattern: str | None = None, substitute: str | None = None):
        super().__init__()
        self.pattern = pattern
        self.substitute = substitute

    def filter(self, record: LogRecord) -> bool:
        record.msg = sub(self.pattern, self.substitute, record.msg)
        return True
