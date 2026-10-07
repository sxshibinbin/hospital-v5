"""
生产环境 uvicorn 启动入口

使用多 worker 模式、反向代理支持、关闭默认日志。
"""
import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        workers=1,
        proxy_headers=True,
        forwarded_allow_ips="*",
        timeout_keep_alive=65,
        limit_concurrency=100,
        log_config=None,
        access_log=False,
    )
