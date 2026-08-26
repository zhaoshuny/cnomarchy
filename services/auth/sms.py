"""
CNomarchy 认证服务 - 短信发送服务
支持: 阿里云短信 / 腾讯云短信 / Mock(开发测试)
"""
import random
import logging
from datetime import datetime, timedelta
from typing import Optional
from config import settings

logger = logging.getLogger(__name__)


class SMSService:
    """短信服务基类"""

    def send_code(self, phone: str, code: str, purpose: str = "login") -> bool:
        """发送验证码
        Args:
            phone: 手机号
            code: 验证码
            purpose: 用途（login/change_phone/new_device）
        Returns:
            是否发送成功
        """
        raise NotImplementedError


class MockSMSService(SMSService):
    """Mock 短信服务（开发测试用，不实际发送）"""

    def send_code(self, phone: str, code: str, purpose: str = "login") -> bool:
        purpose_text = {
            "login": "登录",
            "change_phone": "换绑手机号",
            "new_device": "新设备验证",
        }.get(purpose, "验证")

        logger.info(f"[MOCK SMS] 手机号: {phone}, 验证码: {code}, 用途: {purpose_text}")
        print(f"\n{'='*50}")
        print(f"  [MOCK SMS] 验证码: {code}")
        print(f"  手机号: {phone}")
        print(f"  用途: {purpose_text}")
        print(f"  有效期: {settings.verification_code_ttl}秒")
        print(f"{'='*50}\n")
        return True


class AliyunSMSService(SMSService):
    """阿里云短信服务"""

    def __init__(self):
        self.access_key_id = settings.aliyun_access_key_id
        self.access_key_secret = settings.aliyun_access_key_secret
        self.sign_name = settings.aliyun_sign_name
        self.template_code = settings.aliyun_template_code
        self.endpoint = settings.aliyun_endpoint

        if not all([self.access_key_id, self.access_key_secret, self.template_code]):
            raise ValueError("阿里云短信配置不完整，请检查 .env 文件")

    def send_code(self, phone: str, code: str, purpose: str = "login") -> bool:
        try:
            from alibabacloud_dysmsapi20170525.client import Client as DysmsapiClient
            from alibabacloud_dysmsapi20170525 import models as dysmsapi_models
            from alibabacloud_tea_openapi import models as open_api_models
            from alibabacloud_tea_util import models as util_models
            import json

            config = open_api_models.Config(
                access_key_id=self.access_key_id,
                access_key_secret=self.access_key_secret,
                endpoint=self.endpoint,
            )
            client = DysmsapiClient(config)

            request = dysmsapi_models.SendSmsRequest(
                phone_numbers=phone,
                sign_name=self.sign_name,
                template_code=self.template_code,
                template_param=json.dumps({"code": code}),
            )

            response = client.send_sms_with_options(request, util_models.RuntimeOptions())
            result = response.body

            if result.code == "OK":
                logger.info(f"阿里云短信发送成功: {phone}, request_id: {result.request_id}")
                return True
            else:
                logger.error(f"阿里云短信发送失败: {phone}, code: {result.code}, message: {result.message}")
                return False

        except Exception as e:
            logger.error(f"阿里云短信发送异常: {e}")
            return False


class TencentSMSService(SMSService):
    """腾讯云短信服务"""

    def __init__(self):
        self.sdk_app_id = settings.tencent_sdk_app_id
        self.secret_id = settings.tencent_secret_id
        self.secret_key = settings.tencent_secret_key
        self.sign_name = settings.tencent_sign_name
        self.template_id = settings.tencent_template_id

        if not all([self.sdk_app_id, self.secret_id, self.secret_key, self.template_id]):
            raise ValueError("腾讯云短信配置不完整，请检查 .env 文件")

    def send_code(self, phone: str, code: str, purpose: str = "login") -> bool:
        try:
            from tencentcloud.common import credential
            from tencentcloud.common.profile.client_profile import ClientProfile
            from tencentcloud.common.profile.http_profile import HttpProfile
            from tencentcloud.sms.v20210111 import sms_client, models
            import json

            cred = credential.Credential(self.secret_id, self.secret_key)
            httpProfile = HttpProfile()
            httpProfile.endpoint = "sms.tencentcloudapi.com"
            clientProfile = ClientProfile()
            clientProfile.httpProfile = httpProfile

            client = sms_client.SmsClient(cred, "ap-guangzhou", clientProfile)
            req = models.SendSmsRequest()
            params = {
                "PhoneNumberSet": [f"+86{phone}"],
                "SmsSdkAppId": self.sdk_app_id,
                "SignName": self.sign_name,
                "TemplateId": self.template_id,
                "TemplateParamSet": [code],
            }
            req.from_json_string(json.dumps(params))
            resp = client.SendSms(req)

            if resp.SendStatusSet and resp.SendStatusSet[0].Code == "Ok":
                logger.info(f"腾讯云短信发送成功: {phone}")
                return True
            else:
                logger.error(f"腾讯云短信发送失败: {phone}")
                return False

        except Exception as e:
            logger.error(f"腾讯云短信发送异常: {e}")
            return False


def get_sms_service() -> SMSService:
    """获取短信服务实例（根据配置选择）"""
    provider = settings.sms_provider.lower()

    if provider == "aliyun":
        return AliyunSMSService()
    elif provider == "tencent":
        return TencentSMSService()
    elif provider == "mock":
        return MockSMSService()
    else:
        logger.warning(f"未知短信服务商: {provider}，使用 Mock")
        return MockSMSService()


def generate_code(length: int = None) -> str:
    """生成随机验证码"""
    if length is None:
        length = settings.verification_code_length
    return "".join([str(random.randint(0, 9)) for _ in range(length)])
