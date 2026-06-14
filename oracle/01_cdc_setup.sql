-- =============================================================
-- Oracle CDC Setup for Debezium
-- Run as SYSDBA against the CDB (XE)
-- =============================================================

-- Enable ARCHIVELOG mode (Oracle XE 21c has it enabled by default;
-- included here for completeness on other editions)
-- SHUTDOWN IMMEDIATE;
-- STARTUP MOUNT;
-- ALTER DATABASE ARCHIVELOG;
-- ALTER DATABASE OPEN;

-- Enable supplemental logging at the database level
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Verify supplemental logging
SELECT LOG_MODE, SUPPLEMENTAL_LOG_DATA_MIN FROM V$DATABASE;

-- =============================================================
-- Create Debezium LogMiner user in the CDB (c## prefix required)
-- =============================================================
CREATE USER c##dbzuser IDENTIFIED BY dbzpassword
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS
  CONTAINER = ALL;

-- Minimum privileges for LogMiner-based CDC
GRANT CREATE SESSION                TO c##dbzuser CONTAINER = ALL;
GRANT SET CONTAINER                 TO c##dbzuser CONTAINER = ALL;
GRANT SELECT ANY TRANSACTION        TO c##dbzuser CONTAINER = ALL;
GRANT SELECT ANY DICTIONARY         TO c##dbzuser CONTAINER = ALL;
GRANT LOGMINING                     TO c##dbzuser CONTAINER = ALL;
GRANT EXECUTE ON SYS.DBMS_LOGMNR    TO c##dbzuser CONTAINER = ALL;
GRANT EXECUTE ON SYS.DBMS_LOGMNR_D  TO c##dbzuser CONTAINER = ALL;
GRANT SELECT ON V_$LOG               TO c##dbzuser CONTAINER = ALL;
GRANT SELECT ON V_$LOG_HISTORY       TO c##dbzuser CONTAINER = ALL;
GRANT SELECT ON V_$LOGMNR_LOGS       TO c##dbzuser CONTAINER = ALL;
GRANT SELECT ON V_$LOGMNR_CONTENTS   TO c##dbzuser CONTAINER = ALL;
GRANT SELECT ON V_$LOGMNR_PARAMETERS TO c##dbzuser CONTAINER = ALL;
GRANT SELECT ON V_$LOGFILE           TO c##dbzuser CONTAINER = ALL;
GRANT SELECT ON V_$ARCHIVED_LOG      TO c##dbzuser CONTAINER = ALL;
GRANT SELECT ON V_$ARCHIVE_DEST_STATUS TO c##dbzuser CONTAINER = ALL;
GRANT SELECT ON V_$TRANSACTION       TO c##dbzuser CONTAINER = ALL;
GRANT SELECT ON V_$INSTANCE          TO c##dbzuser CONTAINER = ALL;
GRANT SELECT ON V_$DATABASE          TO c##dbzuser CONTAINER = ALL;

-- =============================================================
-- Switch to the PDB and create the application schema
-- =============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

-- Application schema user
CREATE USER app_user IDENTIFIED BY app_password
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CONNECT, RESOURCE TO app_user;

-- Grant SELECT on app_user tables to the CDC user
GRANT SELECT ON app_user.CUSTOMERS TO c##dbzuser;
GRANT SELECT ON app_user.ORDERS    TO c##dbzuser;
GRANT SELECT ON app_user.ORDER_ITEMS TO c##dbzuser;

COMMIT;
