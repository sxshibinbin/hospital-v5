--
-- PostgreSQL database dump
--

\restrict XIgQyiELWbp55VQqX1wqr9iKh8sNj1jhdJAdElJCe0StUcIzSyHJLHKjrkc2DWs

-- Dumped from database version 16.11
-- Dumped by pg_dump version 16.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: agreements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agreements (
    id integer NOT NULL,
    type character varying(50) NOT NULL,
    title character varying(100) NOT NULL,
    content text NOT NULL,
    updated_at timestamp(6) without time zone
);


--
-- Name: agreements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agreements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: agreements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agreements_id_seq OWNED BY public.agreements.id;


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id integer NOT NULL,
    admin_id integer,
    action character varying(50),
    target_id character varying(50),
    details character varying(500),
    created_at timestamp(6) without time zone
);


--
-- Name: audit_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: audit_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_logs_id_seq OWNED BY public.audit_logs.id;


--
-- Name: chat_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_sessions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    title character varying(120) NOT NULL,
    mode character varying(20) NOT NULL,
    messages_json text NOT NULL,
    is_active boolean,
    token_count integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: chat_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: chat_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_sessions_id_seq OWNED BY public.chat_sessions.id;


--
-- Name: consultation_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consultation_records (
    id integer NOT NULL,
    profile_id integer,
    symptoms text,
    diagnosis text,
    advice text,
    department character varying(100),
    chat_history text,
    created_at timestamp(6) without time zone
);


--
-- Name: consultation_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.consultation_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: consultation_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.consultation_records_id_seq OWNED BY public.consultation_records.id;


