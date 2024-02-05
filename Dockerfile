FROM alpine:3.19.1 AS base

FROM base AS build

RUN apk update && apk add gcc libc-dev python3-dev py3-pip

RUN python3 -m venv --copies /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

ADD requirements.txt .
RUN pip install -r requirements.txt

FROM base AS runtime

RUN apk update && apk add python3-dev

RUN adduser -D flask
RUN mkdir -p /var/log/flask && chown -R flask:flask /var/log/flask
USER flask
WORKDIR /home/flask
ADD . .

COPY --from=build /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

ENV FLASK_PORT=5000
ENV GUNICORN_THREADS=8
ENV GUNICORN_WORKERS=2

CMD gunicorn -b=0.0.0.0:${FLASK_PORT} -w=${GUNICORN_WORKERS} -t=${GUNICORN_THREADS} src.wsgi:app
