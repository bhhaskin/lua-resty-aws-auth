package = "lua-resty-aws-auth"
version = "1.0-0"
source = {
   url = "https://github.com/bhhaskin/lua-resty-aws-auth/archive/refs/tags/v1.0.0.tar.gz",
   tag = "3b833ea30da4202a97b441d2ea9b3e8e9fcd0c6f8a8b6cc3758cd7b09d4aaaff"
}
description = {
   summary  = "Lua resty module to calculate AWS signature v4 authorization header",
   homepage = "https://github.com/bhhaskin/lua-resty-aws-auth",
   license  = "MIT",
   maintainer = "Bryan Haskin <bhhaskin@bitsofsimplicity.com>"
}
dependencies = {
   "lua >= 5.1",
   "lua-resty-openssl"
}
build = {
   type = "builtin",
   modules = {
      ["resty.aws_auth"] = "lib/resty/aws_auth.lua",
   }
}
