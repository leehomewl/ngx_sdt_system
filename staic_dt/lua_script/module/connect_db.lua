local _M = {}
local init_config = require "staic_dt.config.config"
local ngx = ngx

function  _M.query_mysql(sql)
    local mysql = require "resty.mysql"
    local db, err = mysql:new()

    if not db then
       ngx.log(ngx.ERR,"failed to instantiate mysql: ", err)
       return
    end
    db:set_timeout(3000) --sec 
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

    local ok, err = db:set_keepalive(3000, 5)
    if not ok then
        ngx.log(ngx.ERR,"failed to set keepalive: ", err)
        return
    end
	
    return res
end

return _M

