import hashlib
import time

# ===== 请替换为您的真实信息 =====
app_key = "yvzjajW6"          # 由平台提供
app_secret = "47bcf20f7eb76143ef609fb2f7281d71b615c326"
path = "/api/v1/dev/get"      # 请求的接口路径
# ================================

# 生成当前13位毫秒时间戳
timestamp = str(int(time.time() * 1000))

# 拼接并计算MD5（大写）
raw = path + timestamp + app_secret
signature = hashlib.md5(raw.encode('utf-8')).hexdigest().upper()

# 输出结果
print("timestamp:", timestamp)
print("signature:", signature)