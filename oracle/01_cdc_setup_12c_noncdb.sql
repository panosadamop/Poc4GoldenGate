-- =============================================================
-- Oracle 12c NON-CDB LogMiner setup for Debezium
-- Verify deployment type first:
--   SELECT CDB FROM V$DATABASE;  → must return NO
-- Run as SYSDBA against the instance SID (not a PDB)
-- =============================================================

-- Confirm non-CDB
SELECT INSTANCE_NAME, CDB, VERSION FROM V$INSTANCE, V$DATABASE;
-- CDB = NO expected. If CDB = YES, use 01_cdc_setup.sql instead.

-- =============================================================
-- Enable ARCHIVELOG mode
-- Skip if already enabled (SELECT LOG_MODE FROM V$DATABASE;)
-- =============================================================
-- SHUTDOWN IMMEDIATE;
-- STARTUP MOUNT;
-- ALTER DATABASE ARCHIVELOG;
-- ALTER DATABASE OPEN;

-- Verify
SELECT LOG_MODE FROM V$DATABASE;  -- must be ARCHIVELOG

-- =============================================================
-- Supplemental logging at the database level
-- =============================================================
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Verify
SELECT SUPPLEMENTAL_LOG_DATA_MIN,
       SUPPLEMENTAL_LOG_DATA_ALL
FROM   V$DATABASE;

-- =============================================================
-- Archive log retention
-- Retain at least 72 hours to survive connector restarts.
-- =============================================================
-- Adjust for your environment; at minimum cover your peak
-- connector lag window plus one restart cycle.
EXECUTE DBMS_LOGMNR_D.SET_TABLESPACE('SYSAUX');

-- =============================================================
-- Create the Debezium LogMiner user
-- Non-CDB: no c## prefix required.
-- =============================================================
CREATE USER dbzuser IDENTIFIED BY dbzpassword
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

-- Core session and mining privileges
GRANT CREATE SESSION              TO dbzuser;
GRANT SELECT ANY TRANSACTION      TO dbzuser;
GRANT SELECT ANY DICTIONARY       TO dbzuser;

-- LOGMINING system privilege is available from Oracle 12.2 only.
-- If on Oracle 12.1, skip this line and use the DBMS_LOGMNR EXECUTE grants below.
GRANT LOGMINING                   TO dbzuser;

-- LogMiner execution privileges (required on ALL 12c versions)
GRANT EXECUTE ON SYS.DBMS_LOGMNR    TO dbzuser;
GRANT EXECUTE ON SYS.DBMS_LOGMNR_D  TO dbzuser;

-- Dynamic performance views required by the connector
GRANT SELECT ON V_$LOG                  TO dbzuser;
GRANT SELECT ON V_$LOG_HISTORY          TO dbzuser;
GRANT SELECT ON V_$LOGMNR_LOGS         TO dbzuser;
GRANT SELECT ON V_$LOGMNR_CONTENTS     TO dbzuser;
GRANT SELECT ON V_$LOGMNR_PARAMETERS   TO dbzuser;
GRANT SELECT ON V_$LOGFILE             TO dbzuser;
GRANT SELECT ON V_$ARCHIVED_LOG        TO dbzuser;
GRANT SELECT ON V_$ARCHIVE_DEST_STATUS TO dbzuser;
GRANT SELECT ON V_$TRANSACTION         TO dbzuser;
GRANT SELECT ON V_$INSTANCE            TO dbzuser;
GRANT SELECT ON V_$DATABASE            TO dbzuser;

-- =============================================================
-- If on Oracle 12.1 (no LOGMINING privilege available):
-- Uncomment and run these instead of GRANT LOGMINING:
-- GRANT EXECUTE ON SYS.DBMS_LOGMNR   TO dbzuser;
-- GRANT EXECUTE ON SYS.DBMS_LOGMNR_D TO dbzuser;
-- (The EXECUTE grants plus SELECT ANY DICTIONARY are sufficient
--  for LogMiner-based CDC on 12.1.)
-- =============================================================

-- =============================================================
-- Application schema: enable per-table supplemental logging
-- Run this after your application tables are created.
-- Repeat for every table included in table.include.list.
-- =============================================================

-- Example for a schema called APP_USER:
-- ALTER TABLE APP_USER.CUSTOMERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
-- ALTER TABLE APP_USER.ORDERS    ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
-- ALTER TABLE APP_USER.ORDER_ITEMS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Grant SELECT on application tables to dbzuser
-- (required for snapshot reads):
-- GRANT SELECT ON APP_USER.CUSTOMERS  TO dbzuser;
-- GRANT SELECT ON APP_USER.ORDERS     TO dbzuser;
-- GRANT SELECT ON APP_USER.ORDER_ITEMS TO dbzuser;

COMMIT;

-- =============================================================
-- Verification queries
-- =============================================================
-- Check supplemental logging:
SELECT LOG_MODE,
       SUPPLEMENTAL_LOG_DATA_MIN,
       SUPPLEMENTAL_LOG_DATA_ALL
FROM   V$DATABASE;

-- Check dbzuser privileges:
SELECT PRIVILEGE FROM DBA_SYS_PRIVS WHERE GRANTEE = 'DBZUSER' ORDER BY 1;
SELECT OWNER, TABLE_NAME, PRIVILEGE FROM DBA_TAB_PRIVS WHERE GRANTEE = 'DBZUSER' ORDER BY 1,2;
