#!/bin/bash

curl -sv localhost:80/api/comment/new -X POST -H 'Content-Type: application/json' -d '{"email":"test@test","comment":"I am alive!!!","content_id":99}'

curl -sv localhost:8000/api/comment/list/99
