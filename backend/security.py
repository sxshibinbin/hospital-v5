import os
from datetime import datetime, timedelta
from typing import Optional, Any
from passlib.context import CryptContext
from jose import JWTError, jwt
from cryptography.fernet import Fernet
from dotenv import load_dotenv
from fastapi import HTTPException

load_dotenv()

# JWT configuration
SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError(
        "SECRET_KEY 环境变量未设置。"
        "请生成一个密钥并通过环境变量注入: python -c \"import secrets; print(secrets.token_hex(32))\""
    )
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 120  # 2 hours

# Password policy
PASSWORD_MIN_LENGTH = 8


def validate_password_strength(password: str) -> str:
    """Validate password strength and return the password if valid.

    Requirements:
    - Minimum 8 characters
    - At least one uppercase letter
    - At least one lowercase letter
    - At least one digit
    """
    if len(password) < PASSWORD_MIN_LENGTH:
        raise HTTPException(
            status_code=422,
            detail=f"密码长度不能少于 {PASSWORD_MIN_LENGTH} 个字符",
        )
    if not any(c.isupper() for c in password):
        raise HTTPException(
            status_code=422,
            detail="密码必须包含至少一个大写字母",
        )
    if not any(c.islower() for c in password):
        raise HTTPException(
            status_code=422,
            detail="密码必须包含至少一个小写字母",
        )
    if not any(c.isdigit() for c in password):
        raise HTTPException(
            status_code=422,
            detail="密码必须包含至少一个数字",
        )
    return password


# Password hashing
# Adding truncate_error=False to bypass passlib's strict 72-byte check on bcrypt
pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
    bcrypt__truncate_error=False
)

# AES encryption — 必须通过环境变量 ENCRYPTION_KEY 注入持久密钥。
# 每次部署若密钥不一致，已加密的档案数据将无法解密。
# 生成持久密钥：python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
# 亦可在部署平台（如 CloudBase / Railway / Render）中设为环境变量。
_raw_env_key = os.getenv("ENCRYPTION_KEY")
if not _raw_env_key:
    raise RuntimeError(
        "未设置 ENCRYPTION_KEY 环境变量。"
        "请生成一个持久密钥并通过环境变量注入，切勿使用临时随机密钥，否则每次部署后历史加密数据将无法解密。"
    )
fernet = Fernet(_raw_env_key)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def decode_access_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None

def encrypt_data(data: str) -> str:
    if not data:
        return data
    return fernet.encrypt(data.encode()).decode()

def decrypt_data(encrypted_data: str) -> str:
    if not encrypted_data:
        return encrypted_data
    try:
        return fernet.decrypt(encrypted_data.encode()).decode()
    except Exception:
        return ''
