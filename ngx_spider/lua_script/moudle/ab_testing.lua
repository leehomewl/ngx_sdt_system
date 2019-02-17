local _ab_testing = {}

local http = require "resty.http"
local init_config = require "ngx_spider.config.config"
local ngx = require "ngx"
local op_mysql = require "ngx_spider.lua_script.moudle.op_mysql"

local set_ngx_shared = function(host,uri,uri_type)
    local httpc = http.new()
    httpc:set_timeout(15000)
    local ok, err = httpc:connect(init_config.ab_testing_server["ip"],init_config.ab_testing_server["port"])
    if err then
        ngx.log(ngx.ERR,'无法连接灰度Nginx，请检查此机器是否正常: ' ,err, " Nginx的地址: " ,init_config.ab_testing_server["ip"] .. ":" .. init_config.ab_testing_server["port"])
        return
    end
    local is_reg = 1 
    if uri_type == "precise" then
        is_reg = 0
    end
    local request_uri = "/share_set" .. "?" .. "clear=0&zb_start=1&host=" .. host .. "&uri=" .. uri .. "&is_reg=" .. is_reg .. "&version=-1" 
    local res, err = httpc:request({
        path = request_uri,
        method = "GET",
        headers = {
            ["Host"] = init_config.ab_testing_server["host"],
        },
    })

    if not res then
        ngx.log(ngx.ERR, "请求异常，" , "可能的错误原因：" .. err , "URL是:" .. request_uri)
        return
    end
    if res.status >= 400  then
        ngx.log(ngx.ERR, "请求异常，状态码是:" ,res.status, "可能的错误原因：" .. err)
        return
    end
end


function _ab_testing.push_data()
    sql = "select uri_type,host,uri from nginx_resource where catch_disaster = '1'"
    local res = op_mysql.query_mysql(sql) 
    for i, v  in ipairs(res) do
        local uri_type = ngx.escape_uri(v['uri_type'])
        local uri = ngx.escape_uri(v['uri'])
        local host = ngx.escape_uri(v['host'])
        local ok,err = set_ngx_shared(host,uri,uri_type) 
        if err then
            ngx.log(ngx.ERR,'对灰度Nginx进行共享内存修改时，出现异常: ',err)
        end
    end
    return
end

return _ab_testing


