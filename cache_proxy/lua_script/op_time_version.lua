local _M = {}
local ngx_log     = ngx.log
local ngx_ERR     = ngx.ERR
local ngx_time    = ngx.time
local init_config = require "cache_proxy.config.config"
local lrucache     = require "resty.lrucache"
local lua_cache_data = ngx.shared.lua_cache_data

local op_time_ver = function()
   local timetable = os.date("*t", ngx_time());   -->os.date用法
   local min  = timetable['min']
   local hour = timetable['hour']
   local cache_version_updatetime = init_config.cache_version_updatetime
   local l,f = math.modf(min/cache_version_updatetime)
   local version  =  (60/cache_version_updatetime)*hour  + l
   lua_cache_data:set('cache_version',version,5)
   return version
end

function _M.get_nowtime_version()
   local time_ver 
   time_ver =  lua_cache_data:get('cache_version')
   if time_ver then
      return time_ver
   else
      return op_time_ver() 
   end     
end

return _M
