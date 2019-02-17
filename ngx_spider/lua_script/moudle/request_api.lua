local _M = {}

local http = require "resty.http"
local ngx = require "ngx"
local random = require "resty.random"
local init_config = require "ngx_spider.config.config"


local get_host = function(url)
    local m, err = ngx.re.match(url, "([^/]+)(/.*)$", "jo")
    if not m then
        ngx.log(ngx.ERR,"无法分析此URL的host和url:",url)
        return 
    elseif m[1] and m[2] then
        return m[1],m[2]
    else
        return
        ngx.log(ngx.ERR,"无法分析此URL的host和url:",url)
    end
end

_M.request_url =  function(url)
    local host,request_uri = get_host(url)
    if not host then
        ngx.log(ngx.ERR,"URL拆解失败,没有进行爬取:",url)
        return 
    end
    local ua = init_config.spider_user_agent
    local ngx_server_count = table.getn(init_config.proxy_crash_nginx_servers)
    local random_num = random.number(1,ngx_server_count)
    local ngx_server  =   init_config.proxy_crash_nginx_servers[random_num]
    local httpc = http.new()
    httpc:set_timeout(15000)
    local ok, err = httpc:connect(ngx_server["host"],ngx_server["port"])
    if err then
        local node_num
        for i=ngx_server_count,1,-1 do
            if i ~= random_num then
               node_num = i
               break
            end
        end
        local ngx_server  =  init_config.proxy_crash_nginx_servers[node_num]
   --      ngx.log(ngx.ERR,"请求异常，" , "可能的错误原因：" .. err , "  现在切换到了新的节点: ", ngx_server["host"] .. ":" .. ngx_server["port"])
        local ok, err = httpc:connect(ngx_server["host"],ngx_server["port"])
        if err then
            ngx.log(ngx.ERR,"切换到新的节点，但请求仍然异常，" , "可能的错误原因：" .. err ) 
        end

    end
    local res, err = httpc:request({
        path = request_uri,
        headers = {
            ["Host"] = host,
            ["User-Agent"] = ua,
            ["Accept-Encoding"] = "gzip",
            ["X-Need-Static"] = "1",
            ["X-Zaibei-Flush"]  = "1",
        },
    })
    if not res then
        ngx.log(ngx.ERR, "请求异常，" , "可能的错误原因：" .. err , ngx_server["host"] .. ":" .. ngx_server["port"], " URL是:" .. request_uri)
        return
    end
    if res.status >= 400  then
        ngx.log(ngx.ERR, "爬取异常URL: ", url ," 状态码是:" ,res.status, "  服务器是: " , ngx_server["host"] .. ":" .. ngx_server["port"])
        return
    end
    local reader = res.body_reader

    repeat
    local chunk, err = reader(8192)
    if err then
        ngx.log(ngx.ERR, err)
        break
    end

    if chunk then
    end
    until not chunk

    local ok, err = httpc:set_keepalive(60000,200)
    if not ok then
        ngx.log(ngx.ERR,"failed to set keepalive: ", err)
        return
    end

    return
end

return _M

