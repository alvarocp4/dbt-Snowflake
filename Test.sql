select * from fact_mkt_capta_visit;
select * from fact_mkt_capta_visit_criteria;
select * from load_control_tables;

create or replace dbt project DB_MARKETING.SH_STAGING.DBT_MKTV_PROJECT
	from snow://workspace/USER$YUKONTESTING.PUBLIC."dbt-Snowflake"/versions/live/dbt_mktv_project/
	DBT_VERSION='1.9.4'
	DEFAULT_TARGET='dev'
	COMMENT='Project for dbt MKT CAPTA';


    SHOW secrets;

    
    SHOW api integrations;