local _M = {}
local init_config = require "cache_proxy.config.config"
local ngx_log     = ngx.log
local ngx_ERR     = ngx.ERR

local redis = require "resty.redis"


local  exec_red_cmd  = function(rd_obj,cmd)
  if cmd[1] == 'zrange' then
    return rd_obj:zrange(unpack(cmd, 2))
  elseif cmd[1] == 'zadd' then
    return rd_obj:zadd(unpack(cmd, 2))
  elseif cmd[1] == 'zrem' then
    return rd_obj:zrem(unpack(cmd, 2))
  elseif cmd[1] == 'expire' then
    return rd_obj:expire(unpack(cmd, 2))
  end

  ngx_log(ngx_ERR, 'unknown redis cmd: ', tostring(cmd[1]))
  return nil

end


function  _M.pipeline_redis(cmds,redis_sharding)
    local red = redis:new()
    if not red then
       ngx_log(ngx_ERR,"failed to instantiate redis: ", err)
       return
    end
    red:set_timeout(1000) 

    local ok, err = red:connect(init_config.redis_sharding[redis_sharding]['host'],init_config.redis_sharding[redis_sharding]['port'])
    
    if not ok then
      ngx_log(ngx_ERR,'can not connect redis: ',err)
      return nil
    end
    
    if type(cmds[1]) == "table" then
        red:init_pipeline()
        for _, cur_cmd in ipairs(cmds) do
--            ngx.log(ngx.ERR,table.concat(cur_cmd,"---"))
           exec_red_cmd(red, cur_cmd)
        end
        
        local results, err = red:commit_pipeline()
        if not results then
            ngx_log(ngx_ERR,"failed to commit the pipelined requests: ", err)
            return
        end
        
        for i, res in ipairs(results) do
            if type(res) == "table" then
                if res[1] == false then
                    ngx_log(ngx_ERR,"failed to run command ", i, ": ", res[2])
                end
            end
        end
    else
        local res, err = exec_red_cmd(red,cmds)
        if type(res) == "table" and res[1] then
             return res
        end
        return
    end

     
 

    local ok, err = red:set_keepalive(3000, 100)
    if not ok then
        ngx_log(ngx_ERR,"failed to set keepalive: ", err)
        return
    end

end

return _M
