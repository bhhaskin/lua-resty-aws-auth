-- generate amazon v4 authorization signature
-- https://docs.aws.amazon.com/general/latest/gr/signature-version-4.html
-- Licence: MIT

local openssl_hmac = require "resty.openssl.hmac"
local openssl_digest = require "resty.openssl.digest"
local str = require "resty.string"

local _M = {
  _VERSION = '0.2.0'
}

local mt = { __index = _M }

-- Initialize new AWS auth instance
function _M.new(self, config)
  local instance = setmetatable({}, mt)  -- Create a new table for the instance

  instance.aws_key     = config.aws_key
  instance.aws_secret  = config.aws_secret
  instance.aws_stoken  = config.aws_secret_token 
  instance.aws_region  = config.aws_region
  instance.aws_service = config.aws_service
  instance.aws_host    = config.aws_host
  instance.cont_type   = config.content_type or "application/x-www-form-urlencoded"  -- Ensure content-type
  instance.req_method  = config.request_method or "POST"
  instance.req_path    = config.request_path   or "/"
  instance.req_body    = config.request_body or ""  -- Ensure req_body is never nil
  instance.req_querystr = config.request_querystr or ""

  -- Set default time
  instance:set_iso_date(ngx.time())

  return instance
end

-- Required for testing
function _M.set_iso_date(self, microtime)
  self.iso_date = os.date('!%Y%m%d', microtime)
  self.iso_tz   = os.date('!%Y%m%dT%H%M%SZ', microtime)
end

-- Generate SHA256 digest
function _M.get_sha256_digest(self, s)
  if type(s) == "table" then
    s = ngx.encode_args(s)  -- Convert table to URL-encoded string
  end
  local digest = openssl_digest.new("sha256")
  digest:update(s or "")  -- Ensure empty string if nil
  return str.to_hex(digest:final())
end

-- Generate HMAC-SHA256
function _M.hmac(self, secret, message)
  local hmac, err = openssl_hmac.new(secret, "sha256")
  if not hmac then
    error("Failed to create HMAC: " .. err)
  end
  hmac:update(message)
  return hmac:final()
end

-- Get signing key
function _M.get_signing_key(self)
  local k_date    = self:hmac('AWS4' .. self.aws_secret, self.iso_date)
  local k_region  = self:hmac(k_date, self.aws_region)
  local k_service = self:hmac(k_region, self.aws_service)
  local k_signing = self:hmac(k_service, 'aws4_request')
  return k_signing
end

-- Create canonical headers
function _M.get_canonical_header(self)
  local h = {}

  if self.cont_type and self.cont_type ~= "" then
    table.insert(h, "content-type:" .. self.cont_type)
  end

  table.insert(h, "host:" .. self.aws_host)
  table.insert(h, "x-amz-date:" .. self.iso_tz)

  if self.aws_stoken and self.aws_stoken ~= "" then
    table.insert(h, "x-amz-security-token:" .. self.aws_stoken)
  end

  return table.concat(h, '\n')
end

-- Create signed headers
function _M.get_signed_header(self)
  local signed_header = {}

  if self.cont_type and self.cont_type ~= "" then
    table.insert(signed_header, "content-type")
  end

  table.insert(signed_header, "host")
  table.insert(signed_header, "x-amz-date")

  if self.aws_stoken and self.aws_stoken ~= "" then
    table.insert(signed_header, "x-amz-security-token")
  end

  return table.concat(signed_header, ";")
end

-- Get canonical request
function _M.get_canonical_request(self)
  local signed_header = self:get_signed_header()
  local canonical_header = self:get_canonical_header()
  local signed_body = self:get_signed_request_body()
  
  local param = {
    self.req_method,
    self.req_path,
    "",  -- Empty canonical query string
    canonical_header,
    "",  -- Required empty line
    signed_header,
    signed_body
  }

  local canonical_request = table.concat(param, '\n')
  return self:get_sha256_digest(canonical_request)
end

-- Get signed request body
function _M.get_signed_request_body(self)
  local body = self.req_body or ""

  if type(body) == "table" then
    local sorted_keys = {}
    for k in pairs(body) do
      table.insert(sorted_keys, k)
    end
    table.sort(sorted_keys)

    local sorted_body = {}
    for _, k in ipairs(sorted_keys) do
      table.insert(sorted_body, ngx.escape_uri(k) .. "=" .. ngx.escape_uri(body[k]))
    end

    body = table.concat(sorted_body, "&")  -- AWS requires sorted query string format
  end

  return string.lower(self:get_sha256_digest(body))
end

-- Get string to sign
function _M.get_string_to_sign(self)
  local param = { self.iso_date, self.aws_region, self.aws_service, 'aws4_request' }
  local cred  = table.concat(param, '/')
  local req   = self:get_canonical_request()
  return table.concat({ 'AWS4-HMAC-SHA256', self.iso_tz, cred, req }, '\n')
end

-- Generate signature
function _M.get_signature(self)
  local signing_key = self:get_signing_key()
  local string_to_sign = self:get_string_to_sign()
  return str.to_hex(self:hmac(signing_key, string_to_sign))
end

-- Get authorization header
function _M.get_authorization_header(self)
  local param = { self.aws_key, self.iso_date, self.aws_region, self.aws_service, 'aws4_request' }
  local header = {
    'AWS4-HMAC-SHA256 Credential=' .. table.concat(param, '/'),
    'SignedHeaders=' .. self:get_signed_header(),
    'Signature=' .. self:get_signature()
  }
  return table.concat(header, ', ')
end

return _M