SET client_encoding = 'UTF8';

DO $$
DECLARE
    v_imei VARCHAR(32) := '867561087297571';
    v_sign_time TIMESTAMP := date_trunc('second', CURRENT_TIMESTAMP);
    v_suffix TEXT := to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');
    v_event_id BIGINT;
BEGIN
    UPDATE iot_devices
    SET
        device_type = '睡眠雷达',
        device_version = 'SM-C03'
    WHERE imei = v_imei;

    IF NOT EXISTS (
        SELECT 1
        FROM iot_devices
        WHERE imei = v_imei
          AND device_type = '睡眠雷达'
          AND device_version = 'SM-C03'
    ) THEN
        RAISE EXCEPTION 'SM-C03 sleep radar device % not found', v_imei;
    END IF;

    INSERT INTO iot_health_events (
        imei,
        event_name,
        data_type,
        device_state,
        sign_time,
        signature,
        nonce,
        raw_data
    )
    VALUES (
        v_imei,
        '呼吸心率信息上报',
        0,
        0,
        v_sign_time,
        ('seed-rh-' || v_imei || '-' || v_suffix)::VARCHAR(64),
        'seed-rh',
        jsonb_build_object(
            'imei', v_imei,
            'eventName', '呼吸心率信息上报',
            'dataType', 0,
            'deviceState', 0,
            'signTime', to_char(v_sign_time, 'YYYY-MM-DD HH24:MI:SS'),
            'items', jsonb_build_array(
                jsonb_build_object('attrName', '心率', 'value', '72'),
                jsonb_build_object('attrName', '呼吸次数', 'value', '18'),
                jsonb_build_object('attrName', '体动', 'value', '3')
            )
        )::TEXT
    )
    RETURNING id INTO v_event_id;

    INSERT INTO iot_health_event_items (event_id, imei, attr_name, attr_value, sign_time)
    VALUES
        (v_event_id, v_imei, '心率', 72, v_sign_time),
        (v_event_id, v_imei, '呼吸次数', 18, v_sign_time),
        (v_event_id, v_imei, '体动', 3, v_sign_time);

    INSERT INTO iot_health_events (
        imei,
        event_name,
        data_type,
        device_state,
        sign_time,
        signature,
        nonce,
        raw_data
    )
    VALUES (
        v_imei,
        '设备存在信息上报',
        0,
        0,
        v_sign_time + INTERVAL '1 minute',
        ('seed-pres-' || v_imei || '-' || v_suffix)::VARCHAR(64),
        'seed-pres',
        jsonb_build_object(
            'imei', v_imei,
            'eventName', '设备存在信息上报',
            'dataType', 0,
            'deviceState', 0,
            'signTime', to_char(v_sign_time + INTERVAL '1 minute', 'YYYY-MM-DD HH24:MI:SS'),
            'items', jsonb_build_array(
                jsonb_build_object('attrName', '体动', 'value', '3'),
                jsonb_build_object('attrName', '睡眠状态', 'value', '浅睡'),
                jsonb_build_object('attrName', '离床状态', 'value', '在床'),
                jsonb_build_object('attrName', '运动状态', 'value', '静止'),
                jsonb_build_object('attrName', '存在状态', 'value', '有人')
            )
        )::TEXT
    )
    RETURNING id INTO v_event_id;

    INSERT INTO iot_health_event_items (event_id, imei, attr_name, attr_value, sign_time)
    VALUES
        (v_event_id, v_imei, '体动', 3, v_sign_time + INTERVAL '1 minute'),
        (v_event_id, v_imei, '睡眠状态', 1, v_sign_time + INTERVAL '1 minute'),
        (v_event_id, v_imei, '离床状态', 0, v_sign_time + INTERVAL '1 minute'),
        (v_event_id, v_imei, '运动状态', 0, v_sign_time + INTERVAL '1 minute'),
        (v_event_id, v_imei, '存在状态', 1, v_sign_time + INTERVAL '1 minute');

    INSERT INTO iot_device_latest_metrics (
        imei,
        attr_name,
        attr_value,
        attr_value_text,
        sign_time,
        updated_at
    )
    VALUES
        (v_imei, '体动', 3, '3', v_sign_time + INTERVAL '1 minute', CURRENT_TIMESTAMP),
        (v_imei, '心率', 72, '72', v_sign_time, CURRENT_TIMESTAMP),
        (v_imei, '呼吸次数', 18, '18', v_sign_time, CURRENT_TIMESTAMP),
        (v_imei, '睡眠状态', 1, '浅睡', v_sign_time + INTERVAL '1 minute', CURRENT_TIMESTAMP),
        (v_imei, '离床状态', 0, '在床', v_sign_time + INTERVAL '1 minute', CURRENT_TIMESTAMP),
        (v_imei, '运动状态', 0, '静止', v_sign_time + INTERVAL '1 minute', CURRENT_TIMESTAMP),
        (v_imei, '存在状态', 1, '有人', v_sign_time + INTERVAL '1 minute', CURRENT_TIMESTAMP)
    ON CONFLICT (imei, attr_name) DO UPDATE SET
        attr_value = EXCLUDED.attr_value,
        attr_value_text = EXCLUDED.attr_value_text,
        sign_time = EXCLUDED.sign_time,
        updated_at = CURRENT_TIMESTAMP
    WHERE iot_device_latest_metrics.sign_time IS NULL
       OR EXCLUDED.sign_time >= iot_device_latest_metrics.sign_time;
END $$;
