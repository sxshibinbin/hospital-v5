/*
 Navicat Premium Dump SQL

 Source Server         : 本地PG
 Source Server Type    : PostgreSQL
 Source Server Version : 160011 (160011)
 Source Host           : localhost:5432
 Source Catalog        : hospital
 Source Schema         : public

 Target Server Type    : PostgreSQL
 Target Server Version : 160011 (160011)
 File Encoding         : 65001

 Date: 06/08/2026 11:31:21
*/


-- ----------------------------
-- Sequence structure for agreements_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."agreements_id_seq";
CREATE SEQUENCE "public"."agreements_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for audit_logs_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."audit_logs_id_seq";
CREATE SEQUENCE "public"."audit_logs_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for chat_sessions_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."chat_sessions_id_seq";
CREATE SEQUENCE "public"."chat_sessions_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for consultation_records_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."consultation_records_id_seq";
CREATE SEQUENCE "public"."consultation_records_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for high_freq_questions_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."high_freq_questions_id_seq";
CREATE SEQUENCE "public"."high_freq_questions_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for iot_alarm_event_items_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."iot_alarm_event_items_id_seq";
CREATE SEQUENCE "public"."iot_alarm_event_items_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for iot_alarm_events_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."iot_alarm_events_id_seq";
CREATE SEQUENCE "public"."iot_alarm_events_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for iot_device_contacts_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."iot_device_contacts_id_seq";
CREATE SEQUENCE "public"."iot_device_contacts_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for iot_device_latest_metrics_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."iot_device_latest_metrics_id_seq";
CREATE SEQUENCE "public"."iot_device_latest_metrics_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for iot_device_params_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."iot_device_params_id_seq";
CREATE SEQUENCE "public"."iot_device_params_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for iot_device_types_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."iot_device_types_id_seq";
CREATE SEQUENCE "public"."iot_device_types_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for iot_devices_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."iot_devices_id_seq";
CREATE SEQUENCE "public"."iot_devices_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for iot_health_event_items_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."iot_health_event_items_id_seq";
CREATE SEQUENCE "public"."iot_health_event_items_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for iot_health_events_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."iot_health_events_id_seq";
CREATE SEQUENCE "public"."iot_health_events_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for iot_heartbeat_event_items_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."iot_heartbeat_event_items_id_seq";
CREATE SEQUENCE "public"."iot_heartbeat_event_items_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for iot_heartbeat_events_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."iot_heartbeat_events_id_seq";
CREATE SEQUENCE "public"."iot_heartbeat_events_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for iot_ingest_performance_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."iot_ingest_performance_id_seq";
CREATE SEQUENCE "public"."iot_ingest_performance_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for iot_user_devices_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."iot_user_devices_id_seq";
CREATE SEQUENCE "public"."iot_user_devices_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for patient_profiles_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."patient_profiles_id_seq";
CREATE SEQUENCE "public"."patient_profiles_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for system_configs_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."system_configs_id_seq";
CREATE SEQUENCE "public"."system_configs_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for users_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."users_id_seq";
CREATE SEQUENCE "public"."users_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Table structure for agreements
-- ----------------------------
DROP TABLE IF EXISTS "public"."agreements";
CREATE TABLE "public"."agreements" (
  "id" int4 NOT NULL DEFAULT nextval('agreements_id_seq'::regclass),
  "type" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "title" varchar(100) COLLATE "pg_catalog"."default" NOT NULL,
  "content" text COLLATE "pg_catalog"."default" NOT NULL,
  "updated_at" timestamp(6)
)
;

-- ----------------------------
-- Table structure for audit_logs
-- ----------------------------
DROP TABLE IF EXISTS "public"."audit_logs";
CREATE TABLE "public"."audit_logs" (
  "id" int4 NOT NULL DEFAULT nextval('audit_logs_id_seq'::regclass),
  "admin_id" int4,
  "action" varchar(50) COLLATE "pg_catalog"."default",
  "target_id" varchar(50) COLLATE "pg_catalog"."default",
  "details" varchar(500) COLLATE "pg_catalog"."default",
  "created_at" timestamp(6)
)
;

-- ----------------------------
-- Table structure for chat_sessions
-- ----------------------------
DROP TABLE IF EXISTS "public"."chat_sessions";
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

