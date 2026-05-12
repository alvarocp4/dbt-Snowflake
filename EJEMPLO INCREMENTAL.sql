--================================================================================--
--================================================================================--
                        -- Example for incremental model --
--================================================================================--
--================================================================================--

select * from fact_mktv_visitas_trans;

-- 1. INSERT INTO ORIGIN TABLE
INSERT INTO DB_MINERVA.SH_STAGING.YUKON_OPPORTUNITY_CLOSED_ES (
    APP_ID,
    APP_VERSION,
    EVENT_DATETIME,
    COUNTRY,
    TIMEZONE,
    CREATION_DATETIME,
    OWNERSHIP_CHANNEL,
    OWNERSHIP_SUBCHANNEL,
    OWNERSHIP_BUSINESS_UNIT,
    OWNERSHIP,
    OPPORTUNITY_ID,
    UNIQUE_INTENDER_ID,
    OPPORTUNITY_NUMBER,
    LEAD_INTEGRATION_ID,
    PROSPECT_INTEGRATION_ID,
    NUMBER_INTEGRATION_ID,
    ZIP_CODE,
    SEGMENT,
    SEGMENT_SUBTYPE,
    APPOINTMENT,
    STATUS_NAME,
    STATUS_CODE,
    CHANGE_TYPE,
    CHANGE_REASON,
    CHANGE_SUBREASON,
    STATUS,
    AUDIT,
    PROCTIME
)
VALUES (
    'APP_TEST',
    '1.0',
    CURRENT_TIMESTAMP,
    'ES',
    'Europe/Madrid',
    CURRENT_TIMESTAMP,
    'ONLINE',
    'WEB',
    'SALES',
    '{"ownerUserId":"TLVANU","costCenter":"892"}',
    'OPP_ID_001',
    'INTENDER_001',
    'OP_TEST_001',
    'LEAD_001',
    'PROSPECT_001',
    '13906314', 
    '28001',
    'RESIDENTIAL',
    'STANDARD',
    NULL,
    'Closed',
    1,
    'UPDATE',
    'Closed Due to Opp', 
    NULL,
    'CLOSED',
    NULL,
    CURRENT_TIMESTAMP
);

-- 2. DELETE THE RECORD FOR CLEAN DATASET
DELETE FROM DB_MINERVA.SH_STAGING.YUKON_OPPORTUNITY_CLOSED_ES WHERE NUMBER_INTEGRATION_ID='13906314';
--======================================--
--======================================--
