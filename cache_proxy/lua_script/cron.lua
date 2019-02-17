local ngx         = ngx
local ngx_log     = ngx.log
local ngx_ERR     = ngx.ERR
local ngx_var     = ngx.var
local op_time_version        = require "cache_proxy.lua_script.op_time_version"
local init_config = require "cache_proxy.config.config"

function get_nowtime_cache_version()
    local cache_version_updatetime =  init_config.cache_version_updatetime

    if  60%cache_version_updatetime ~=0 then
        ngx_log(ngx_ERR,'缓存的时间版本分钟是:'  .. cache_version_updatetime  .. ' 无法被60整除，请重新配置 cache_version_updatetime !')
        return 
    end
    if 0 == ngx.worker.id() then
        local ok, err = ngx.timer.at(0,op_time_version.get_nowtime_version)
         if not ok then
            ngx_log(ngx_ERR, "failed to create the timer: ", err)
            return
        end
        local ok, err = ngx.timer.every(3,op_time_version.get_nowtime_version)
        if not ok then
            ngx_log(ngx_ERR, "failed to create the timer: ", err)
            return
        end
    end
end

get_nowtime_cache_version()
