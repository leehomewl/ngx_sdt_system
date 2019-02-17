local ngx     = ngx
local ngx_ERR     = ngx.ERR
local ngx_log  = ngx.log
local ngx_time    = ngx.time
local ngx_var     = ngx.var
local md5     = ngx.md5

local lua_cache_data = ngx.shared.lua_cache_data
local init_config = require "cache_proxy.config.config"
local op_redis = require "cache_proxy.lua_script.module.op_redis"
local nowtime_ver =  lua_cache_data:get('cache_version')
local redis_sharding = ngx_var.redis_sharding


local url = (ngx_var.host or '') .. (ngx_var.request_uri or '')
url = 'sdt_' .. md5(url)
local version = tonumber(ngx.req.get_headers()['need-static-dt-version'])
local cmd =  {'zrem', url, version}
op_redis.pipeline_redis(cmd,redis_sharding)
return ngx.exit(ngx.OK)


