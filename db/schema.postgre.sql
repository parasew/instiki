CREATE TABLE pages (
    id serial primary key,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    web_id integer NOT NULL,
    locked_by character varying(60),
    name character varying(60),
    locked_at timestamp without time zone
);

CREATE TABLE revisions (
    id serial primary key,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    page_id integer NOT NULL,
    content text NOT NULL,
    author character varying(60),
    ip character varying(60),
    number integer
);

CREATE TABLE system (
    id serial primary key,
    "password" character varying(60)
);

CREATE TABLE webs (
    id serial primary key,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying(60) NOT NULL,
    address character varying(60) NOT NULL,
    "password" character varying(60),
    additional_style character varying(255),
    allow_uploads boolean DEFAULT true,
    published boolean DEFAULT false,
    count_pages boolean DEFAULT false,
    markup character varying(50) DEFAULT 'textile'::character varying,
    color character varying(6) DEFAULT '008B26'::character varying,
    max_upload_size integer DEFAULT 100,
    safe_mode boolean DEFAULT false,
    brackets_only boolean DEFAULT false
);
