local _M = {}
local init_config = require "staic_dt.config.config"
local get_dt_url = require "staic_dt.lua_script.get_dt_url"
local ngx = ngx

function _M.set_dt_cache()
    
    if init_config.update_cache_time < 3 then
        return
        ngx.log(ngx.ERR,'update_cache_time的配置不能小于3秒，请设置在3秒以上，减少对后端MYSQL的查询!')

    end

    local ok, err = ngx.timer.at(0, get_dt_url.set_cache)
    if not ok then
        ngx.log(ngx.ERR, "failed to create timer: ", err)
        return
    end

    local ok, err = ngx.timer.every(init_config.update_cache_time, get_dt_url.set_cache)
    if not ok then
        ngx.log(ngx.ERR, "failed to create timer: ", err)
        return
    end
end

return _M

