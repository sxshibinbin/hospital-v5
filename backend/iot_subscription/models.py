"""
IoT 设备数据模型

表结构：
- iot_devices: 设备信息
- iot_device_contacts: 设备接警人
- iot_user_devices: 用户设备关系
- iot_device_types: 设备类型字典
- iot_device_params: 设备参数配置
- iot_health_events / iot_alarm_events / iot_heartbeat_events: 分类事件
- iot_health_event_items / iot_alarm_event_items / iot_heartbeat_event_items: 分类属性
- iot_device_latest_metrics: 设备最新指标
"""
from sqlalchemy import Column, Integer, String, SmallInteger, BigInteger, DateTime, Numeric, Text, ForeignKey, Index, Float
from sqlalchemy.orm import declarative_base, relationship
from datetime import datetime
import pytz


Base = declarative_base()


def get_beijing_time():
    return datetime.now(pytz.timezone('Asia/Shanghai')).replace(tzinfo=None)


class IoTDevice(Base):
    """设备信息表"""
    __tablename__ = "iot_devices"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    imei = Column(String(32), unique=True, nullable=False, index=True, comment="设备编号")
    iccid = Column(String(32), comment="SIM卡ICCID")
    device_type = Column(String(64), comment="设备类型")
    device_version = Column(String(64), comment="设备型号")
    device_model_id = Column(BigInteger, comment="设备型号ID")
    device_state = Column(SmallInteger, default=0, comment="状态 0:正常 1:故障 2:报警 4:离线 8:隐患")
    longitude = Column(Numeric(12, 8), comment="经度")
    latitude = Column(Numeric(12, 8), comment="纬度")
    site = Column(String(256), comment="安装地址")
    room_name = Column(String(128), comment="安装点名称")
    company_name = Column(String(128), comment="所属公司")
    enabled_time = Column(DateTime, comment="首次安装时间")
    created_at = Column(DateTime, default=get_beijing_time, comment="数据落库时间")
    updated_at = Column(DateTime, default=get_beijing_time, onupdate=get_beijing_time, comment="最后更新时间")

    # 关联
    contacts = relationship("IoTDeviceContact", back_populates="device", cascade="all, delete-orphan")
    params = relationship("IoTDeviceParam", back_populates="device", cascade="all, delete-orphan")


