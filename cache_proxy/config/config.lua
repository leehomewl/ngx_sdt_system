local _M = {}

--支持配置多个redis分片，每个redis需要保证可写，qps较高的网站，可以考虑2个节点以上 ，默认是2个节点， 
--如果使用节点不是2个，请找到 /opt/nginx/lua/cache_proxy/nginx_conf/http_block.conf;
--不仅需要修改redis_sharding，还需要修改split_clients的配置。
_M.redis_sharding = {
    redis_server_1 = {
       host = "",
       port = ,
    },
    redis_server_2 = {
       host = "",
       port = ,
    },
}



-- 用来设置多少分钟一个缓存版本的配置，目前只支持分钟，并且设置的时间必须可以被60整除，比如10,20,15， 如果设置为20，表示每小>时3个版本，1天就是72个版本
_M.cache_version_updatetime = 20  -- number

-- 如果缓存系统的每个时间版本的缓存有效期是多少，就填写多少，单位支持小时，因为是容灾的数据，缓存时间建议不要低于1小时
_M.cache_servers_exprise =  6   -- number 



-- 爬虫的user-agent， 爬虫是用来更新静态容灾的缓存数据
_M.spider_user_agent =  'static_dt_spider'

return _M

