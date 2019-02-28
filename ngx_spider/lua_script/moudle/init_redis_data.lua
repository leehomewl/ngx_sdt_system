spider = {}

local ngx = require "ngx"
local cjson = require "cjson"
local redis = require "resty.redis"
local config = require "ngx_spider.config.config"

local request_api = require "ngx_spider.lua_script.moudle.request_api"
local redis = require "resty.redis"

local init_lua_data = ngx.shared.init_lua_data;

local tmp_file = config['tmp_url_file']

local redis_inint = function()
    local red = redis:new()
    red:set_timeout(20000)   
    local ok, err = red:connect(config.redis_conf['host'],config.redis_conf['port'])
    if not ok then
        ngx.log(ngx.ERR,"failed to connect: " ..  err)
        return false,"failed to authenticate: " .. err
    end
    if config.redis_conf['passwd'] then
        local res, err = red:auth(config.redis_conf['passwd'])
        if not res then
          ngx.log(ngx.ERR,"failed to authenticate: " ..  err)
          return false,"failed to authenticate: " .. err 
        end
    end
    return true
end


local insert_redis = function()

    --local cmd = string.format([[influx -database "%s"   -execute "select distinct(org_url)  from nginx where time > now()-%sm and status != '404' and status != '403'  and org_url != '' and varnish_ttl = 'null' and http_user_agent != '%s'" -format "json"  > %s -host='%s'  -port='%s' ]] ,config.influx_config['database'],config['cache_version_updatetime'],config['spider_user_agent'],tmp_file,config.influx_config['host'],config.influx_config['port'])
    local cmd = string.format([[influx -database "%s"   -execute "select distinct(org_url)  from nginx where time > now()-%sm and status != '404' and status != '403'  and org_url != '' and http_user_agent != '%s'" -format "json"  > %s -host='%s'  -port='%s' ]] ,config.influx_config['database'],config['cache_version_updatetime'],config['spider_user_agent'],tmp_file,config.influx_config['host'],config.influx_config['port'])

    local f = assert(io.popen(cmd, 'r'))
    local f_res = f:read("*a")
    f:close()
    local m = ngx.re.match(f_res,"\\w")
    if m  then
        ngx.log(ngx.ERR,"导出influxdb数据异常，原因可能是: " .. f_res)
        return  "导出influxdb数据异常，原因可能是: " .. f_res
    end

    local red = redis:new()
    red:set_timeout(20000)
    local ok, err = red:connect(config.redis_conf['host'],config.redis_conf['port'])
    if not ok then
        ngx.log(ngx.ERR,"failed to connect: " ..  err)
        return false,"failed to authenticate: " .. err
    end
    if config.redis_conf['passwd'] then
        local res, err = red:auth(config.redis_conf['passwd'])
        if not res then
          ngx.log(ngx.ERR,"failed to authenticate: " ..  err)
          return false,"failed to authenticate: " .. err
        end
    end
    local file = io.open(tmp_file),'r'
    local data = file:read("*a")
    file:close()
    local data_table = cjson.decode(data)
    --local url_table =  data_table["results"][1]["series"][1]["values"] 
    local url_table =  data_table["results"]
    local n = 0
    for k,v in ipairs(url_table) do
        if not v["series"] or not v["series"][1]["values"]  then
            ngx.log(ngx.ERR,"influxdb导出的数据异常，请检查:" ,tmp_file)
            ngx.exit(500)
        end
        for i,data in ipairs(v["series"][1]["values"]) do
        
                local ok, err = red:lpush("spider_url", data[2])
                if not ok then
                    local ok,err = red:lpush("spider_url", data[2])
                    if not ok then
                        ngx.log(ngx.ERR,"failed to set spider_url: ", err)
                    end
                end
                n = n + 1
         end
    end
    ngx.log(ngx.ERR,n)
    local ok, err = red:set_keepalive(200000, 20)
    if not ok then
        ngx.log(ngx.ERR,"failed to set keepalive: ", err)
    end
    init_lua_data:delete("insert_redis_key_spdier")
    ngx.log(ngx.ERR,"数据已经导入redis!")
    return 'ok'
end

function spider.lpush_redis()
    local resty_lock = require "resty.lock"
    local lua_locks = ngx.shared.lua_locks
  
    local key = 'insert_redis'
    local lock, err = resty_lock:new("lua_locks")
    if not lock then
         ngx.log(ngx.ERR,"failed to create lock: ", err)
        return
    end
    local elapsed, err = lock:lock(key)
    if not elapsed then
        ngx.log(ngx.ERR,"failed to acquire the lock: ", err)
        return
    end
    local ok,err = insert_redis()
    local lock_ok, lock_err = lock:unlock()
    if not lock_ok then
        ngx.log(ngx.ERR,"failed to unlock: ", lock_err)
        return
    end
    if err then
         return  err
    end
    return 'lpush redis ok!'
end

local url = '' 
local spawn_op = function()
    request_api.request_url(url)
end

function spider.rpop_redis()

    local red = redis:new()
    red:set_timeout(2000)
    local ok, err = red:connect(config.redis_conf['host'],config.redis_conf['port'])
    if not ok then
        ngx.log(ngx.ERR,"failed to connect: " ..  err)
        return false,"failed to authenticate: " .. err
    end
    if config.redis_conf['passwd'] then
        local res, err = red:auth(config.redis_conf['passwd'])
        if not res then
          ngx.log(ngx.ERR,"failed to authenticate: " ..  err)
          return false,"failed to authenticate: " .. err
        end
    end

    local spawn = ngx.thread.spawn
    local wait = ngx.thread.wait

       local threads = { }
       local rpop_count = config.rpop_once_total 
       local init_again = 0
       local sleep_threshold = 0
       for  i=1, rpop_count do
 
                 init_again = init_again +1
                local ok , err = red:rpop("spider_url")
                if not ok then
                    ngx.log(ngx.ERR,"failed to set spider_url: ", err)
                    return
                elseif tostring(ok) == "userdata: NULL" then
                    sleep_threshold = sleep_threshold +1 
                    if sleep_threshold > 10 then
                         ngx.log(ngx.ERR,'从redis读取数据为空，休息一会在读取')
                         ngx.sleep(5)
                         return 
                         --ngx.exit(ngx.HTTP_OK)
                    end
                else
                    url = tostring(ok)
                    ngx.sleep(0.01)
                    spawn(spawn_op)
                    if init_again == 30 then
                        ngx.sleep(0.3)
                        init_again = 0
                    end
                end
       end


                local ok, err = red:set_keepalive(10000, 100)
                if not ok then
                    ngx.log(ngx.ERR,"failed to set keepalive: ", err)
                    return
                end

end




return spider
