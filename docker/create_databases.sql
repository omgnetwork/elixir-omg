CREATE USER feefeed;
ALTER USER feefeed CREATEDB;
ALTER USER feefeed WITH PASSWORD 'feefeed';
CREATE DATABASE feefeed;
GRANT ALL PRIVILEGES ON DATABASE feefeed TO feefeed;

CREATE USER engine_repo;
ALTER USER engine_repo CREATEDB;
ALTER USER engine_repo WITH PASSWORD 'engine_repo';
CREATE DATABASE engine_repo;
GRANT ALL PRIVILEGES ON DATABASE engine_repo TO engine_repo;

CREATE USER omisego_dev;
ALTER USER omisego_dev CREATEDB;
ALTER USER omisego_dev WITH PASSWORD 'omisego_dev';
CREATE DATABASE omisego_dev;
GRANT ALL PRIVILEGES ON DATABASE omisego_dev TO omisego_dev;

CREATE DATABASE omisego_test;
GRANT ALL PRIVILEGES ON DATABASE omisego_test TO omisego_dev;
