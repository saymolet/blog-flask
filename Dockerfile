FROM python:3.10-slim-buster as app

ENV PYTHONFAULTHANDLER=1 \
  PYTHONUNBUFFERED=1 \
  PYTHONHASHSEED=random \
  PIP_NO_CACHE_DIR=off \
  PIP_DISABLE_PIP_VERSION_CHECK=on \
  PIP_DEFAULT_TIMEOUT=100 \
  POETRY_VERSION=1.3.2

# Install poetry
RUN pip install "poetry==$POETRY_VERSION"
RUN mkdir "/usr/app/"
WORKDIR /usr/app

# Copy only requirements to cache them in docker layer
COPY poetry.lock pyproject.toml /usr/app/

# Install dependencies from pyproject.toml
RUN pip install psycopg2-binary && \
    poetry config virtualenvs.create false && \
    poetry install --no-interaction --no-ansi --no-root
COPY . /usr/app

# install nginx
RUN apt update && \
    apt install nginx=1.14.2-2+deb10u5 -y

# replace config and restart nginx
RUN mv /usr/app/nginx/nginx.conf /etc/nginx/nginx.conf && \
    chmod a+x scripts/docker-entrypoint.sh

EXPOSE 80
CMD ["/bin/sh", "scripts/docker-entrypoint.sh"]
