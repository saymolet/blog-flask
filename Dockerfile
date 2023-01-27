FROM python:3.10-slim-buster

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

EXPOSE 5000
CMD python -m flask run --host=0.0.0.0
