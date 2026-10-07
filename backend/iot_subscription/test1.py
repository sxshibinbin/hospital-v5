import hashlib
import time
import json
import requests
import urllib.parse

class IoTCloudClient:
    def __init__(self, app_key, app_secret, base_url="https://webapi.nbiotyun.com"):
        self.app_key = app_key
        self.app_secret = app_secret
        self.base_url = base_url.rstrip('/')

    def _generate_signature(self, path, timestamp):
        raw = path + timestamp + self.app_secret
        return hashlib.md5(raw.encode('utf-8')).hexdigest().upper()

    def _build_full_path(self, path, params=None):
        if params:
            query = urllib.parse.urlencode(params)
            return path + '?' + query
        return path

    def request(self, method, path, params=None, data=None):
        full_path = self._build_full_path(path, params)
        url = self.base_url + full_path
        timestamp = str(int(time.time() * 1000))
        signature = self._generate_signature(full_path, timestamp)
        headers = {
            'Content-Type': 'application/json; charset=UTF-8',
            'timestamp': timestamp,
            'appKey': self.app_key,
            'signature': signature,
        }
        body = json.dumps(data) if data is not None else None
        response = requests.request(method, url, headers=headers, data=body)
        return response

    def get(self, path, params=None):
        return self.request('GET', path, params=params)

    def post(self, path, data=None, params=None):
        return self.request('POST', path, params=params, data=data)

# ========== 下面开始实际调用示例 ==========

# 1. 初始化客户端（请替换成您的真实 appKey）
APP_KEY = "yvzjajW6"   # <--- 重要！
APP_SECRET = "47bcf20f7eb76143ef609fb2f7281d71b615c326"

client = IoTCloudClient(APP_KEY, APP_SECRET)

# 2. 调用 POST 接口：查询设备型号列表
path = "/api/v1/dev/get"
data = {
    "deviceImei": "867160071596708",
    "fullFlag": 1
}
response = client.post(path, data=data)

# 3. 输出结果
print("HTTP状态码:", response.status_code)
print("响应内容:", response.text)   # 如果是 JSON，可以用 response.json()