# IoT接口切换新表改造方案

## 总体策略

第一阶段只切读接口到新表，写入继续新旧双写。

保留旧表双写的原因：

1. 便于线上观察和新旧表对账。
2. 出现问题时可快速回退到旧查询。
3. 等新接口稳定后，再进入第二阶段讨论是否停止旧表写入。

返回 JSON 契约保持不变，前端无感。

## 1. 指标趋势接口

接口：

```text
POST /api/iot/device/metric/trend
```

当前数据源：

```text
iot_event_items
```

调整为：

```text
iot_health_event_items
```

调整内容：

1. `attr_value` 已是 `DOUBLE PRECISION`，直接参与聚合。
2. 删除 SQL 中的 `substring(attr_value from pattern)::numeric`。
3. 聚合逻辑保持不变：
   - 心率、血氧、血压、温度：按 bucket 聚合平均值、最大值、最小值、最新值。
   - 计步：继续按平台最新累计值逻辑处理。

预期收益：

1. 不再做文本正则转换。
2. 不再扫描旧的大属性表。
3. 可命中 `idx_iot_health_items_imei_attr_sign_id`。

返回结构：不变。

## 2. 设备检测报告接口

接口：

```text
POST /api/iot/device/report
```

当前数据源：

```text
最新事件状态：iot_device_events
手环/手表指标：iot_event_items
雷达报警数：iot_device_events WHERE data_type = 2
```

调整为：

```text
最新事件状态：iot_health_events / iot_alarm_events / iot_heartbeat_events UNION ALL
手环/手表指标：iot_device_latest_metrics
雷达当天报警数：iot_alarm_events
```

最新事件查询逻辑：

```sql
SELECT device_state, sign_time
FROM (
    SELECT device_state, sign_time, id FROM iot_health_events WHERE imei = %s
    UNION ALL
    SELECT device_state, sign_time, id FROM iot_alarm_events WHERE imei = %s
    UNION ALL
    SELECT device_state, sign_time, id FROM iot_heartbeat_events WHERE imei = %s
) t
ORDER BY sign_time DESC NULLS LAST, id DESC
LIMIT 1;
```

最新指标查询逻辑：

```sql
SELECT imei, attr_name, attr_value, sign_time
FROM iot_device_latest_metrics
WHERE imei IN (...)
  AND attr_name IN (...);
```

说明：`iot_device_latest_metrics` 已有 `(imei, attr_name)` 唯一索引，所以不需要再使用 `DISTINCT ON`。

返回结构：不变。

## 3. 单设备报警接口

接口：

```text
POST /api/iot/devices/alarm
```

当前数据源：

```text
iot_device_events
```

调整为：

```text
iot_alarm_events
```

查询字段直接来自新表：

```text
event_name
data_type
handler_status
handle_time
alarm_reason
sign_time
```

查询条件：

```sql
WHERE imei = %s
  AND sign_time >= %s::DATE
  AND sign_time < (%s::DATE + INTERVAL '1 day')
```

如果传 `handlerStatus`：

```sql
AND handler_status = %s
```

说明：`iot_alarm_events` 已新增 `handler_status / handle_time / alarm_reason`，不需要再 join 旧表补字段。

返回结构：不变。

## 4. 设备信息接口

接口：

```text
POST /api/iot/device/get
```

当前数据源：

```text
设备基础信息：iot_devices
最新状态和上报时间：iot_device_events
```

调整为：

```text
设备基础信息：iot_devices
状态：优先使用 iot_devices.device_state
最新上报时间：iot_health_events / iot_alarm_events / iot_heartbeat_events UNION ALL
```

最新上报时间查询逻辑：

```sql
SELECT device_state, sign_time
FROM (
    SELECT device_state, sign_time, id FROM iot_health_events WHERE imei = %s
    UNION ALL
    SELECT device_state, sign_time, id FROM iot_alarm_events WHERE imei = %s
    UNION ALL
    SELECT device_state, sign_time, id FROM iot_heartbeat_events WHERE imei = %s
) t
ORDER BY sign_time DESC NULLS LAST, id DESC
LIMIT 1;
```

返回结构：不变。

## 5. 设备删除回调

位置：

```text
router.py 设备信息变更 action=delete
```

