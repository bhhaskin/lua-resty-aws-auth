package = "lua-resty-aws-auth"
version = "1.0-0"
source = {
   url = "git://github.com/bhhaskin/lua-resty-aws-auth",
   tag = "v1.0-0"
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
