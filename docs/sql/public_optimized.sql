/*
 医院健康管理系统数据库初始化脚本（优化版）
 支持幂等执行 - 无论数据库当前状态如何都能成功执行
*/

-- 步骤1: 断开所有其他连接
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = current_database() AND pid <> pg_backend_pid();

-- 步骤2: 删除所有现有表（CASCADE 级联删除序列依赖）
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public'
    LOOP EXECUTE format('DROP TABLE IF EXISTS public.%I CASCADE', r.tablename); END LOOP;
END $$;

-- 步骤3: 删除所有剩余序列
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = 'public'
    LOOP EXECUTE format('DROP SEQUENCE IF EXISTS public.%I', r.sequence_name); END LOOP;
END $$;

-- 步骤4: 创建序列（21个）
CREATE SEQUENCE "public"."agreements_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;
CREATE SEQUENCE "public"."audit_logs_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;
CREATE SEQUENCE "public"."chat_sessions_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;
CREATE SEQUENCE "public"."consultation_records_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;
CREATE SEQUENCE "public"."high_freq_questions_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;
CREATE SEQUENCE "public"."iot_alarm_event_items_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
CREATE SEQUENCE "public"."iot_alarm_events_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
CREATE SEQUENCE "public"."iot_device_contacts_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
CREATE SEQUENCE "public"."iot_device_latest_metrics_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
CREATE SEQUENCE "public"."iot_device_params_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
CREATE SEQUENCE "public"."iot_device_types_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
CREATE SEQUENCE "public"."iot_devices_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
CREATE SEQUENCE "public"."iot_health_event_items_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
CREATE SEQUENCE "public"."iot_health_events_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
CREATE SEQUENCE "public"."iot_heartbeat_event_items_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
CREATE SEQUENCE "public"."iot_heartbeat_events_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
CREATE SEQUENCE "public"."iot_ingest_performance_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
CREATE SEQUENCE "public"."iot_user_devices_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
CREATE SEQUENCE "public"."patient_profiles_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;
CREATE SEQUENCE "public"."system_configs_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;
CREATE SEQUENCE "public"."users_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- 步骤5: 创建表（22张）
CREATE TABLE "public"."agreements" (
  "id" int4 NOT NULL DEFAULT nextval('agreements_id_seq'::regclass),
  "type" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "title" varchar(100) COLLATE "pg_catalog"."default" NOT NULL,
  "content" text COLLATE "pg_catalog"."default" NOT NULL,
  "updated_at" timestamp(6)
)
;
CREATE TABLE "public"."audit_logs" (
  "id" int4 NOT NULL DEFAULT nextval('audit_logs_id_seq'::regclass),
  "admin_id" int4,
  "action" varchar(50) COLLATE "pg_catalog"."default",
  "target_id" varchar(50) COLLATE "pg_catalog"."default",
  "details" varchar(500) COLLATE "pg_catalog"."default",
  "created_at" timestamp(6)
)
;
CREATE TABLE "public"."chat_sessions" (
  "id" int4 NOT NULL DEFAULT nextval('chat_sessions_id_seq'::regclass),
  "user_id" int4 NOT NULL,
  "title" varchar(120) COLLATE "pg_catalog"."default" NOT NULL,
  "mode" varchar(20) COLLATE "pg_catalog"."default" NOT NULL,
  "messages_json" text COLLATE "pg_catalog"."default" NOT NULL,
  "is_active" bool,
  "token_count" int4,
  "created_at" timestamp(6),
  "updated_at" timestamp(6)
)
;
CREATE TABLE "public"."consultation_records" (
  "id" int4 NOT NULL DEFAULT nextval('consultation_records_id_seq'::regclass),
  "profile_id" int4,
  "symptoms" text COLLATE "pg_catalog"."default",
  "diagnosis" text COLLATE "pg_catalog"."default",
  "advice" text COLLATE "pg_catalog"."default",
  "department" varchar(100) COLLATE "pg_catalog"."default",
  "chat_history" text COLLATE "pg_catalog"."default",
  "created_at" timestamp(6)
)
;
CREATE TABLE "public"."high_freq_questions" (
  "id" int4 NOT NULL DEFAULT nextval('high_freq_questions_id_seq'::regclass),
  "question" varchar(200) COLLATE "pg_catalog"."default" NOT NULL,
  "answer_template" text COLLATE "pg_catalog"."default" NOT NULL,
  "category" varchar(50) COLLATE "pg_catalog"."default",
  "click_count" int4,
  "is_top" bool,
  "status" varchar(20) COLLATE "pg_catalog"."default",
  "sort_weight" int4,
  "created_at" timestamp(6),
  "updated_at" timestamp(6)
)
;
CREATE TABLE "public"."iot_alarm_event_items" (
  "id" int8 NOT NULL DEFAULT nextval('iot_alarm_event_items_id_seq'::regclass),
  "event_id" int8 NOT NULL,
  "imei" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "attr_name" varchar(64) COLLATE "pg_catalog"."default",
  "attr_value" varchar(128) COLLATE "pg_catalog"."default",
  "sign_time" timestamp(6),
  "created_at" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
CREATE TABLE "public"."iot_alarm_events" (
  "id" int8 NOT NULL DEFAULT nextval('iot_alarm_events_id_seq'::regclass),
  "imei" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "event_name" varchar(64) COLLATE "pg_catalog"."default",
  "data_type" int2,
  "device_state" int2,
  "sign_time" timestamp(6),
  "signature" varchar(64) COLLATE "pg_catalog"."default",
  "nonce" varchar(32) COLLATE "pg_catalog"."default",
  "raw_data" text COLLATE "pg_catalog"."default",
  "created_at" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "handler_status" int2 NOT NULL DEFAULT 0,
  "handle_time" timestamp(6),
  "alarm_reason" varchar(128) COLLATE "pg_catalog"."default"
)
;
CREATE TABLE "public"."iot_device_contacts" (
  "id" int8 NOT NULL DEFAULT nextval('iot_device_contacts_id_seq'::regclass),
  "imei" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "name" varchar(64) COLLATE "pg_catalog"."default",
  "phone" varchar(20) COLLATE "pg_catalog"."default",
  "contact_type" int2,
  "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP
)
;
CREATE TABLE "public"."iot_device_latest_metrics" (
  "id" int8 NOT NULL DEFAULT nextval('iot_device_latest_metrics_id_seq'::regclass),
  "imei" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "attr_name" varchar(64) COLLATE "pg_catalog"."default",
  "attr_value" float8,
  "sign_time" timestamp(6),
  "updated_at" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "attr_value_text" varchar(128) COLLATE "pg_catalog"."default"
)
;
CREATE TABLE "public"."iot_device_params" (
  "id" int8 NOT NULL DEFAULT nextval('iot_device_params_id_seq'::regclass),
  "imei" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "param_code" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "field_name" varchar(32) COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "param_value" varchar(64) COLLATE "pg_catalog"."default",
  "create_by" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "created_at" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
CREATE TABLE "public"."iot_device_types" (
  "id" int8 NOT NULL DEFAULT nextval('iot_device_types_id_seq'::regclass),
  "code" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "name" varchar(128) COLLATE "pg_catalog"."default" NOT NULL,
  "status" int2 DEFAULT 1,
  "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP
)
;
CREATE TABLE "public"."iot_devices" (
  "id" int8 NOT NULL DEFAULT nextval('iot_devices_id_seq'::regclass),
  "imei" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "iccid" varchar(32) COLLATE "pg_catalog"."default",
  "device_type" varchar(64) COLLATE "pg_catalog"."default",
  "device_version" varchar(64) COLLATE "pg_catalog"."default",
  "device_state" int2 DEFAULT 0,
  "longitude" numeric(12,8),
  "latitude" numeric(12,8),
  "site" varchar(256) COLLATE "pg_catalog"."default",
  "company_name" varchar(128) COLLATE "pg_catalog"."default",
  "enabled_time" timestamp(6),
  "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "room_name" varchar(128) COLLATE "pg_catalog"."default",
  "device_model_id" int8
)
;
CREATE TABLE "public"."iot_file_offsets" (
  "file_path" text COLLATE "pg_catalog"."default" NOT NULL,
  "offset_bytes" int8 NOT NULL DEFAULT 0,
  "file_size" int8 NOT NULL DEFAULT 0,
  "status" varchar(16) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'processing'::character varying,
  "updated_at" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "completed_at" timestamp(6)
)
;
CREATE TABLE "public"."iot_health_event_items" (
  "id" int8 NOT NULL DEFAULT nextval('iot_health_event_items_id_seq'::regclass),
  "event_id" int8 NOT NULL,
  "imei" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "attr_name" varchar(64) COLLATE "pg_catalog"."default",
  "attr_value" float8,
  "sign_time" timestamp(6),
  "created_at" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "prop_value" varchar(128) COLLATE "pg_catalog"."default"
)
;
CREATE TABLE "public"."iot_health_events" (
  "id" int8 NOT NULL DEFAULT nextval('iot_health_events_id_seq'::regclass),
  "imei" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "event_name" varchar(64) COLLATE "pg_catalog"."default",
  "data_type" int2,
  "device_state" int2,
  "sign_time" timestamp(6),
  "signature" varchar(64) COLLATE "pg_catalog"."default",
  "nonce" varchar(32) COLLATE "pg_catalog"."default",
  "raw_data" text COLLATE "pg_catalog"."default",
  "created_at" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
CREATE TABLE "public"."iot_heartbeat_event_items" (
  "id" int8 NOT NULL DEFAULT nextval('iot_heartbeat_event_items_id_seq'::regclass),
  "event_id" int8 NOT NULL,
  "imei" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "attr_name" varchar(64) COLLATE "pg_catalog"."default",
  "attr_value" varchar(128) COLLATE "pg_catalog"."default",
  "sign_time" timestamp(6),
  "created_at" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
CREATE TABLE "public"."iot_heartbeat_events" (
  "id" int8 NOT NULL DEFAULT nextval('iot_heartbeat_events_id_seq'::regclass),
  "imei" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "event_name" varchar(64) COLLATE "pg_catalog"."default",
  "data_type" int2,
  "device_state" int2,
  "sign_time" timestamp(6),
  "signature" varchar(64) COLLATE "pg_catalog"."default",
  "nonce" varchar(32) COLLATE "pg_catalog"."default",
  "raw_data" text COLLATE "pg_catalog"."default",
  "created_at" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "handler_status" int2 NOT NULL DEFAULT 0,
  "handle_time" timestamp(6),
  "alarm_reason" varchar(128) COLLATE "pg_catalog"."default"
)
;
CREATE TABLE "public"."iot_ingest_performance" (
  "id" int8 NOT NULL DEFAULT nextval('iot_ingest_performance_id_seq'::regclass),
  "run_id" varchar(80) COLLATE "pg_catalog"."default",
  "trace_id" varchar(128) COLLATE "pg_catalog"."default",
  "seq" int8,
  "imei" varchar(32) COLLATE "pg_catalog"."default",
  "event_name" varchar(64) COLLATE "pg_catalog"."default",
  "event_kind" varchar(64) COLLATE "pg_catalog"."default",
  "signature" varchar(64) COLLATE "pg_catalog"."default",
  "client_send_ms" float8,
  "api_received_ms" float8,
  "file_write_ms" float8,
  "file_read_ms" float8,
  "db_write_ms" float8 NOT NULL,
  "file_path" text COLLATE "pg_catalog"."default",
  "file_offset_bytes" int8,
  "created_at" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
CREATE TABLE "public"."iot_user_devices" (
  "id" int8 NOT NULL DEFAULT nextval('iot_user_devices_id_seq'::regclass),
  "user_id" int8 NOT NULL,
  "device_id" int8 NOT NULL,
  "device_imei" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "status" int2 DEFAULT 1,
  "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP
)
;
CREATE TABLE "public"."patient_profiles" (
  "id" int4 NOT NULL DEFAULT nextval('patient_profiles_id_seq'::regclass),
  "user_id" int4,
  "name" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "relation" varchar(20) COLLATE "pg_catalog"."default" NOT NULL,
  "gender" varchar(10) COLLATE "pg_catalog"."default" NOT NULL,
  "age" int4 NOT NULL,
  "medical_history" text COLLATE "pg_catalog"."default",
  "allergies" text COLLATE "pg_catalog"."default",
  "created_at" timestamp(6)
)
;
CREATE TABLE "public"."system_configs" (
  "id" int4 NOT NULL DEFAULT nextval('system_configs_id_seq'::regclass),
  "key" varchar(50) COLLATE "pg_catalog"."default",
  "value" varchar(200) COLLATE "pg_catalog"."default",
  "description" varchar(200) COLLATE "pg_catalog"."default",
  "updated_at" timestamp(6)
)
;
CREATE TABLE "public"."users" (
  "id" int4 NOT NULL DEFAULT nextval('users_id_seq'::regclass),
  "phone" varchar(20) COLLATE "pg_catalog"."default" NOT NULL,
  "hashed_password" varchar COLLATE "pg_catalog"."default",
  "display_name" varchar(100) COLLATE "pg_catalog"."default",
  "avatar_key" varchar(50) COLLATE "pg_catalog"."default",
  "is_admin" bool,
  "is_active" bool,
  "created_at" timestamp(6)
)
;

-- 步骤6: 设置序列归属关系
ALTER SEQUENCE "public"."agreements_id_seq" OWNED BY "public"."agreements"."id";
ALTER SEQUENCE "public"."audit_logs_id_seq" OWNED BY "public"."audit_logs"."id";
ALTER SEQUENCE "public"."chat_sessions_id_seq" OWNED BY "public"."chat_sessions"."id";
ALTER SEQUENCE "public"."consultation_records_id_seq" OWNED BY "public"."consultation_records"."id";
ALTER SEQUENCE "public"."high_freq_questions_id_seq" OWNED BY "public"."high_freq_questions"."id";
ALTER SEQUENCE "public"."iot_alarm_event_items_id_seq" OWNED BY "public"."iot_alarm_event_items"."id";
ALTER SEQUENCE "public"."iot_alarm_events_id_seq" OWNED BY "public"."iot_alarm_events"."id";
ALTER SEQUENCE "public"."iot_device_contacts_id_seq" OWNED BY "public"."iot_device_contacts"."id";
ALTER SEQUENCE "public"."iot_device_latest_metrics_id_seq" OWNED BY "public"."iot_device_latest_metrics"."id";
ALTER SEQUENCE "public"."iot_device_params_id_seq" OWNED BY "public"."iot_device_params"."id";
ALTER SEQUENCE "public"."iot_device_types_id_seq" OWNED BY "public"."iot_device_types"."id";
ALTER SEQUENCE "public"."iot_devices_id_seq" OWNED BY "public"."iot_devices"."id";
ALTER SEQUENCE "public"."iot_health_event_items_id_seq" OWNED BY "public"."iot_health_event_items"."id";
ALTER SEQUENCE "public"."iot_health_events_id_seq" OWNED BY "public"."iot_health_events"."id";
ALTER SEQUENCE "public"."iot_heartbeat_event_items_id_seq" OWNED BY "public"."iot_heartbeat_event_items"."id";
ALTER SEQUENCE "public"."iot_heartbeat_events_id_seq" OWNED BY "public"."iot_heartbeat_events"."id";
ALTER SEQUENCE "public"."iot_ingest_performance_id_seq" OWNED BY "public"."iot_ingest_performance"."id";
ALTER SEQUENCE "public"."iot_user_devices_id_seq" OWNED BY "public"."iot_user_devices"."id";
ALTER SEQUENCE "public"."patient_profiles_id_seq" OWNED BY "public"."patient_profiles"."id";
ALTER SEQUENCE "public"."system_configs_id_seq" OWNED BY "public"."system_configs"."id";
ALTER SEQUENCE "public"."users_id_seq" OWNED BY "public"."users"."id";

-- 步骤7: 添加主键约束
ALTER TABLE "public"."agreements" ADD CONSTRAINT "agreements_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."audit_logs" ADD CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."chat_sessions" ADD CONSTRAINT "chat_sessions_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."consultation_records" ADD CONSTRAINT "consultation_records_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."high_freq_questions" ADD CONSTRAINT "high_freq_questions_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."iot_alarm_event_items" ADD CONSTRAINT "iot_alarm_event_items_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."iot_alarm_events" ADD CONSTRAINT "iot_alarm_events_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."iot_device_contacts" ADD CONSTRAINT "iot_device_contacts_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."iot_device_latest_metrics" ADD CONSTRAINT "iot_device_latest_metrics_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."iot_device_params" ADD CONSTRAINT "iot_device_params_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."iot_device_types" ADD CONSTRAINT "iot_device_types_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."iot_devices" ADD CONSTRAINT "iot_devices_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."iot_file_offsets" ADD CONSTRAINT "iot_file_offsets_pkey" PRIMARY KEY ("file_path");
ALTER TABLE "public"."iot_health_event_items" ADD CONSTRAINT "iot_health_event_items_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."iot_health_events" ADD CONSTRAINT "iot_health_events_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."iot_heartbeat_event_items" ADD CONSTRAINT "iot_heartbeat_event_items_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."iot_heartbeat_events" ADD CONSTRAINT "iot_heartbeat_events_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."iot_ingest_performance" ADD CONSTRAINT "iot_ingest_performance_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."iot_user_devices" ADD CONSTRAINT "iot_user_devices_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."patient_profiles" ADD CONSTRAINT "patient_profiles_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."system_configs" ADD CONSTRAINT "system_configs_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."users" ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");

-- 步骤8: 创建索引（34个）
CREATE INDEX "ix_agreements_id" ON "public"."agreements" USING btree (
CREATE INDEX "ix_audit_logs_id" ON "public"."audit_logs" USING btree (
CREATE INDEX "ix_chat_sessions_id" ON "public"."chat_sessions" USING btree (
CREATE INDEX "ix_chat_sessions_user_id" ON "public"."chat_sessions" USING btree (
CREATE INDEX "ix_consultation_records_id" ON "public"."consultation_records" USING btree (
CREATE INDEX "ix_high_freq_questions_id" ON "public"."high_freq_questions" USING btree (
CREATE INDEX "idx_iot_alarm_items_event_id" ON "public"."iot_alarm_event_items" USING btree (
CREATE INDEX "idx_iot_alarm_items_imei_attr_sign_id" ON "public"."iot_alarm_event_items" USING btree (
CREATE INDEX "idx_iot_alarm_events_data_type_time" ON "public"."iot_alarm_events" USING btree (
CREATE INDEX "idx_iot_alarm_events_device_state_time" ON "public"."iot_alarm_events" USING btree (
CREATE INDEX "idx_iot_alarm_events_handler_status_time" ON "public"."iot_alarm_events" USING btree (
CREATE INDEX "idx_iot_alarm_events_imei_sign_time" ON "public"."iot_alarm_events" USING btree (
CREATE INDEX "idx_iot_alarm_events_type_state_time" ON "public"."iot_alarm_events" USING btree (
CREATE INDEX "idx_iot_device_contacts_imei" ON "public"."iot_device_contacts" USING btree (
CREATE INDEX "idx_iot_latest_metrics_attr_time" ON "public"."iot_device_latest_metrics" USING btree (
CREATE INDEX "idx_iot_device_params_imei" ON "public"."iot_device_params" USING btree (
CREATE INDEX "idx_iot_devices_imei" ON "public"."iot_devices" USING btree (
CREATE INDEX "idx_iot_file_offsets_status_updated_at" ON "public"."iot_file_offsets" USING btree (
CREATE INDEX "idx_iot_health_items_attr_sign_time" ON "public"."iot_health_event_items" USING btree (
CREATE INDEX "idx_iot_health_items_event_id" ON "public"."iot_health_event_items" USING btree (
CREATE INDEX "idx_iot_health_items_imei_attr_sign_id" ON "public"."iot_health_event_items" USING btree (
CREATE INDEX "idx_iot_health_events_imei_sign_time" ON "public"."iot_health_events" USING btree (
CREATE INDEX "idx_iot_health_events_sign_time" ON "public"."iot_health_events" USING btree (
CREATE INDEX "idx_iot_heartbeat_items_event_id" ON "public"."iot_heartbeat_event_items" USING btree (
CREATE INDEX "idx_iot_heartbeat_items_imei_attr_sign_id" ON "public"."iot_heartbeat_event_items" USING btree (
CREATE INDEX "idx_iot_heartbeat_events_imei_sign_time" ON "public"."iot_heartbeat_events" USING btree (
CREATE INDEX "idx_iot_heartbeat_events_imei_status_time" ON "public"."iot_heartbeat_events" USING btree (
CREATE INDEX "idx_iot_heartbeat_events_sign_time" ON "public"."iot_heartbeat_events" USING btree (
CREATE INDEX "idx_iot_ingest_performance_imei_created" ON "public"."iot_ingest_performance" USING btree (
CREATE INDEX "idx_iot_ingest_performance_run_id" ON "public"."iot_ingest_performance" USING btree (
CREATE INDEX "idx_iot_user_devices_user_imei_status" ON "public"."iot_user_devices" USING btree (
CREATE INDEX "ix_patient_profiles_id" ON "public"."patient_profiles" USING btree (
CREATE INDEX "ix_system_configs_id" ON "public"."system_configs" USING btree (
CREATE INDEX "ix_users_id" ON "public"."users" USING btree (

-- 步骤9: 初始化序列值
SELECT setval('"public"."agreements_id_seq"', 2, true);
SELECT setval('"public"."audit_logs_id_seq"', 1, false);
SELECT setval('"public"."chat_sessions_id_seq"', 1, false);
SELECT setval('"public"."consultation_records_id_seq"', 1, false);
SELECT setval('"public"."high_freq_questions_id_seq"', 1, false);
SELECT setval('"public"."iot_alarm_event_items_id_seq"', 93428, true);
SELECT setval('"public"."iot_alarm_events_id_seq"', 58196, true);
SELECT setval('"public"."iot_device_contacts_id_seq"', 140421, true);
SELECT setval('"public"."iot_device_latest_metrics_id_seq"', 166202, true);
SELECT setval('"public"."iot_device_params_id_seq"', 546, true);
SELECT setval('"public"."iot_device_types_id_seq"', 1, true);
SELECT setval('"public"."iot_devices_id_seq"', 19331, true);
SELECT setval('"public"."iot_health_event_items_id_seq"', 202150, true);
SELECT setval('"public"."iot_health_events_id_seq"', 133872, true);
SELECT setval('"public"."iot_heartbeat_event_items_id_seq"', 3298723, true);
SELECT setval('"public"."iot_heartbeat_events_id_seq"', 864839, true);
SELECT setval('"public"."iot_ingest_performance_id_seq"', 124674, true);
SELECT setval('"public"."iot_user_devices_id_seq"', 4011, true);
SELECT setval('"public"."patient_profiles_id_seq"', 1, false);
SELECT setval('"public"."system_configs_id_seq"', 3, true);
SELECT setval('"public"."users_id_seq"', 1, true);

SELECT 'Database initialization completed successfully!' AS result;
