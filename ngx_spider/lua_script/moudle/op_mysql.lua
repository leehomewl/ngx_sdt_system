local _M = {}
 
_M.query_mysql = function(sql)
    local init_config = require "ngx_spider.config.config"
    local ngx = require "ngx"
    local mysql = require "resty.mysql"
    local db, err = mysql:new()
    if not db then
       ngx.log(ngx.ERR,"failed to instantiate mysql: ", err)
       return
    end
    db:set_timeout(10000) --sec
    local ok, err, errcode, sqlstate = db:connect(init_config.mysql_config)
    if not ok then
        ngx.log(ngx.ERR,"failed to connect MySQL: ", err, ": ", errcode, " ", sqlstate)
        return
    end
    local   res, err, errcode, sqlstate =
        db:query(sql)
    if not res then
        ngx.log(ngx.ERR,"bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
        return
    end
    
    local ok, err = db:set_keepalive(240000, 10)
    if not ok then
        ngx.log(ngx.ERR,"failed to set keepalive: ", err)
        return
    end
 
    return res
end


return _M
