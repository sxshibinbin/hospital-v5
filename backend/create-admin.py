import asyncio
from database import AsyncSessionLocal
from db_encryption import phone_lookup_hash
from models import User
from security import get_password_hash

async def create_superuser():
    async with AsyncSessionLocal() as db:
        # 1. 检查是否已经存在
        from sqlalchemy.future import select
        result = await db.execute(select(User).where(User.phone_hash == phone_lookup_hash("admin")))
        user = result.scalars().first()
        if not user:
            result = await db.execute(select(User).where(User.is_admin == True))
            for candidate in result.scalars().all():
                if candidate.phone == "admin":
                    user = candidate
                    user.phone_hash = phone_lookup_hash("admin")
                    db.add(user)
                    await db.commit()
                    break
        
        if user:
            print("Admin user already exists!")
            return

        # 2. 创建管理员对象，注意这里调用了 get_password_hash 来加密 "admin123"
        admin_user = User(
            phone="admin",  # 登录账号
            phone_hash=phone_lookup_hash("admin"),
            display_name="超级管理员",
            hashed_password=get_password_hash("admin123"), # 加密密码
            is_admin=True,  # 关键：设置为管理员权限
        )
        
        # 3. 存入数据库
        db.add(admin_user)
        await db.commit()
        print("Successfully created admin user with password 'admin123'")

if __name__ == "__main__":
    asyncio.run(create_superuser())
