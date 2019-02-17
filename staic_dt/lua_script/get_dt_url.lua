local _M = {}

local ngx          = ngx
local ngx_log      = ngx.log
local ngx_ERR      = ngx.ERR
local lrucache     = require "resty.lrucache"
local init_config  = require "staic_dt.config.config"
local connect_db   = require "staic_dt.lua_script.module.connect_db"
local dump_list    = init_config.dump_staic_dt_status_list 
local ttl          = init_config.update_cache_time + 2
local static_dt_url_list = ngx.shared.static_dt_url_list
local static_dt_url_list_version = ngx.shared.static_dt_url_list_version


local static_dt_status, err = lrucache.new(5)
if not static_dt_status then
    ngx_log(ngx_ERR,"failed to create the cache: " .. err or "unknown")
end

local host_list, err = lrucache.new(1000)
if not host_list then
    ngx_log(ngx_ERR,"failed to create the cache: " .. err or "unknown")
end

local static_dt_uri_precise, err = lrucache.new(init_config.uri_precise_maximum)
if not static_dt_uri_precise then
    ngx_log(ngx_ERR,"failed to create the cache: " .. err or "unknown")
end

local static_dt_uri_regex, err = lrucache.new(init_config.uri_regex_maximum)
if not static_dt_uri_regex then
    ngx_log(ngx_ERR,"failed to create the cache: " .. err or "unknown")
end

local static_dt_uri_wildcard, err = lrucache.new(init_config.uri_wildcard_maximum)
if not static_dt_uri_wildcard then
    ngx_log(ngx_ERR,"failed to create the cache: " .. err or "unknown")
end

local uri_all_maximum = init_config.uri_precise_maximum + init_config.uri_regex_maximum + init_config.uri_wildcard_maximum
local static_dt_uri_version, err = lrucache.new(uri_all_maximum)
if not static_dt_uri_version then
    ngx_log(ngx_ERR,"failed to create the cache: " .. err or "unknown")
end

function _M.get_static_dt_status()
     return  static_dt_status:get("status")
end

function _M.get_host_list(host)
    return host_list:get(host)
end

local to_table = function(host,uri,uri_type,switch_percentage,uri_regex,uri_wildcard)
    host_list:set(host,1,ttl)
    if uri_type == "precise" then
        static_dt_uri_precise:set(host .. uri,switch_percentage,ttl)
    elseif uri_type == "regex" then
        if uri_regex[host] then
            table.insert(uri_regex[host],{uri,switch_percentage})
        else
            uri_regex[host] = {}
            table.insert(uri_regex[host],{uri,switch_percentage})
        end
    elseif  uri_type == "wildcard" then
        if uri_wildcard[host] then
            table.insert(uri_wildcard[host],{uri,switch_percentage})
        else
            uri_wildcard[host] = {}
            table.insert(uri_wildcard[host],{uri,switch_percentage})
        end
    end
    return 
end

function _M.find_dt_cache(host,uri,uri_type)
    local list = {} 
    local switch_percentage 
    local switch_version = 0  
    local host_uri = host .. uri 
    if uri_type == 'precise' then
        switch_percentage = static_dt_uri_precise:get(host_uri)
        switch_version    = static_dt_uri_version:get(host_uri) 
        ngx.req.set_header("need-static-dt-version",switch_version)
        return switch_percentage
    elseif uri_type == 'regex' then
        list = static_dt_uri_regex:get(host)
    else 
        list = static_dt_uri_wildcard:get(host)
    end
    if list then
        for key, value_uri in pairs(list) do
            local m, err  = ngx.re.find(uri , value_uri[1],"jo")
            if m then
                switch_percentage = value_uri[2]
                switch_version    = static_dt_uri_version:get(host .. value_uri[1]) 
                ngx.req.set_header("need-static-dt-version",switch_version)
                break
            end
         end
    end
    return switch_percentage
end


