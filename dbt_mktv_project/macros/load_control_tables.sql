{% macro load_control_tables(event, error_message=none) %}

    {% set materialization = config.get('materialized', '') %}

    {% if execute and materialization in ('table', 'incremental') %}

        {% if event == 'start' %}

            {% set query %}
                MERGE INTO DB_MARKETING.SH_MAIN.LOAD_CONTROL_TABLES AS target
                USING (
                    SELECT
                         '{{ this.name }}'     AS table_name
                        ,'PENDING'             AS status
                        ,NULL                  AS total_rows
                        ,CURRENT_DATE          AS dt_load
                        ,CURRENT_TIMESTAMP     AS dh_started_at
                        ,NULL                  AS dh_finished_at
                        ,NULL                  AS elapsed_seconds
                        ,NULL                  AS error_message
                        ,'{{ target.name }}'   AS target_name
                        ,'{{ invocation_id }}' AS invocation_id
                ) AS source
                ON target.table_name = source.table_name
                WHEN MATCHED THEN UPDATE SET
                     target.status        = source.status
                    ,target.total_rows = source.total_rows
                    ,target.dt_load   = source.dt_load
                    ,target.dh_started_at    = source.dh_started_at
                    ,target.dh_finished_at   = source.dh_finished_at
                    ,target.elapsed_seconds = source.elapsed_seconds
                    ,target.error_message = source.error_message
                    ,target.target_name   = source.target_name
                    ,target.invocation_id = source.invocation_id
                WHEN NOT MATCHED THEN INSERT (
                     table_name
                    ,status
                    ,total_rows
                    ,dt_load
                    ,dh_started_at
                    ,dh_finished_at
                    ,elapsed_seconds
                    ,error_message
                    ,target_name
                    ,invocation_id
                )
                VALUES (
                     source.table_name
                    ,source.status
                    ,source.total_rows
                    ,source.dt_load
                    ,source.dh_started_at
                    ,source.dh_finished_at
                    ,source.elapsed_seconds
                    ,source.error_message
                    ,source.target_name
                    ,source.invocation_id
                );
            {% endset %}

        {% elif event == 'end' %}

            {% set query %}
                UPDATE DB_MARKETING.SH_MAIN.LOAD_CONTROL_TABLES
                SET
                     status          = 'OK'
                    ,dh_finished_at     = CURRENT_TIMESTAMP
                    ,elapsed_seconds = DATEDIFF(
                                         'second',
                                         dh_started_at,
                                         CURRENT_TIMESTAMP
                                       )
                    ,total_rows   = (
                                         SELECT COUNT(*)
                                         FROM {{ this }}
                                       )
                    ,error_message   = NULL
                WHERE
                    table_name = '{{ this.name }}'
                    AND status   = 'PENDING';
            {% endset %}

        {% elif event == 'error' %}

            {% set clean_error = "" %}
            {% if error_message %}
                {% set clean_error = error_message
                    | replace("'", "''")
                    | truncate(4990)
                %}
            {% endif %}

            {% set query %}
                UPDATE DB_MARKETING.SH_MAIN.LOAD_CONTROL_TABLES
                SET
                     status          = 'KO'
                    ,dh_finished_at     = CURRENT_TIMESTAMP
                    ,elapsed_seconds = DATEDIFF(
                                         'second',
                                         dh_started_at,
                                         CURRENT_TIMESTAMP
                                       )
                    ,error_message   = '{{ clean_error }}'
                WHERE
                    table_name = '{{ this.name }}'
                    AND status   = 'PENDING';
            {% endset %}

        {% elif event == 'cleanup' %}

            {% set query %}
                UPDATE DB_MARKETING.SH_MAIN.LOAD_CONTROL_TABLES
                SET
                     status        = 'KO'
                    ,dh_finished_at   = CURRENT_TIMESTAMP
                    ,error_message = 'Execution interrupted unexpectedly'
                WHERE
                    status = 'PENDING';
            {% endset %}

        {% endif %}

        {% do run_query(query) %}

    {% endif %}

{% endmacro %}