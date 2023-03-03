#!/bin/bash

IFS=' ' read -r -a array <<< `poetry version | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g"`; echo "${array[$1]}"