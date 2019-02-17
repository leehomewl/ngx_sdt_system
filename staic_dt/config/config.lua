local _M = {}

_M.mysql_config = {
    -- 请配置的和nginx_log_analysis系统的mysql一致
    host = "",
    port = ,
    database = "",
    user = "",
    password = "",
    charset = "utf8",
    max_packet_size = 2048 * 2048
}


-- 同时允许最大数量的精确url服务进入容灾系统:
_M.uri_precise_maximum = 500

-- 同时允许最大数量的正则url服务进入容灾系统:
_M.uri_regex_maximum = 100

-- 同时允许最大数量的目录url服务进入容灾系统:
_M.uri_wildcard_maximum = 100

-- 爬虫的user-agent， 爬虫是用来更新静态容灾的缓存数据
_M.spider_user_agent =  'static_dt_spider'

--设置从MYSQL读取URL属性的间隔时间，单位秒。
_M.update_cache_time = 10   -- 秒，number

return _M
