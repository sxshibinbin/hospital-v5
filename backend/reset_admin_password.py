import asyncio
import sys
from db_encryption import phone_lookup_hash
from security import get_password_hash
from database import AsyncSessionLocal, DATABASE_URL
from models import User
from sqlalchemy.future import select


async def list_admins():
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(User).where(User.is_admin == True)
        )
        admins = result.scalars().all()
        if not admins:
            print("错误：系统中没有管理员账号。")
            print("提示：请先访问管理端页面进行首次初始化设置。")
            return []
        print("\n当前管理员列表：")
        for i, admin in enumerate(admins):
            print(f"  [{i + 1}] 账号: {admin.phone}  |  名称: {admin.display_name or '未设置'}")
        return admins


async def reset_password(phone: str, new_password: str):
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(User).where(
                User.phone_hash == phone_lookup_hash(phone),
                User.is_admin == True,
            )
        )
        admin = result.scalars().first()
        if not admin:
            result = await db.execute(
                select(User).where(User.is_admin == True, User.phone_hash.is_(None))
            )
            for candidate in result.scalars().all():
                if candidate.phone == phone:
                    admin = candidate
                    admin.phone_hash = phone_lookup_hash(phone)
                    break
        if not admin:
            print(f"错误：未找到管理员账号 '{phone}'")
            return False

        admin.hashed_password = get_password_hash(new_password)
        await db.commit()
        print(f"\n成功重置管理员 '{admin.phone}' 的密码。")
        print(f"新密码: {new_password}")
        print("请妥善保管新密码。")
        return True


async def main():
    args = sys.argv[1:]

    if len(args) == 0:
        # Interactive mode
        print("=" * 50)
        print("  管理员密码重置工具")
        print(f"  数据库: {DATABASE_URL}")
        print("=" * 50)

        admins = await list_admins()
        if not admins:
            return

        if len(admins) == 1:
            target_phone = admins[0].phone
            confirm = input(f"\n将重置管理员 '{target_phone}' 的密码，确认？[y/N]: ")
            if confirm.lower() != 'y':
                print("已取消。")
                return
        else:
            choice = input(f"\n请选择要重置的管理员编号 [1-{len(admins)}]: ")
            try:
                idx = int(choice) - 1
                if idx < 0 or idx >= len(admins):
                    print("无效选择。")
                    return
                target_phone = admins[idx].phone
            except ValueError:
                print("无效输入。")
                return

        new_password = input("请输入新密码: ").strip()
        if not new_password:
            print("密码不能为空。")
            return
        if len(new_password) < 6:
            print("密码长度不能少于6位。")
            return
        confirm_pw = input("请再次输入新密码: ").strip()
        if new_password != confirm_pw:
            print("两次输入的密码不一致。")
            return

        await reset_password(target_phone, new_password)

    elif len(args) == 2:
        # Non-interactive mode: phone new_password
        phone = args[0]
        new_password = args[1]
        await reset_password(phone, new_password)

    else:
        print("用法：")
        print("  交互模式:   python reset_admin_password.py")
        print("  命令行模式: python reset_admin_password.py <管理员账号> <新密码>")

if __name__ == "__main__":
    asyncio.run(main())