local dt_status =  function(uri_type_list)
    local precise = uri_type_list['precise']
    local regex = uri_type_list['regex']
    local wildcard = uri_type_list['wildcard']
    --只存在精确存在容灾  
    if precise and not regex and not wildcard then
       return 1 
    --只存在正则存在容灾
    elseif not precise and regex and not wildcard then
       return 2
    --只存在目录存在容灾
    elseif not precise and not regex and wildcard then
       return 3
    --只存在精确和正则容灾
    elseif precise and regex and not wildcard then
       return 4
    --只存在精确和目录容灾
    elseif precise and not regex and wildcard then
       return 5
    --只存在正则和目录容灾
    elseif not precise and regex and wildcard then
       return 6
    --精确和正则和目录都存在
    elseif precise and regex and wildcard then
       return 7
    else 
       ngx_log(ngx_ERR,'没有发现可以容灾的服务: ',table.concat(uri_type_list,","))
       return 0 
    end
end 

local shard_setto_lrucache = function()
    local uri_regex = {}
    local uri_wildcard = {}
    local uri_type_list = {}

    local keys = static_dt_url_list:get_keys(0)
    if next(keys)  then
        for k,v in pairs(keys) do
            local m,err = ngx.re.match(v, "(.+)--dt--(precise|regex|wildcard)(.+)--dt--([0-9]+)","oj")
            --ngx_log(ngx_ERR,m[1],'-----',m[2],'-----',m[3],'----',m[4])
            local uri               = m[1]
            local host              = m[3]
            local uri_type          = m[2]
            local switch_percentage = m[4]
            uri_type_list[uri_type] = true 
            to_table(host,uri,uri_type,switch_percentage,uri_regex,uri_wildcard)
        end 
    else 
        return
    end
    local status = dt_status(uri_type_list)
    static_dt_status:set("status",status)
    if status == 0 then
        return
    end
    for k in pairs(uri_regex) do
        static_dt_uri_regex:set(k,uri_regex[k],ttl)
    end
    for k in pairs(uri_wildcard) do
        static_dt_uri_wildcard:set(k,uri_wildcard[k],ttl)
    end
    local keys = static_dt_url_list_version:get_keys(0)
    if next(keys)  then
        for k,v in pairs(keys) do
            static_dt_uri_version:set(v ,static_dt_url_list_version:get(v)) 
        end
    else
       ngx_log(ngx_ERR,'容灾服务没有提供对应的时间版本，请注意！！！')
    end

    return 
end
function _M.set_cache()
    local uri_regex = {}
    local uri_wildcard = {}
    local shard_uri_list = {}
    local uri_type_list = {}
    local sql = 'select uri_type,host,uri,switch_percentage,switch_version from nginx_var_information where dt_status != 0 and dt_status is not null;'
    local res = connect_db.query_mysql(sql)
    if  not  res  then
        ngx_log(ngx_ERR,'读取MySQL异常，请检查!!!')
        shard_setto_lrucache()
        return
    end
    if not next(res) then
        ngx_log(ngx_ERR,"数据为空，mysql查询不到!!")
        static_dt_status:set("status",0)
        static_dt_url_list:flush_all()
        static_dt_url_list:flush_all()

        return
    end
    if  0 == ngx.worker.id() then
        static_dt_url_list:flush_all()
        static_dt_url_list:flush_all()
        for i, one  in ipairs(res) do
            local uri_type =  one['uri_type']
            local uri = one['uri']
            local host = one['host']
            local switch_version = one['switch_version']
            local switch_percentage = one['switch_percentage']
            if not  switch_percentage  or switch_percentage == '' or switch_percentage == 'NULL' then
               switch_percentage = '100%'
            end
    --        ngx_log(ngx_ERR,'---------',host .. uri .. switch_version)
            static_dt_url_list_version:set(host .. uri ,switch_version)
            static_dt_url_list:set(uri .. '--dt--' .. uri_type .. host  .. '--dt--' ..  switch_percentage,1)
        end
    end
    shard_setto_lrucache()

    return true 
end

return _M