-- ----------------------------
-- Table structure for consultation_records
-- ----------------------------
DROP TABLE IF EXISTS "public"."consultation_records";
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

-- ----------------------------
-- Table structure for high_freq_questions
-- ----------------------------
DROP TABLE IF EXISTS "public"."high_freq_questions";
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

-- ----------------------------
-- Table structure for iot_alarm_event_items
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_alarm_event_items";
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

-- ----------------------------
-- Table structure for iot_alarm_events
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_alarm_events";
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

-- ----------------------------
-- Table structure for iot_device_contacts
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_device_contacts";
CREATE TABLE "public"."iot_device_contacts" (
  "id" int8 NOT NULL DEFAULT nextval('iot_device_contacts_id_seq'::regclass),
  "imei" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "name" varchar(64) COLLATE "pg_catalog"."default",
  "phone" varchar(20) COLLATE "pg_catalog"."default",
  "contact_type" int2,
  "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP
)
;

-- ----------------------------
-- Table structure for iot_device_latest_metrics
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_device_latest_metrics";
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

-- ----------------------------
-- Table structure for iot_device_params
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_device_params";
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

-- ----------------------------
-- Table structure for iot_device_types
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_device_types";
CREATE TABLE "public"."iot_device_types" (
  "id" int8 NOT NULL DEFAULT nextval('iot_device_types_id_seq'::regclass),
  "code" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "name" varchar(128) COLLATE "pg_catalog"."default" NOT NULL,
  "status" int2 DEFAULT 1,
  "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP
)
;

-- ----------------------------
-- Table structure for iot_devices
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_devices";
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

-- ----------------------------
-- Table structure for iot_file_offsets
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_file_offsets";
CREATE TABLE "public"."iot_file_offsets" (
  "file_path" text COLLATE "pg_catalog"."default" NOT NULL,
  "offset_bytes" int8 NOT NULL DEFAULT 0,
  "file_size" int8 NOT NULL DEFAULT 0,
  "status" varchar(16) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'processing'::character varying,
  "updated_at" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "completed_at" timestamp(6)
)
;

-- ----------------------------
-- Table structure for iot_health_event_items
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_health_event_items";
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

-- ----------------------------
-- Table structure for iot_health_events
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_health_events";
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

-- ----------------------------
-- Table structure for iot_heartbeat_event_items
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_heartbeat_event_items";
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

-- ----------------------------
-- Table structure for iot_heartbeat_events
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_heartbeat_events";
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

-- ----------------------------
-- Table structure for iot_ingest_performance
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_ingest_performance";
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

-- ----------------------------
-- Table structure for iot_user_devices
-- ----------------------------
DROP TABLE IF EXISTS "public"."iot_user_devices";
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

-- ----------------------------
-- Table structure for patient_profiles
-- ----------------------------
DROP TABLE IF EXISTS "public"."patient_profiles";
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

-- ----------------------------
-- Table structure for system_configs
-- ----------------------------
DROP TABLE IF EXISTS "public"."system_configs";
CREATE TABLE "public"."system_configs" (
  "id" int4 NOT NULL DEFAULT nextval('system_configs_id_seq'::regclass),
  "key" varchar(50) COLLATE "pg_catalog"."default",
  "value" varchar(200) COLLATE "pg_catalog"."default",
  "description" varchar(200) COLLATE "pg_catalog"."default",
  "updated_at" timestamp(6)
)
;

