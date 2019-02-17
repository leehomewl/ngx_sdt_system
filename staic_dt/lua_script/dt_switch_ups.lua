local ngx        = ngx
local ngx_var    = ngx.var
local ngx_log    = ngx.log
local get_dt_url = require "staic_dt.lua_script.get_dt_url"
local init_config = require "staic_dt.config.config"

local status     = get_dt_url.get_static_dt_status()
local host       = ngx_var.host
local uri        = ngx_var.uri
local ua         = ngx_var.http_user_agent
local mirror     = ngx_var.http_static_mirror
local need_static_dt_version = ngx_var.http_need_static_dt_version
local switch_percentage
local switch_version 

function switch_ups()
    if not status or status == 0 or  need_static_dt_version  or mirror or ua == init_config.spider_user_agent then
        return ngx.exit(ngx.OK)
    elseif status == 1 then
        switch_percentage  = get_dt_url.find_dt_cache(host,uri,"precise")    
    elseif status == 2 then
        switch_percentage  = get_dt_url.find_dt_cache(host,uri,"regex")
    elseif status == 3 then
        switch_percentage  = get_dt_url.find_dt_cache(host,uri,"wildcard")
    elseif status == 4 then
        switch_percentage  = get_dt_url.find_dt_cache(host,uri,"precise") or get_dt_url.find_dt_cache(host,uri,"regex")
    elseif status == 5 then
        switch_percentage  = get_dt_url.find_dt_cache(host,uri,"precise") or get_dt_url.find_dt_cache(host,uri,"wildcard")
    elseif status == 6 then
        switch_percentage  = get_dt_url.find_dt_cache(host,uri,"regex")   or get_dt_url.find_dt_cache(host,uri,"wildcard")
    elseif status == 7 then
        switch_percentage  = get_dt_url.find_dt_cache(host,uri,"precise") or get_dt_url.find_dt_cache(host,uri,"regex")  or get_dt_url.find_dt_cache(host,uri,"wildcard")
    end

    if  switch_percentage then
        local random = require "resty.random"
        local random_num = random.number(1, 100)
        local switch_percentage  = tonumber(switch_percentage)
        if not switch_percentage then
            ngx_log(ngx.ERR,"请检查MySQL字段switch_percentage是否为number!")
            return ngx.exit(ngx.OK)
        end
        if random_num > switch_percentage  then
             return ngx.exit(ngx.OK)
        end
        ngx.req.set_header("need-static-dt", "yes")
        ngx.req.set_uri("/ups_static_dt",true)
    else 
        return ngx.exit(ngx.OK)
    end
end

switch_ups()