class IoTHealthEvent(Base):
    """健康类设备事件表"""
    __tablename__ = "iot_health_events"
    __table_args__ = (
        Index("idx_iot_health_events_imei_sign_time", "imei", "sign_time", "id"),
        Index("idx_iot_health_events_sign_time", "sign_time"),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    imei = Column(String(32), ForeignKey("iot_devices.imei"), nullable=False, index=True, comment="设备编号")
    event_name = Column(String(64), comment="事件名称")
    data_type = Column(SmallInteger, comment="数据类型 0:正常 1:故障 2:报警 8:隐患")
    device_state = Column(SmallInteger, comment="事件时设备状态")
    sign_time = Column(DateTime, comment="数据上报时间")
    signature = Column(String(64), comment="签名")
    nonce = Column(String(32), comment="随机数")
    raw_data = Column(Text, comment="原始JSON数据")
    handler_status = Column(SmallInteger, default=0, nullable=False, comment="事件处理状态 0:未处理 1:已处理")
    handle_time = Column(DateTime, comment="处理时间")
    alarm_reason = Column(String(128), comment="确认报警原因")
    created_at = Column(DateTime, default=get_beijing_time, comment="数据落库时间")


class IoTAlarmEvent(Base):
    """报警类设备事件表"""
    __tablename__ = "iot_alarm_events"
    __table_args__ = (
        Index("idx_iot_alarm_events_imei_sign_time", "imei", "sign_time", "id"),
        Index("idx_iot_alarm_events_data_type_time", "data_type", "sign_time"),
        Index("idx_iot_alarm_events_device_state_time", "device_state", "sign_time"),
        Index("idx_iot_alarm_events_type_state_time", "data_type", "device_state", "sign_time"),
        Index("idx_iot_alarm_events_handler_status_time", "handler_status", "sign_time"),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    imei = Column(String(32), ForeignKey("iot_devices.imei"), nullable=False, index=True, comment="设备编号")
    event_name = Column(String(64), comment="事件名称")
    data_type = Column(SmallInteger, comment="数据类型 0:正常 1:故障 2:报警 8:隐患")
    device_state = Column(SmallInteger, comment="事件时设备状态")
    sign_time = Column(DateTime, comment="数据上报时间")
    signature = Column(String(64), comment="签名")
    nonce = Column(String(32), comment="随机数")
    raw_data = Column(Text, comment="原始JSON数据")
    created_at = Column(DateTime, default=get_beijing_time, comment="数据落库时间")


class IoTHeartbeatEvent(Base):
    """心跳类设备事件表"""
    __tablename__ = "iot_heartbeat_events"
    __table_args__ = (
        Index("idx_iot_heartbeat_events_imei_sign_time", "imei", "sign_time", "id"),
        Index("idx_iot_heartbeat_events_sign_time", "sign_time"),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    imei = Column(String(32), ForeignKey("iot_devices.imei"), nullable=False, index=True, comment="设备编号")
    event_name = Column(String(64), comment="事件名称")
    data_type = Column(SmallInteger, comment="数据类型 0:正常 1:故障 2:报警 8:隐患")
    device_state = Column(SmallInteger, comment="事件时设备状态")
    sign_time = Column(DateTime, comment="数据上报时间")
    signature = Column(String(64), comment="签名")
    nonce = Column(String(32), comment="随机数")
    raw_data = Column(Text, comment="原始JSON数据")
    created_at = Column(DateTime, default=get_beijing_time, comment="数据落库时间")


class IoTHealthEventItem(Base):
    """健康类指标属性表"""
    __tablename__ = "iot_health_event_items"
    __table_args__ = (
        Index("idx_iot_health_items_imei_attr_sign_id", "imei", "attr_name", "sign_time", "id"),
        Index("idx_iot_health_items_event_id", "event_id"),
        Index("idx_iot_health_items_attr_sign_time", "attr_name", "sign_time"),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    event_id = Column(BigInteger, ForeignKey("iot_health_events.id"), nullable=False, comment="关联健康事件ID")
    imei = Column(String(32), ForeignKey("iot_devices.imei"), nullable=False, index=True, comment="设备编号")
    attr_name = Column(String(64), comment="属性名称")
    attr_value = Column(Float, comment="属性数值")
    prop_value = Column(String(128), comment="属性文本值")
    sign_time = Column(DateTime, comment="数据上报时间")
    created_at = Column(DateTime, default=get_beijing_time, comment="数据落库时间")


class IoTAlarmEventItem(Base):
    """报警类指标属性表"""
    __tablename__ = "iot_alarm_event_items"
    __table_args__ = (
        Index("idx_iot_alarm_items_event_id", "event_id"),
        Index("idx_iot_alarm_items_imei_attr_sign_id", "imei", "attr_name", "sign_time", "id"),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    event_id = Column(BigInteger, ForeignKey("iot_alarm_events.id"), nullable=False, comment="关联报警事件ID")
    imei = Column(String(32), ForeignKey("iot_devices.imei"), nullable=False, index=True, comment="设备编号")
    attr_name = Column(String(64), comment="属性名称")
    attr_value = Column(String(128), comment="属性值")
    sign_time = Column(DateTime, comment="数据上报时间")
    created_at = Column(DateTime, default=get_beijing_time, comment="数据落库时间")


class IoTHeartbeatEventItem(Base):
    """心跳类指标属性表"""
    __tablename__ = "iot_heartbeat_event_items"
    __table_args__ = (
        Index("idx_iot_heartbeat_items_event_id", "event_id"),
        Index("idx_iot_heartbeat_items_imei_attr_sign_id", "imei", "attr_name", "sign_time", "id"),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    event_id = Column(BigInteger, ForeignKey("iot_heartbeat_events.id"), nullable=False, comment="关联心跳事件ID")
    imei = Column(String(32), ForeignKey("iot_devices.imei"), nullable=False, index=True, comment="设备编号")
    attr_name = Column(String(64), comment="属性名称")
    attr_value = Column(String(128), comment="属性值")
    sign_time = Column(DateTime, comment="数据上报时间")
    created_at = Column(DateTime, default=get_beijing_time, comment="数据落库时间")


class IoTDeviceLatestMetric(Base):
    """设备最新指标表"""
    __tablename__ = "iot_device_latest_metrics"
    __table_args__ = (
        Index("uq_iot_latest_metrics_imei_attr", "imei", "attr_name", unique=True),
        Index("idx_iot_latest_metrics_attr_time", "attr_name", "sign_time"),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    imei = Column(String(32), ForeignKey("iot_devices.imei"), nullable=False, index=True, comment="设备编号")
    attr_name = Column(String(64), comment="属性名称")
    attr_value = Column(Float, comment="属性值")
    sign_time = Column(DateTime, comment="数据上报时间")
    updated_at = Column(DateTime, default=get_beijing_time, onupdate=get_beijing_time, comment="数据更新时间")


class IoTDeviceContact(Base):
    """设备接警人表"""
    __tablename__ = "iot_device_contacts"
    __table_args__ = (
        Index("idx_imei_phone", "imei", "phone", unique=True),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    imei = Column(String(32), ForeignKey("iot_devices.imei"), nullable=False, index=True, comment="设备编号")
    name = Column(String(64), comment="联系人姓名")
    phone = Column(String(20), comment="手机号")
    contact_type = Column(SmallInteger, comment="接警级别 1-4级")
    created_at = Column(DateTime, default=get_beijing_time, comment="数据落库时间")

    # 关联
    device = relationship("IoTDevice", back_populates="contacts")


class IoTDeviceParam(Base):
    """设备参数配置表"""
    __tablename__ = "iot_device_params"
    __table_args__ = (
        Index("idx_iot_device_params_imei_code_field", "imei", "param_code", "field_name", unique=True),
        Index("idx_iot_device_params_imei", "imei"),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    imei = Column(String(32), ForeignKey("iot_devices.imei"), nullable=False, comment="设备编号")
    param_code = Column(String(32), nullable=False, comment="参数编码")
    field_name = Column(String(32), nullable=False, default="", comment="参数字段")
    param_value = Column(String(64), comment="参数值")
    create_by = Column(String(32), nullable=False, comment="创建人")
    created_at = Column(DateTime, default=get_beijing_time, comment="数据落库时间")
    updated_at = Column(DateTime, default=get_beijing_time, onupdate=get_beijing_time, comment="数据更新时间")

    device = relationship("IoTDevice", back_populates="params")


class IoTUserDevice(Base):
    """用户设备关系表"""
    __tablename__ = "iot_user_devices"
    __table_args__ = (
        Index("idx_iot_user_devices_user_device_imei", "user_id", "device_id", "device_imei", unique=True),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, nullable=False, index=True, comment="用户ID")
    device_id = Column(BigInteger, nullable=False, index=True, comment="设备ID")
    device_imei = Column(String(32), nullable=False, comment="设备IMEI")
    status = Column(SmallInteger, default=1, comment="状态 0:禁用 1:启用")
    created_at = Column(DateTime, default=get_beijing_time, comment="创建时间")
    updated_at = Column(DateTime, default=get_beijing_time, onupdate=get_beijing_time, comment="更新时间")


class IoTDeviceType(Base):
    """设备类型字典表"""
    __tablename__ = "iot_device_types"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    code = Column(String(64), nullable=False, comment="设备类型编码")
    name = Column(String(128), nullable=False, comment="设备类型名称")
    status = Column(SmallInteger, default=1, comment="状态 0:禁用 1:启用")
    created_at = Column(DateTime, default=get_beijing_time, comment="创建时间")
    updated_at = Column(DateTime, default=get_beijing_time, onupdate=get_beijing_time, comment="更新时间")
