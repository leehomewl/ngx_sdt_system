local utils = require "ngx_spider.lua_script.moudle.utils"
local init_lua_data = ngx.shared.init_lua_data;
local hostname = utils.hostname()
init_lua_data:set("hostname", hostname)
ngx.log(ngx.STDERR,'The hostname is  :' ,init_lua_data:get("hostname"))