--
-- Name: high_freq_questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.high_freq_questions (
    id integer NOT NULL,
    question character varying(200) NOT NULL,
    answer_template text NOT NULL,
    category character varying(50),
    click_count integer,
    is_top boolean,
    status character varying(20),
    sort_weight integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: high_freq_questions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.high_freq_questions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: high_freq_questions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.high_freq_questions_id_seq OWNED BY public.high_freq_questions.id;


--
-- Name: iot_alarm_event_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_alarm_event_items (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    imei character varying(32) NOT NULL,
    attr_name character varying(64),
    attr_value character varying(128),
    sign_time timestamp(6) without time zone,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: iot_alarm_event_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iot_alarm_event_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iot_alarm_event_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iot_alarm_event_items_id_seq OWNED BY public.iot_alarm_event_items.id;


--
-- Name: iot_alarm_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_alarm_events (
    id bigint NOT NULL,
    imei character varying(32) NOT NULL,
    event_name character varying(64),
    data_type smallint,
    device_state smallint,
    sign_time timestamp(6) without time zone,
    signature character varying(64),
    nonce character varying(32),
    raw_data text,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    handler_status smallint DEFAULT 0 NOT NULL,
    handle_time timestamp(6) without time zone,
    alarm_reason character varying(128)
);


--
-- Name: iot_alarm_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iot_alarm_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iot_alarm_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iot_alarm_events_id_seq OWNED BY public.iot_alarm_events.id;


--
-- Name: iot_device_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_device_contacts (
    id bigint NOT NULL,
    imei character varying(32) NOT NULL,
    name character varying(64),
    phone character varying(20),
    contact_type smallint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: iot_device_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iot_device_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iot_device_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iot_device_contacts_id_seq OWNED BY public.iot_device_contacts.id;


--
-- Name: iot_device_latest_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_device_latest_metrics (
    id bigint NOT NULL,
    imei character varying(32) NOT NULL,
    attr_name character varying(64),
    attr_value double precision,
    sign_time timestamp(6) without time zone,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    attr_value_text character varying(128)
);


--
-- Name: iot_device_latest_metrics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iot_device_latest_metrics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iot_device_latest_metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iot_device_latest_metrics_id_seq OWNED BY public.iot_device_latest_metrics.id;


--
-- Name: iot_device_params; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_device_params (
    id bigint NOT NULL,
    imei character varying(32) NOT NULL,
    param_code character varying(32) NOT NULL,
    field_name character varying(32) DEFAULT ''::character varying NOT NULL,
    param_value character varying(64),
    create_by character varying(32) NOT NULL,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: iot_device_params_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iot_device_params_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iot_device_params_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iot_device_params_id_seq OWNED BY public.iot_device_params.id;


--
-- Name: iot_device_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_device_types (
    id bigint NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(128) NOT NULL,
    status smallint DEFAULT 1,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: iot_device_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iot_device_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iot_device_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iot_device_types_id_seq OWNED BY public.iot_device_types.id;


--
-- Name: iot_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_devices (
    id bigint NOT NULL,
    imei character varying(32) NOT NULL,
    iccid character varying(32),
    device_type character varying(64),
    device_version character varying(64),
    device_state smallint DEFAULT 0,
    longitude numeric(12,8),
    latitude numeric(12,8),
    site character varying(256),
    company_name character varying(128),
    enabled_time timestamp(6) without time zone,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    room_name character varying(128),
    device_model_id bigint
);


--
-- Name: iot_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iot_devices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iot_devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iot_devices_id_seq OWNED BY public.iot_devices.id;


--
-- Name: iot_file_offsets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_file_offsets (
    file_path text NOT NULL,
    offset_bytes bigint DEFAULT 0 NOT NULL,
    file_size bigint DEFAULT 0 NOT NULL,
    status character varying(16) DEFAULT 'processing'::character varying NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    completed_at timestamp(6) without time zone,
    CONSTRAINT iot_file_offsets_file_size_check CHECK ((file_size >= 0)),
    CONSTRAINT iot_file_offsets_offset_bytes_check CHECK ((offset_bytes >= 0))
);


--
-- Name: iot_health_event_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_health_event_items (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    imei character varying(32) NOT NULL,
    attr_name character varying(64),
    attr_value double precision,
    sign_time timestamp(6) without time zone,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    prop_value character varying(128)
);


--
-- Name: iot_health_event_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iot_health_event_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iot_health_event_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iot_health_event_items_id_seq OWNED BY public.iot_health_event_items.id;


--
-- Name: iot_health_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_health_events (
    id bigint NOT NULL,
    imei character varying(32) NOT NULL,
    event_name character varying(64),
    data_type smallint,
    device_state smallint,
    sign_time timestamp(6) without time zone,
    signature character varying(64),
    nonce character varying(32),
    raw_data text,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: iot_health_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iot_health_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iot_health_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iot_health_events_id_seq OWNED BY public.iot_health_events.id;


--
-- Name: iot_heartbeat_event_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_heartbeat_event_items (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    imei character varying(32) NOT NULL,
    attr_name character varying(64),
    attr_value character varying(128),
    sign_time timestamp(6) without time zone,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: iot_heartbeat_event_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iot_heartbeat_event_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iot_heartbeat_event_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iot_heartbeat_event_items_id_seq OWNED BY public.iot_heartbeat_event_items.id;


--
-- Name: iot_heartbeat_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_heartbeat_events (
    id bigint NOT NULL,
    imei character varying(32) NOT NULL,
    event_name character varying(64),
    data_type smallint,
    device_state smallint,
    sign_time timestamp(6) without time zone,
    signature character varying(64),
    nonce character varying(32),
    raw_data text,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    handler_status smallint DEFAULT 0 NOT NULL,
    handle_time timestamp(6) without time zone,
    alarm_reason character varying(128)
);


--
-- Name: iot_heartbeat_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iot_heartbeat_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iot_heartbeat_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iot_heartbeat_events_id_seq OWNED BY public.iot_heartbeat_events.id;


--
-- Name: iot_ingest_performance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_ingest_performance (
    id bigint NOT NULL,
    run_id character varying(80),
    trace_id character varying(128),
    seq bigint,
    imei character varying(32),
    event_name character varying(64),
    event_kind character varying(64),
    signature character varying(64),
    client_send_ms double precision,
    api_received_ms double precision,
    file_write_ms double precision,
    file_read_ms double precision,
    db_write_ms double precision NOT NULL,
    file_path text,
    file_offset_bytes bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: iot_ingest_performance_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iot_ingest_performance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iot_ingest_performance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iot_ingest_performance_id_seq OWNED BY public.iot_ingest_performance.id;


--
-- Name: iot_user_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iot_user_devices (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    device_id bigint NOT NULL,
    device_imei character varying(32) NOT NULL,
    status smallint DEFAULT 1,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: iot_user_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iot_user_devices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iot_user_devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iot_user_devices_id_seq OWNED BY public.iot_user_devices.id;


--
-- Name: patient_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.patient_profiles (
    id integer NOT NULL,
    user_id integer,
    name character varying(50) NOT NULL,
    relation character varying(20) NOT NULL,
    gender character varying(10) NOT NULL,
    age integer NOT NULL,
    medical_history text,
    allergies text,
    created_at timestamp(6) without time zone
);


--
-- Name: patient_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.patient_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: patient_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.patient_profiles_id_seq OWNED BY public.patient_profiles.id;


--
-- Name: system_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_configs (
    id integer NOT NULL,
    key character varying(50),
    value character varying(200),
    description character varying(200),
    updated_at timestamp(6) without time zone
);


--
-- Name: system_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: system_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.system_configs_id_seq OWNED BY public.system_configs.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    phone character varying(20) NOT NULL,
    hashed_password character varying,
    display_name character varying(100),
    avatar_key character varying(50),
    is_admin boolean,
    is_active boolean,
    created_at timestamp(6) without time zone
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: agreements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreements ALTER COLUMN id SET DEFAULT nextval('public.agreements_id_seq'::regclass);


--
-- Name: audit_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs ALTER COLUMN id SET DEFAULT nextval('public.audit_logs_id_seq'::regclass);


--
-- Name: chat_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_sessions ALTER COLUMN id SET DEFAULT nextval('public.chat_sessions_id_seq'::regclass);


--
-- Name: consultation_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consultation_records ALTER COLUMN id SET DEFAULT nextval('public.consultation_records_id_seq'::regclass);


--
-- Name: high_freq_questions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.high_freq_questions ALTER COLUMN id SET DEFAULT nextval('public.high_freq_questions_id_seq'::regclass);


--
-- Name: iot_alarm_event_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_alarm_event_items ALTER COLUMN id SET DEFAULT nextval('public.iot_alarm_event_items_id_seq'::regclass);


--
-- Name: iot_alarm_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_alarm_events ALTER COLUMN id SET DEFAULT nextval('public.iot_alarm_events_id_seq'::regclass);


--
-- Name: iot_device_contacts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_device_contacts ALTER COLUMN id SET DEFAULT nextval('public.iot_device_contacts_id_seq'::regclass);


--
-- Name: iot_device_latest_metrics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_device_latest_metrics ALTER COLUMN id SET DEFAULT nextval('public.iot_device_latest_metrics_id_seq'::regclass);


--
-- Name: iot_device_params id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_device_params ALTER COLUMN id SET DEFAULT nextval('public.iot_device_params_id_seq'::regclass);


--
-- Name: iot_device_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_device_types ALTER COLUMN id SET DEFAULT nextval('public.iot_device_types_id_seq'::regclass);


--
-- Name: iot_devices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_devices ALTER COLUMN id SET DEFAULT nextval('public.iot_devices_id_seq'::regclass);


--
-- Name: iot_health_event_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_health_event_items ALTER COLUMN id SET DEFAULT nextval('public.iot_health_event_items_id_seq'::regclass);


--
-- Name: iot_health_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_health_events ALTER COLUMN id SET DEFAULT nextval('public.iot_health_events_id_seq'::regclass);


--
-- Name: iot_heartbeat_event_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_heartbeat_event_items ALTER COLUMN id SET DEFAULT nextval('public.iot_heartbeat_event_items_id_seq'::regclass);


--
-- Name: iot_heartbeat_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_heartbeat_events ALTER COLUMN id SET DEFAULT nextval('public.iot_heartbeat_events_id_seq'::regclass);


--
-- Name: iot_ingest_performance id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_ingest_performance ALTER COLUMN id SET DEFAULT nextval('public.iot_ingest_performance_id_seq'::regclass);


--
-- Name: iot_user_devices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_user_devices ALTER COLUMN id SET DEFAULT nextval('public.iot_user_devices_id_seq'::regclass);


--
-- Name: patient_profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patient_profiles ALTER COLUMN id SET DEFAULT nextval('public.patient_profiles_id_seq'::regclass);


--
-- Name: system_configs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_configs ALTER COLUMN id SET DEFAULT nextval('public.system_configs_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: agreements agreements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreements
    ADD CONSTRAINT agreements_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: chat_sessions chat_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_sessions
    ADD CONSTRAINT chat_sessions_pkey PRIMARY KEY (id);


--
-- Name: consultation_records consultation_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consultation_records
    ADD CONSTRAINT consultation_records_pkey PRIMARY KEY (id);


--
-- Name: high_freq_questions high_freq_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.high_freq_questions
    ADD CONSTRAINT high_freq_questions_pkey PRIMARY KEY (id);


--
-- Name: iot_alarm_event_items iot_alarm_event_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_alarm_event_items
    ADD CONSTRAINT iot_alarm_event_items_pkey PRIMARY KEY (id);


--
-- Name: iot_alarm_events iot_alarm_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_alarm_events
    ADD CONSTRAINT iot_alarm_events_pkey PRIMARY KEY (id);


--
-- Name: iot_device_contacts iot_device_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_device_contacts
    ADD CONSTRAINT iot_device_contacts_pkey PRIMARY KEY (id);


--
-- Name: iot_device_latest_metrics iot_device_latest_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_device_latest_metrics
    ADD CONSTRAINT iot_device_latest_metrics_pkey PRIMARY KEY (id);


--
-- Name: iot_device_params iot_device_params_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_device_params
    ADD CONSTRAINT iot_device_params_pkey PRIMARY KEY (id);


--
-- Name: iot_device_types iot_device_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_device_types
    ADD CONSTRAINT iot_device_types_pkey PRIMARY KEY (id);


--
-- Name: iot_devices iot_devices_imei_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_devices
    ADD CONSTRAINT iot_devices_imei_key UNIQUE (imei);


--
-- Name: iot_devices iot_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_devices
    ADD CONSTRAINT iot_devices_pkey PRIMARY KEY (id);


--
-- Name: iot_file_offsets iot_file_offsets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_file_offsets
    ADD CONSTRAINT iot_file_offsets_pkey PRIMARY KEY (file_path);


--
-- Name: iot_health_event_items iot_health_event_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_health_event_items
    ADD CONSTRAINT iot_health_event_items_pkey PRIMARY KEY (id);


--
-- Name: iot_health_events iot_health_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_health_events
    ADD CONSTRAINT iot_health_events_pkey PRIMARY KEY (id);


--
-- Name: iot_heartbeat_event_items iot_heartbeat_event_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_heartbeat_event_items
    ADD CONSTRAINT iot_heartbeat_event_items_pkey PRIMARY KEY (id);


--
-- Name: iot_heartbeat_events iot_heartbeat_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_heartbeat_events
    ADD CONSTRAINT iot_heartbeat_events_pkey PRIMARY KEY (id);


--
-- Name: iot_ingest_performance iot_ingest_performance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_ingest_performance
    ADD CONSTRAINT iot_ingest_performance_pkey PRIMARY KEY (id);


--
-- Name: iot_user_devices iot_user_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iot_user_devices
    ADD CONSTRAINT iot_user_devices_pkey PRIMARY KEY (id);


--
-- Name: patient_profiles patient_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patient_profiles
    ADD CONSTRAINT patient_profiles_pkey PRIMARY KEY (id);


--
-- Name: system_configs system_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_configs
    ADD CONSTRAINT system_configs_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_imei_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_imei_phone ON public.iot_device_contacts USING btree (imei, phone);


--
-- Name: idx_iot_alarm_events_data_type_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_alarm_events_data_type_time ON public.iot_alarm_events USING btree (data_type, sign_time DESC);


--
-- Name: idx_iot_alarm_events_device_state_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_alarm_events_device_state_time ON public.iot_alarm_events USING btree (device_state, sign_time DESC);


--
-- Name: idx_iot_alarm_events_handler_status_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_alarm_events_handler_status_time ON public.iot_alarm_events USING btree (handler_status, sign_time DESC);


--
-- Name: idx_iot_alarm_events_imei_sign_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_alarm_events_imei_sign_time ON public.iot_alarm_events USING btree (imei, sign_time DESC, id DESC);


--
-- Name: idx_iot_alarm_events_type_state_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_alarm_events_type_state_time ON public.iot_alarm_events USING btree (data_type, device_state, sign_time DESC);


--
-- Name: idx_iot_alarm_items_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_alarm_items_event_id ON public.iot_alarm_event_items USING btree (event_id);


--
-- Name: idx_iot_alarm_items_imei_attr_sign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_alarm_items_imei_attr_sign_id ON public.iot_alarm_event_items USING btree (imei, attr_name, sign_time DESC, id DESC);


--
-- Name: idx_iot_device_contacts_imei; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_device_contacts_imei ON public.iot_device_contacts USING btree (imei);


--
-- Name: idx_iot_device_params_imei; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_device_params_imei ON public.iot_device_params USING btree (imei);


--
-- Name: idx_iot_device_params_imei_code_field; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_iot_device_params_imei_code_field ON public.iot_device_params USING btree (imei, param_code, field_name);


--
-- Name: idx_iot_devices_imei; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_devices_imei ON public.iot_devices USING btree (imei);


--
-- Name: idx_iot_file_offsets_status_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_file_offsets_status_updated_at ON public.iot_file_offsets USING btree (status, updated_at);


--
-- Name: idx_iot_health_events_imei_sign_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_health_events_imei_sign_time ON public.iot_health_events USING btree (imei, sign_time DESC, id DESC);


--
-- Name: idx_iot_health_events_sign_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_health_events_sign_time ON public.iot_health_events USING btree (sign_time DESC);


--
-- Name: idx_iot_health_items_attr_sign_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_health_items_attr_sign_time ON public.iot_health_event_items USING btree (attr_name, sign_time DESC);


--
-- Name: idx_iot_health_items_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_health_items_event_id ON public.iot_health_event_items USING btree (event_id);


--
-- Name: idx_iot_health_items_imei_attr_sign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_health_items_imei_attr_sign_id ON public.iot_health_event_items USING btree (imei, attr_name, sign_time DESC, id DESC);


--
-- Name: idx_iot_heartbeat_events_imei_sign_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_heartbeat_events_imei_sign_time ON public.iot_heartbeat_events USING btree (imei, sign_time DESC, id DESC);


--
-- Name: idx_iot_heartbeat_events_imei_status_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_heartbeat_events_imei_status_time ON public.iot_heartbeat_events USING btree (imei, handler_status, sign_time DESC, id DESC);


--
-- Name: idx_iot_heartbeat_events_sign_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_heartbeat_events_sign_time ON public.iot_heartbeat_events USING btree (sign_time DESC);


--
-- Name: idx_iot_heartbeat_items_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_heartbeat_items_event_id ON public.iot_heartbeat_event_items USING btree (event_id);


--
-- Name: idx_iot_heartbeat_items_imei_attr_sign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_heartbeat_items_imei_attr_sign_id ON public.iot_heartbeat_event_items USING btree (imei, attr_name, sign_time DESC, id DESC);


--
-- Name: idx_iot_ingest_performance_imei_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_ingest_performance_imei_created ON public.iot_ingest_performance USING btree (imei, created_at DESC);


--
-- Name: idx_iot_ingest_performance_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_ingest_performance_run_id ON public.iot_ingest_performance USING btree (run_id);


--
-- Name: idx_iot_latest_metrics_attr_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_latest_metrics_attr_time ON public.iot_device_latest_metrics USING btree (attr_name, sign_time DESC);


--
-- Name: idx_iot_user_devices_user_device_imei; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_iot_user_devices_user_device_imei ON public.iot_user_devices USING btree (user_id, device_id, device_imei);


--
-- Name: idx_iot_user_devices_user_imei_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_iot_user_devices_user_imei_status ON public.iot_user_devices USING btree (user_id, device_imei, status);


--
-- Name: idx_user_device; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_user_device ON public.iot_user_devices USING btree (user_id, device_id);


--
-- Name: ix_agreements_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_agreements_id ON public.agreements USING btree (id);


--
-- Name: ix_agreements_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_agreements_type ON public.agreements USING btree (type);


--
-- Name: ix_audit_logs_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_audit_logs_id ON public.audit_logs USING btree (id);


--
-- Name: ix_chat_sessions_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chat_sessions_id ON public.chat_sessions USING btree (id);


--
-- Name: ix_chat_sessions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chat_sessions_user_id ON public.chat_sessions USING btree (user_id);


--
-- Name: ix_consultation_records_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_consultation_records_id ON public.consultation_records USING btree (id);


--
-- Name: ix_high_freq_questions_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_high_freq_questions_id ON public.high_freq_questions USING btree (id);


--
-- Name: ix_patient_profiles_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_patient_profiles_id ON public.patient_profiles USING btree (id);


--
-- Name: ix_system_configs_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_system_configs_id ON public.system_configs USING btree (id);


--
-- Name: ix_system_configs_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_system_configs_key ON public.system_configs USING btree (key);


--
-- Name: ix_users_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_users_id ON public.users USING btree (id);


--
-- Name: ix_users_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_users_phone ON public.users USING btree (phone);


--
-- Name: uq_iot_alarm_events_signature; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_iot_alarm_events_signature ON public.iot_alarm_events USING btree (signature) WHERE (signature IS NOT NULL);


--
-- Name: uq_iot_health_events_signature; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_iot_health_events_signature ON public.iot_health_events USING btree (signature) WHERE (signature IS NOT NULL);


--
-- Name: uq_iot_heartbeat_events_signature; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_iot_heartbeat_events_signature ON public.iot_heartbeat_events USING btree (signature) WHERE (signature IS NOT NULL);


--
-- Name: uq_iot_ingest_performance_signature; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_iot_ingest_performance_signature ON public.iot_ingest_performance USING btree (signature) WHERE (signature IS NOT NULL);


--
-- Name: uq_iot_latest_metrics_imei_attr; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_iot_latest_metrics_imei_attr ON public.iot_device_latest_metrics USING btree (imei, attr_name);


--
-- Name: audit_logs audit_logs_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.users(id);


--
-- Name: chat_sessions chat_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_sessions
    ADD CONSTRAINT chat_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: consultation_records consultation_records_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consultation_records
    ADD CONSTRAINT consultation_records_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.patient_profiles(id);


--
-- Name: patient_profiles patient_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patient_profiles
    ADD CONSTRAINT patient_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

\unrestrict XIgQyiELWbp55VQqX1wqr9iKh8sNj1jhdJAdElJCe0StUcIzSyHJLHKjrkc2DWs