当前清理旧表：

```text
iot_event_items
iot_device_events
iot_device_contacts
iot_devices
```

调整为先清理新表：

```text
iot_health_event_items
iot_alarm_event_items
iot_heartbeat_event_items
iot_device_latest_metrics
iot_health_events
iot_alarm_events
iot_heartbeat_events
```

再清理旧表：

```text
iot_event_items
iot_device_events
iot_device_contacts
iot_devices
```

原因：

1. 新表有外键引用 `iot_devices`。
2. 不先删新表，删除设备可能失败。
3. 避免设备删除后新表残留历史数据。

## 6. 写入逻辑

第一阶段继续双写：

```text
旧表：iot_device_events / iot_event_items
新表：iot_health_events / iot_alarm_events / iot_heartbeat_events
新属性表：iot_health_event_items / iot_alarm_event_items / iot_heartbeat_event_items
最新指标表：iot_device_latest_metrics
```

同时将 `_upsert_latest_metric()` 调整为数据库原子 upsert：

```sql
INSERT INTO iot_device_latest_metrics
    (imei, attr_name, attr_value, sign_time, updated_at)
VALUES
    (%s, %s, %s, %s, CURRENT_TIMESTAMP)
ON CONFLICT (imei, attr_name) DO UPDATE SET
    attr_value = EXCLUDED.attr_value,
    sign_time = EXCLUDED.sign_time,
    updated_at = CURRENT_TIMESTAMP
WHERE
    iot_device_latest_metrics.sign_time IS NULL
    OR (
        EXCLUDED.sign_time IS NOT NULL
        AND EXCLUDED.sign_time >= iot_device_latest_metrics.sign_time
    );
```

目的：

1. 由数据库唯一索引保证并发安全。
2. 新数据时间较新或相等时更新。
3. 旧时间数据回放时不覆盖最新值。
4. 当已有记录有上报时间时，`sign_time` 为空的新数据不覆盖已有最新值。

## 实施顺序

1. 修改 `_upsert_latest_metric()` 为 `ON CONFLICT` 原子 upsert。
2. 修改指标趋势接口读 `iot_health_event_items`。
3. 修改设备报告接口读 `iot_device_latest_metrics` 和新事件表。
4. 修改报警接口读 `iot_alarm_events`。
5. 修改设备信息接口读新事件表。
6. 修改设备删除回调清理新表。
7. 重启后端。
8. 接口验证与 SQL 对账。

## 验证清单

### SQL验证

确认 `iot_device_latest_metrics` 没有重复：

```sql
SELECT imei, attr_name, COUNT(*)
FROM iot_device_latest_metrics
GROUP BY imei, attr_name
HAVING COUNT(*) > 1;
```

确认新旧事件数量对账：

```sql
SELECT COUNT(*) FROM iot_device_events;

SELECT
    (SELECT COUNT(*) FROM iot_health_events)
  + (SELECT COUNT(*) FROM iot_alarm_events)
  + (SELECT COUNT(*) FROM iot_heartbeat_events) AS new_event_count;
```

确认新旧属性数量对账：

```sql
SELECT COUNT(*) FROM iot_event_items;

SELECT
    (SELECT COUNT(*) FROM iot_health_event_items)
  + (SELECT COUNT(*) FROM iot_alarm_event_items)
  + (SELECT COUNT(*) FROM iot_heartbeat_event_items) AS new_item_count;
```

### 接口验证

```text
/device/metric/trend：趋势点数量、最新值、聚合值和旧接口一致
/device/report：设备状态、最新指标、报警数正确
/devices/alarm：报警列表、handlerStatus 过滤正确
/device/get：设备状态、reportDate 正确
```

### 性能验证

```text
指标趋势不再访问 iot_event_items
报告页最新指标命中 uq_iot_latest_metrics_imei_attr
报警查询命中 iot_alarm_events 相关索引
```

## 第二阶段

第一阶段稳定后，再讨论是否停止旧表写入。

停止旧表写入前需要确认：

1. 所有读取接口已切到新表。
2. 报警处置功能已使用 `iot_alarm_events`。
3. 对账连续稳定。
4. 已有报表、后台任务、运维查询不再依赖旧表。
