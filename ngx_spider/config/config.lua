local _M = {}

--请使用和nginx_log_analysis 保持一致的配置
_M.influx_config = {
    host = "",
    database = "",
    port = , --influxdb的HTTP API端口，默认是8086
   }

--是个可读写的redis即可，  qps的大小是根据你每个时间版本需要爬取的url（包含参数，每个版本的url会先 进行去重在爬取）有关。 
_M.redis_conf = {
   host = '',
   port = ,
}

-- 配置爬取访问的Nginx地址，此Nginx是容灾系统的反向代理
_M.proxy_crash_nginx_servers = {
    {
      host = "",
      port = 
    } ,
}

--请配置的和cache_proxy中的config的一致， 作用是更加版本的时间，来定时爬取，如果20分钟一个版本，那么就是20分钟爬取一次全量数据
_M.cache_version_updatetime =  20  -- number

--如果你需要多个爬虫服务，请将其中一台的hostname配置到此处，它是用来检查和更新influxdb的定时任务的
_M.hostname_crond = ''

--配置每次取出的URL数量，取多少就爬取多少。 默认是10秒获取一次url进行爬取，如果下面配置的是1500，就是指10秒内会爬取1500次URL,
--如果你的爬取的数量非常多，请适当加大你的爬取次数，这样可以确保每个版本的数据都是全的。如果规定时间内没有爬取完所有的url，那么请求会进入下一个时间版本继续爬取
_M.rpop_once_total = 1500

-- 请配置的和cache_proxy中的config的一致, 指定爬虫的user-agent， 爬虫是用来更新静态容灾的缓存数据
_M.spider_user_agent =  'static_dt_spider'

--临时文件，用来存放从influxdb导出json数据，数据是URL，供爬取使用
_M.tmp_url_file =  '/tmp/ngx_org_url.json'

return _M

