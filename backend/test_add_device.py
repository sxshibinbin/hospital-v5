import os

import requests


base_url = os.getenv("HOSPITAL_API_BASE_URL", "http://localhost:8000").rstrip("/")
token = os.getenv("HOSPITAL_AUTH_TOKEN", "").strip()


def resolve_user_id() -> int:
    configured_user_id = os.getenv("HOSPITAL_USER_ID", "").strip()
    if configured_user_id:
        return int(configured_user_id)

    if token:
        response = requests.get(
            f"{base_url}/api/auth/me",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
        )
        response.raise_for_status()
        return int(response.json()["id"])

    raise RuntimeError(
        "请设置 HOSPITAL_USER_ID，或设置 HOSPITAL_AUTH_TOKEN 让脚本从 /api/auth/me 获取当前用户 ID"
    )


url = f"{base_url}/api/iot/devices/add"
data = {
    "deviceImei": "867561087297571",
    "deviceModelId": 1,
    "deviceModelName": "智能手环",
    "roomName": "测试房间",
    "deviceType": "智能手环",
    "userId": resolve_user_id(),
}

headers = {"Content-Type": "application/json"}
if token:
    headers["Authorization"] = f"Bearer {token}"

response = requests.post(url, json=data, headers=headers, timeout=10)
print(f"Status: {response.status_code}")
print(f"Response: {response.text}")
