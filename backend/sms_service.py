import asyncio
import json
import os
from dataclasses import dataclass
from typing import Any

from loguru import logger


class SmsServiceError(RuntimeError):
    """Base error for verification SMS delivery."""


class SmsServiceConfigError(SmsServiceError):
    """Raised when required SMS provider configuration is missing."""


class SmsDeliveryError(SmsServiceError):
    """Raised when the SMS provider rejects or fails a delivery request."""


@dataclass(frozen=True)
class AliyunSmsConfig:
    access_key_id: str
    access_key_secret: str
    sign_name: str
    template_code: str
    endpoint: str
    code_param_name: str
    extra_template_params: dict[str, Any]


@dataclass(frozen=True)
class SmsSendResult:
    request_id: str | None = None
    provider_code: str | None = None
    provider_message: str | None = None


def _get_env(primary_name: str, fallback_name: str | None = None, default: str = "") -> str:
    value = os.getenv(primary_name, "").strip()
    if value:
        return value
    if fallback_name:
        return os.getenv(fallback_name, "").strip()
    return default


def _load_extra_template_params() -> dict[str, Any]:
    raw = os.getenv("ALIBABA_CLOUD_SMS_TEMPLATE_PARAM_EXTRA", "").strip()
    if not raw:
        return {}

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as error:
        raise SmsServiceConfigError(
            "短信服务配置错误：ALIBABA_CLOUD_SMS_TEMPLATE_PARAM_EXTRA 必须是 JSON 对象"
        ) from error

    if not isinstance(parsed, dict):
        raise SmsServiceConfigError(
            "短信服务配置错误：ALIBABA_CLOUD_SMS_TEMPLATE_PARAM_EXTRA 必须是 JSON 对象"
        )
    return parsed


def load_aliyun_sms_config() -> AliyunSmsConfig:
    access_key_id = _get_env(
        "ALIBABA_CLOUD_SMS_ACCESS_KEY_ID",
        fallback_name="ALIBABA_CLOUD_ACCESS_KEY_ID",
    )
    access_key_secret = _get_env(
        "ALIBABA_CLOUD_SMS_ACCESS_KEY_SECRET",
        fallback_name="ALIBABA_CLOUD_ACCESS_KEY_SECRET",
    )
    sign_name = _get_env("ALIBABA_CLOUD_SMS_SIGN_NAME")
    template_code = _get_env("ALIBABA_CLOUD_SMS_TEMPLATE_CODE")

    missing_fields = [
        name
        for name, value in (
            ("ALIBABA_CLOUD_SMS_SIGN_NAME", sign_name),
            ("ALIBABA_CLOUD_SMS_TEMPLATE_CODE", template_code),
            ("ALIBABA_CLOUD_SMS_ACCESS_KEY_ID 或 ALIBABA_CLOUD_ACCESS_KEY_ID", access_key_id),
            (
                "ALIBABA_CLOUD_SMS_ACCESS_KEY_SECRET 或 ALIBABA_CLOUD_ACCESS_KEY_SECRET",
                access_key_secret,
            ),
        )
        if not value
    ]
    if missing_fields:
        raise SmsServiceConfigError(
            "短信服务未配置完整，请设置：" + "、".join(missing_fields)
        )

    return AliyunSmsConfig(
        access_key_id=access_key_id,
        access_key_secret=access_key_secret,
        sign_name=sign_name,
        template_code=template_code,
        endpoint=_get_env("ALIBABA_CLOUD_SMS_ENDPOINT", default="dysmsapi.aliyuncs.com"),
        code_param_name=_get_env("ALIBABA_CLOUD_SMS_CODE_PARAM_NAME", default="code"),
        extra_template_params=_load_extra_template_params(),
    )


def _create_aliyun_sms_client(config: AliyunSmsConfig):
    try:
        from alibabacloud_dysmsapi20170525.client import Client as DysmsapiClient
        from alibabacloud_tea_openapi import models as open_api_models
    except ImportError as error:
        raise SmsServiceConfigError(
            "缺少阿里云短信 SDK，请安装依赖 alibabacloud_dysmsapi20170525"
        ) from error

    client_config = open_api_models.Config(
        access_key_id=config.access_key_id,
        access_key_secret=config.access_key_secret,
    )
    client_config.endpoint = config.endpoint
    return DysmsapiClient(client_config)


def _mask_phone(phone: str) -> str:
    if len(phone) < 7:
        return "***"
    return f"{phone[:3]}****{phone[-4:]}"


def _send_verification_code_sync(phone: str, code: str) -> SmsSendResult:
    try:
        from alibabacloud_dysmsapi20170525 import models as dysmsapi_models
        from alibabacloud_tea_util import models as util_models
    except ImportError as error:
        raise SmsServiceConfigError(
            "缺少阿里云短信 SDK，请安装依赖 alibabacloud_dysmsapi20170525"
        ) from error

    config = load_aliyun_sms_config()
    client = _create_aliyun_sms_client(config)
    template_params = {
        **config.extra_template_params,
        config.code_param_name: code,
    }
    send_sms_request = dysmsapi_models.SendSmsRequest(
        phone_numbers=phone,
        sign_name=config.sign_name,
        template_code=config.template_code,
        template_param=json.dumps(template_params, ensure_ascii=False),
    )
    runtime = util_models.RuntimeOptions()

    try:
        response = client.send_sms_with_options(send_sms_request, runtime)
    except SmsServiceError:
        raise
    except Exception as error:
        logger.warning(
            "Aliyun SMS request failed: phone={}, error={}",
            _mask_phone(phone),
            error,
        )
        raise SmsDeliveryError("短信发送失败，请稍后重试") from error

    body = getattr(response, "body", None)
    provider_code = getattr(body, "code", None)
    provider_message = getattr(body, "message", None)
    request_id = getattr(body, "request_id", None)
    if provider_code != "OK":
        logger.warning(
            "Aliyun SMS rejected request: phone={}, code={}, message={}, request_id={}",
            _mask_phone(phone),
            provider_code,
            provider_message,
            request_id,
        )
        raise SmsDeliveryError(provider_message or "短信发送失败，请稍后重试")

    logger.info(
        "Aliyun SMS sent: phone={}, request_id={}",
        _mask_phone(phone),
        request_id,
    )
    return SmsSendResult(
        request_id=request_id,
        provider_code=provider_code,
        provider_message=provider_message,
    )


async def send_verification_code(phone: str, code: str) -> SmsSendResult:
    return await asyncio.to_thread(_send_verification_code_sync, phone, code)
