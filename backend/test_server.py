"""
IoT 订阅接口服务器
包含数据库连接和文件监听，接收推送并存入数据库
"""
import asyncio
import uvicorn
from contextlib import asynccontextmanager
from fastapi import FastAPI
from iot_subscription.router import router as iot_router, log_writer
from iot_subscription.database import init_pool, close_pool
from iot_subscription.file_monitor import file_monitor_loop


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_pool()
    monitor_task = asyncio.create_task(file_monitor_loop())
    yield
    monitor_task.cancel()
    log_writer.close()
    close_pool()


app = FastAPI(title="IoT Subscription Server", lifespan=lifespan)
app.include_router(iot_router)


if __name__ == "__main__":
    uvicorn.run("test_server:app", host="0.0.0.0", port=8003, reload=True)
