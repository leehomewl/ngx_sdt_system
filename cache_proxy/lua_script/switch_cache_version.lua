local ngx     = ngx
local ngx_ERR     = ngx.ERR
local ngx_log  = ngx.log
local ngx_time    = ngx.time
local ngx_var     = ngx.var
local md5     = ngx.md5

local lua_cache_data = ngx.shared.lua_cache_data
local init_config = require "cache_proxy.config.config"
local op_time_version   = require "cache_proxy.lua_script.op_time_version"
local op_redis = require "cache_proxy.lua_script.module.op_redis"
local nowtime_ver =  lua_cache_data:get('cache_version')

if not nowtime_ver then
   nowtime_ver = op_time_version.get_nowtime_version()
   ngx_log(ngx_ERR,'缓存时间版本是:',nowtime_ver)
end

local url = (ngx_var.host or '') .. (ngx_var.request_uri or '')
url = 'sdt_' .. ngx.md5(url)

local redis_sharding = ngx_var.redis_sharding
local time_ver_h = 60/tonumber(init_config.cache_version_updatetime)
local cache_exist_ver_maximum = init_config.cache_servers_exprise * time_ver_h
local day_all_ver_count = 24 * time_ver_h


local set_ttl = function()
    local expired_ver
    if nowtime_ver > cache_exist_ver_maximum then
        expired_ver = nowtime_ver - cache_exist_ver_maximum
    else
        expired_ver = day_all_ver_count - cache_exist_ver_maximum + nowtime_ver
    end
    return expired_ver
end


if ngx_var.http_user_agent == init_config.spider_user_agent  then  
    local expired_ver = set_ttl()
    
    local cmds = {
        {'zadd', url, nowtime_ver,nowtime_ver},
        {'zrem', url, expired_ver},
        {'expire', url, 21600}
    }
    op_redis.pipeline_redis(cmds,redis_sharding)
    ngx.req.set_header("need-static-dt-version",nowtime_ver)
else 
   --ngx.log(ngx_ERR,ngx_var.http_need_static_dt_version)
   local client_time_ver = tonumber(ngx_var.http_need_static_dt_version)  or nowtime_ver
   if client_time_ver == 0 then
       client_time_ver = nowtime_ver
   end
   local cmd = {'zrange', url , 0, -1}
   local r = op_redis.pipeline_redis(cmd,redis_sharding)
   local n_v = -1
   if type(r) == 'table' then
       if client_time_ver >= cache_exist_ver_maximum then
           ngx_log(ngx_ERR,client_time_ver,'-----',cache_exist_ver_maximum)
           local min_v = client_time_ver - cache_exist_ver_maximum
           for _, k in ipairs(r) do
               k = tonumber(k)
               if k > min_v and k <= client_time_ver and k > n_v then
                   n_v = k
               end
           end
       else
           ngx_log(ngx_ERR,client_time_ver,'xxx-----',cache_exist_ver_maximum)
          local max_v = day_all_ver_count + (client_time_ver - cache_exist_ver_maximum)
          local j = -1
          for _, k in ipairs(r) do
              k = tonumber(k)
              if k > max_v then
                  if k > j then
                      j = k
                  end
              elseif k <= client_time_ver then
                   if k > n_v then
                       n_v = k
                   end
               end
          end

          if n_v == -1 then
               n_v = j
          end
      end

      if n_v > -1 then
          ngx.req.set_header("need-static-dt-version",n_v)
      end

   else
       local expired_ver = set_ttl()
       local cmds = {
          {'zadd', url, nowtime_ver,nowtime_ver},
          {'expire', url, 21600}
       }
       op_redis.pipeline_redis(cmds,redis_sharding)
       ngx.req.set_header("need-static-dt-version",nowtime_ver)
   end

end