-- ----------------------------
-- Table structure for users
-- ----------------------------
DROP TABLE IF EXISTS "public"."users";
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

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."agreements_id_seq"
OWNED BY "public"."agreements"."id";
SELECT setval('"public"."agreements_id_seq"', 2, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."audit_logs_id_seq"
OWNED BY "public"."audit_logs"."id";
SELECT setval('"public"."audit_logs_id_seq"', 1, false);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."chat_sessions_id_seq"
OWNED BY "public"."chat_sessions"."id";
SELECT setval('"public"."chat_sessions_id_seq"', 1, false);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."consultation_records_id_seq"
OWNED BY "public"."consultation_records"."id";
SELECT setval('"public"."consultation_records_id_seq"', 1, false);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."high_freq_questions_id_seq"
OWNED BY "public"."high_freq_questions"."id";
SELECT setval('"public"."high_freq_questions_id_seq"', 1, false);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."iot_alarm_event_items_id_seq"
OWNED BY "public"."iot_alarm_event_items"."id";
SELECT setval('"public"."iot_alarm_event_items_id_seq"', 93428, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."iot_alarm_events_id_seq"
OWNED BY "public"."iot_alarm_events"."id";
SELECT setval('"public"."iot_alarm_events_id_seq"', 58196, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."iot_device_contacts_id_seq"
OWNED BY "public"."iot_device_contacts"."id";
SELECT setval('"public"."iot_device_contacts_id_seq"', 140421, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."iot_device_latest_metrics_id_seq"
OWNED BY "public"."iot_device_latest_metrics"."id";
SELECT setval('"public"."iot_device_latest_metrics_id_seq"', 166202, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."iot_device_params_id_seq"
OWNED BY "public"."iot_device_params"."id";
SELECT setval('"public"."iot_device_params_id_seq"', 546, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."iot_device_types_id_seq"
OWNED BY "public"."iot_device_types"."id";
SELECT setval('"public"."iot_device_types_id_seq"', 1, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."iot_devices_id_seq"
OWNED BY "public"."iot_devices"."id";
SELECT setval('"public"."iot_devices_id_seq"', 19331, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."iot_health_event_items_id_seq"
OWNED BY "public"."iot_health_event_items"."id";
SELECT setval('"public"."iot_health_event_items_id_seq"', 202150, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."iot_health_events_id_seq"
OWNED BY "public"."iot_health_events"."id";
SELECT setval('"public"."iot_health_events_id_seq"', 133872, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."iot_heartbeat_event_items_id_seq"
OWNED BY "public"."iot_heartbeat_event_items"."id";
SELECT setval('"public"."iot_heartbeat_event_items_id_seq"', 3298723, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."iot_heartbeat_events_id_seq"
OWNED BY "public"."iot_heartbeat_events"."id";
SELECT setval('"public"."iot_heartbeat_events_id_seq"', 864839, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."iot_ingest_performance_id_seq"
OWNED BY "public"."iot_ingest_performance"."id";
SELECT setval('"public"."iot_ingest_performance_id_seq"', 124674, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."iot_user_devices_id_seq"
OWNED BY "public"."iot_user_devices"."id";
SELECT setval('"public"."iot_user_devices_id_seq"', 4011, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."patient_profiles_id_seq"
OWNED BY "public"."patient_profiles"."id";
SELECT setval('"public"."patient_profiles_id_seq"', 1, false);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."system_configs_id_seq"
OWNED BY "public"."system_configs"."id";
SELECT setval('"public"."system_configs_id_seq"', 3, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."users_id_seq"
OWNED BY "public"."users"."id";
SELECT setval('"public"."users_id_seq"', 1, true);

-- ----------------------------
-- Indexes structure for table agreements
-- ----------------------------
CREATE INDEX "ix_agreements_id" ON "public"."agreements" USING btree (
  "id" "pg_catalog"."int4_ops" ASC NULLS LAST
);
CREATE UNIQUE INDEX "ix_agreements_type" ON "public"."agreements" USING btree (
  "type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table agreements
-- ----------------------------
ALTER TABLE "public"."agreements" ADD CONSTRAINT "agreements_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table audit_logs
-- ----------------------------
CREATE INDEX "ix_audit_logs_id" ON "public"."audit_logs" USING btree (
  "id" "pg_catalog"."int4_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table audit_logs
-- ----------------------------
ALTER TABLE "public"."audit_logs" ADD CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table chat_sessions
-- ----------------------------
CREATE INDEX "ix_chat_sessions_id" ON "public"."chat_sessions" USING btree (
  "id" "pg_catalog"."int4_ops" ASC NULLS LAST
);
CREATE INDEX "ix_chat_sessions_user_id" ON "public"."chat_sessions" USING btree (
  "user_id" "pg_catalog"."int4_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table chat_sessions
-- ----------------------------
ALTER TABLE "public"."chat_sessions" ADD CONSTRAINT "chat_sessions_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table consultation_records
-- ----------------------------
CREATE INDEX "ix_consultation_records_id" ON "public"."consultation_records" USING btree (
  "id" "pg_catalog"."int4_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table consultation_records
-- ----------------------------
ALTER TABLE "public"."consultation_records" ADD CONSTRAINT "consultation_records_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table high_freq_questions
-- ----------------------------
CREATE INDEX "ix_high_freq_questions_id" ON "public"."high_freq_questions" USING btree (
  "id" "pg_catalog"."int4_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table high_freq_questions
-- ----------------------------
ALTER TABLE "public"."high_freq_questions" ADD CONSTRAINT "high_freq_questions_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table iot_alarm_event_items
-- ----------------------------
CREATE INDEX "idx_iot_alarm_items_event_id" ON "public"."iot_alarm_event_items" USING btree (
  "event_id" "pg_catalog"."int8_ops" ASC NULLS LAST
);
CREATE INDEX "idx_iot_alarm_items_imei_attr_sign_id" ON "public"."iot_alarm_event_items" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "attr_name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST,
  "id" "pg_catalog"."int8_ops" DESC NULLS FIRST
);

-- ----------------------------
-- Primary Key structure for table iot_alarm_event_items
-- ----------------------------
ALTER TABLE "public"."iot_alarm_event_items" ADD CONSTRAINT "iot_alarm_event_items_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table iot_alarm_events
-- ----------------------------
CREATE INDEX "idx_iot_alarm_events_data_type_time" ON "public"."iot_alarm_events" USING btree (
  "data_type" "pg_catalog"."int2_ops" ASC NULLS LAST,
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST
);
CREATE INDEX "idx_iot_alarm_events_device_state_time" ON "public"."iot_alarm_events" USING btree (
  "device_state" "pg_catalog"."int2_ops" ASC NULLS LAST,
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST
);
CREATE INDEX "idx_iot_alarm_events_handler_status_time" ON "public"."iot_alarm_events" USING btree (
  "handler_status" "pg_catalog"."int2_ops" ASC NULLS LAST,
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST
);
CREATE INDEX "idx_iot_alarm_events_imei_sign_time" ON "public"."iot_alarm_events" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST,
  "id" "pg_catalog"."int8_ops" DESC NULLS FIRST
);
CREATE INDEX "idx_iot_alarm_events_type_state_time" ON "public"."iot_alarm_events" USING btree (
  "data_type" "pg_catalog"."int2_ops" ASC NULLS LAST,
  "device_state" "pg_catalog"."int2_ops" ASC NULLS LAST,
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST
);
CREATE UNIQUE INDEX "uq_iot_alarm_events_signature" ON "public"."iot_alarm_events" USING btree (
  "signature" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
) WHERE signature IS NOT NULL;

-- ----------------------------
-- Primary Key structure for table iot_alarm_events
-- ----------------------------
ALTER TABLE "public"."iot_alarm_events" ADD CONSTRAINT "iot_alarm_events_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table iot_device_contacts
-- ----------------------------
CREATE UNIQUE INDEX "idx_imei_phone" ON "public"."iot_device_contacts" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "phone" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);
CREATE INDEX "idx_iot_device_contacts_imei" ON "public"."iot_device_contacts" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table iot_device_contacts
-- ----------------------------
ALTER TABLE "public"."iot_device_contacts" ADD CONSTRAINT "iot_device_contacts_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table iot_device_latest_metrics
-- ----------------------------
CREATE INDEX "idx_iot_latest_metrics_attr_time" ON "public"."iot_device_latest_metrics" USING btree (
  "attr_name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST
);
CREATE UNIQUE INDEX "uq_iot_latest_metrics_imei_attr" ON "public"."iot_device_latest_metrics" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "attr_name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table iot_device_latest_metrics
-- ----------------------------
ALTER TABLE "public"."iot_device_latest_metrics" ADD CONSTRAINT "iot_device_latest_metrics_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table iot_device_params
-- ----------------------------
CREATE INDEX "idx_iot_device_params_imei" ON "public"."iot_device_params" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);
CREATE UNIQUE INDEX "idx_iot_device_params_imei_code_field" ON "public"."iot_device_params" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "param_code" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "field_name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table iot_device_params
-- ----------------------------
ALTER TABLE "public"."iot_device_params" ADD CONSTRAINT "iot_device_params_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table iot_device_types
-- ----------------------------
ALTER TABLE "public"."iot_device_types" ADD CONSTRAINT "iot_device_types_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table iot_devices
-- ----------------------------
CREATE INDEX "idx_iot_devices_imei" ON "public"."iot_devices" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Uniques structure for table iot_devices
-- ----------------------------
ALTER TABLE "public"."iot_devices" ADD CONSTRAINT "iot_devices_imei_key" UNIQUE ("imei");

-- ----------------------------
-- Primary Key structure for table iot_devices
-- ----------------------------
ALTER TABLE "public"."iot_devices" ADD CONSTRAINT "iot_devices_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table iot_file_offsets
-- ----------------------------
CREATE INDEX "idx_iot_file_offsets_status_updated_at" ON "public"."iot_file_offsets" USING btree (
  "status" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "updated_at" "pg_catalog"."timestamp_ops" ASC NULLS LAST
);

-- ----------------------------
-- Checks structure for table iot_file_offsets
-- ----------------------------
ALTER TABLE "public"."iot_file_offsets" ADD CONSTRAINT "iot_file_offsets_offset_bytes_check" CHECK (offset_bytes >= 0);
ALTER TABLE "public"."iot_file_offsets" ADD CONSTRAINT "iot_file_offsets_file_size_check" CHECK (file_size >= 0);

-- ----------------------------
-- Primary Key structure for table iot_file_offsets
-- ----------------------------
ALTER TABLE "public"."iot_file_offsets" ADD CONSTRAINT "iot_file_offsets_pkey" PRIMARY KEY ("file_path");

-- ----------------------------
-- Indexes structure for table iot_health_event_items
-- ----------------------------
CREATE INDEX "idx_iot_health_items_attr_sign_time" ON "public"."iot_health_event_items" USING btree (
  "attr_name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST
);
CREATE INDEX "idx_iot_health_items_event_id" ON "public"."iot_health_event_items" USING btree (
  "event_id" "pg_catalog"."int8_ops" ASC NULLS LAST
);
CREATE INDEX "idx_iot_health_items_imei_attr_sign_id" ON "public"."iot_health_event_items" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "attr_name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST,
  "id" "pg_catalog"."int8_ops" DESC NULLS FIRST
);

-- ----------------------------
-- Primary Key structure for table iot_health_event_items
-- ----------------------------
ALTER TABLE "public"."iot_health_event_items" ADD CONSTRAINT "iot_health_event_items_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table iot_health_events
-- ----------------------------
CREATE INDEX "idx_iot_health_events_imei_sign_time" ON "public"."iot_health_events" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST,
  "id" "pg_catalog"."int8_ops" DESC NULLS FIRST
);
CREATE INDEX "idx_iot_health_events_sign_time" ON "public"."iot_health_events" USING btree (
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST
);
CREATE UNIQUE INDEX "uq_iot_health_events_signature" ON "public"."iot_health_events" USING btree (
  "signature" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
) WHERE signature IS NOT NULL;

-- ----------------------------
-- Primary Key structure for table iot_health_events
-- ----------------------------
ALTER TABLE "public"."iot_health_events" ADD CONSTRAINT "iot_health_events_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table iot_heartbeat_event_items
-- ----------------------------
CREATE INDEX "idx_iot_heartbeat_items_event_id" ON "public"."iot_heartbeat_event_items" USING btree (
  "event_id" "pg_catalog"."int8_ops" ASC NULLS LAST
);
CREATE INDEX "idx_iot_heartbeat_items_imei_attr_sign_id" ON "public"."iot_heartbeat_event_items" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "attr_name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST,
  "id" "pg_catalog"."int8_ops" DESC NULLS FIRST
);

-- ----------------------------
-- Primary Key structure for table iot_heartbeat_event_items
-- ----------------------------
ALTER TABLE "public"."iot_heartbeat_event_items" ADD CONSTRAINT "iot_heartbeat_event_items_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table iot_heartbeat_events
-- ----------------------------
CREATE INDEX "idx_iot_heartbeat_events_imei_sign_time" ON "public"."iot_heartbeat_events" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST,
  "id" "pg_catalog"."int8_ops" DESC NULLS FIRST
);
CREATE INDEX "idx_iot_heartbeat_events_imei_status_time" ON "public"."iot_heartbeat_events" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "handler_status" "pg_catalog"."int2_ops" ASC NULLS LAST,
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST,
  "id" "pg_catalog"."int8_ops" DESC NULLS FIRST
);
CREATE INDEX "idx_iot_heartbeat_events_sign_time" ON "public"."iot_heartbeat_events" USING btree (
  "sign_time" "pg_catalog"."timestamp_ops" DESC NULLS FIRST
);
CREATE UNIQUE INDEX "uq_iot_heartbeat_events_signature" ON "public"."iot_heartbeat_events" USING btree (
  "signature" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
) WHERE signature IS NOT NULL;

-- ----------------------------
-- Primary Key structure for table iot_heartbeat_events
-- ----------------------------
ALTER TABLE "public"."iot_heartbeat_events" ADD CONSTRAINT "iot_heartbeat_events_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table iot_ingest_performance
-- ----------------------------
CREATE INDEX "idx_iot_ingest_performance_imei_created" ON "public"."iot_ingest_performance" USING btree (
  "imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "created_at" "pg_catalog"."timestamp_ops" DESC NULLS FIRST
);
CREATE INDEX "idx_iot_ingest_performance_run_id" ON "public"."iot_ingest_performance" USING btree (
  "run_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);
CREATE UNIQUE INDEX "uq_iot_ingest_performance_signature" ON "public"."iot_ingest_performance" USING btree (
  "signature" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
) WHERE signature IS NOT NULL;

-- ----------------------------
-- Primary Key structure for table iot_ingest_performance
-- ----------------------------
ALTER TABLE "public"."iot_ingest_performance" ADD CONSTRAINT "iot_ingest_performance_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table iot_user_devices
-- ----------------------------
CREATE UNIQUE INDEX "idx_iot_user_devices_user_device_imei" ON "public"."iot_user_devices" USING btree (
  "user_id" "pg_catalog"."int8_ops" ASC NULLS LAST,
  "device_id" "pg_catalog"."int8_ops" ASC NULLS LAST,
  "device_imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);
CREATE INDEX "idx_iot_user_devices_user_imei_status" ON "public"."iot_user_devices" USING btree (
  "user_id" "pg_catalog"."int8_ops" ASC NULLS LAST,
  "device_imei" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "status" "pg_catalog"."int2_ops" ASC NULLS LAST
);
CREATE UNIQUE INDEX "idx_user_device" ON "public"."iot_user_devices" USING btree (
  "user_id" "pg_catalog"."int8_ops" ASC NULLS LAST,
  "device_id" "pg_catalog"."int8_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table iot_user_devices
-- ----------------------------
ALTER TABLE "public"."iot_user_devices" ADD CONSTRAINT "iot_user_devices_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table patient_profiles
-- ----------------------------
CREATE INDEX "ix_patient_profiles_id" ON "public"."patient_profiles" USING btree (
  "id" "pg_catalog"."int4_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table patient_profiles
-- ----------------------------
ALTER TABLE "public"."patient_profiles" ADD CONSTRAINT "patient_profiles_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table system_configs
-- ----------------------------
CREATE INDEX "ix_system_configs_id" ON "public"."system_configs" USING btree (
  "id" "pg_catalog"."int4_ops" ASC NULLS LAST
);
CREATE UNIQUE INDEX "ix_system_configs_key" ON "public"."system_configs" USING btree (
  "key" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table system_configs
-- ----------------------------
ALTER TABLE "public"."system_configs" ADD CONSTRAINT "system_configs_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table users
-- ----------------------------
CREATE INDEX "ix_users_id" ON "public"."users" USING btree (
  "id" "pg_catalog"."int4_ops" ASC NULLS LAST
);
CREATE UNIQUE INDEX "ix_users_phone" ON "public"."users" USING btree (
  "phone" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table users
-- ----------------------------
ALTER TABLE "public"."users" ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Foreign Keys structure for table audit_logs
-- ----------------------------
ALTER TABLE "public"."audit_logs" ADD CONSTRAINT "audit_logs_admin_id_fkey" FOREIGN KEY ("admin_id") REFERENCES "public"."users" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Keys structure for table chat_sessions
-- ----------------------------
ALTER TABLE "public"."chat_sessions" ADD CONSTRAINT "chat_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Keys structure for table consultation_records
-- ----------------------------
ALTER TABLE "public"."consultation_records" ADD CONSTRAINT "consultation_records_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."patient_profiles" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Keys structure for table patient_profiles
-- ----------------------------
ALTER TABLE "public"."patient_profiles" ADD CONSTRAINT "patient_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;
