-- =============================================================
-- Oracle Target Setup
-- Run as SYSDBA against the CDB root (XE)
-- Creates the application user inside XEPDB1
-- =============================================================

-- Switch to the PDB where application data lives
ALTER SESSION SET CONTAINER = XEPDB1;

CREATE USER app_user IDENTIFIED BY app_password
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO app_user;

COMMIT;
