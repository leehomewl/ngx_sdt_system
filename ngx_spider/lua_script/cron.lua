local ngx = require "ngx"
local init_config = require "ngx_spider.config.config"
local init_redis_data = require "ngx_spider.lua_script.moudle.init_redis_data"


local ok, err = ngx.timer.every(10, init_redis_data.rpop_redis)
if not ok then
    ngx.log(ngx.ERR, "failed to create timer: ", err)
    return
end



if 0 == ngx.worker.id() then
    local init_lua_data = ngx.shared.init_lua_data;
    local hostname = init_lua_data:get("hostname")
    if hostname == init_config.hostname_crond then
        local ok, err = ngx.timer.every(init_config.cache_version_updatetime, init_redis_data.lpush_redis)
        if not ok then
            ngx.log(ngx.ERR, "failed to create timer: ", err)
            return
        end
        local ok, err = ngx.timer.every(init_config.ab_testing_init_time,ab_testing.push_data)
        if not ok then
            ngx.log(ngx.ERR, "failed to create timer: ", err)
            return
        end

        local ok, err = ngx.timer.at(0,init_redis_data.lpush_redis)
        if not ok then
            ngx.log(ngx.ERR, "failed to create timer: ", err)
            return
        end  
    end
end

