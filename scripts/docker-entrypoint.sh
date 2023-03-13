#!/bin/sh

service nginx restart
gunicorn -w 4 app:app
