from datetime import datetime, timezone
from json import dumps as json_dumps
from logging import Filter, Formatter, LogRecord
from re import sub


class JsonLinesFormatter(Formatter):
    def format(self, record: LogRecord) -> str:
        msg = {
            "message": record.getMessage(),
            "timestamp": datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat(),
            "path": record.pathname,
            "level": record.levelname,
            "message": record.message,
            "logger": record.name,
            "function": record.funcName,
            "line": record.lineno,
            "thread_name": record.threadName,
        }

        if record.exc_info is not None:
            msg.update({"exc_info": self.formatException(record.exc_info)})

        if record.stack_info is not None:
            msg.update({"stack_info": self.formatStack(record.stack_info)})

        return json_dumps(msg, default=str)


class RegexFilter(Filter):
    def __init__(self, pattern: str | None = None, substitute: str | None = None):
        super().__init__()
        self.pattern = pattern
        self.substitute = substitute

    def filter(self, record: LogRecord) -> bool:
        record.msg = sub(self.pattern, self.substitute, record.msg)
        return True
