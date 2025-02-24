FROM openresty/openresty:alpine-fat AS builder

RUN apk --no-cache upgrade && \
    apk --no-cache add openssl && \
    luarocks install lua-resty-openssl && \
    luarocks install luaunit

COPY ./lib/resty/aws_auth.lua /usr/local/openresty/lualib/resty/aws_auth.lua
COPY ./t/test.lua /usr/local/openresty/lualib/resty/aws_auth_tests.lua

RUN resty /usr/local/openresty/lualib/resty/aws_auth_tests.lua | tee test_output.log && \
    grep -q "Failed tests" test_output.log && { echo 'Tests failed'; exit 1; } || exit 0