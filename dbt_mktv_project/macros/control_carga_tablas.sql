{% macro control_carga_tablas(event, error_message=none) %}

    {% set materialization = config.get('materialized', '') %}

    {% if execute and materialization in ('table', 'incremental') %}

        {% if event == 'start' %}

            {% set query %}
                MERGE INTO DB_MARKETING.SH_MAIN.CONTROL_CARGA_TABLAS AS target
                USING (
                    SELECT
                         '{{ this.name }}'     AS tabla_nombre
                        ,'PENDING'             AS status
                        ,NULL                  AS filas_totales
                        ,CURRENT_DATE          AS fecha_carga
                        ,CURRENT_TIMESTAMP     AS started_at
                        ,NULL                  AS finished_at
                        ,NULL                  AS elapsed_seconds
                        ,NULL                  AS error_message
                        ,'{{ target.name }}'   AS target_name
                        ,'{{ invocation_id }}' AS invocation_id
                ) AS source
                ON target.tabla_nombre = source.tabla_nombre
                WHEN MATCHED THEN UPDATE SET
                     target.status        = source.status
                    ,target.filas_totales = source.filas_totales
                    ,target.fecha_carga   = source.fecha_carga
                    ,target.started_at    = source.started_at
                    ,target.finished_at   = source.finished_at
                    ,target.elapsed_seconds = source.elapsed_seconds
                    ,target.error_message = source.error_message
                    ,target.target_name   = source.target_name
                    ,target.invocation_id = source.invocation_id
                WHEN NOT MATCHED THEN INSERT (
                     tabla_nombre
                    ,status
                    ,filas_totales
                    ,fecha_carga
                    ,started_at
                    ,finished_at
                    ,elapsed_seconds
                    ,error_message
                    ,target_name
                    ,invocation_id
                )
                VALUES (
                     source.tabla_nombre
                    ,source.status
                    ,source.filas_totales
                    ,source.fecha_carga
                    ,source.started_at
                    ,source.finished_at
                    ,source.elapsed_seconds
                    ,source.error_message
                    ,source.target_name
                    ,source.invocation_id
                );
            {% endset %}

        {% elif event == 'end' %}

            {% set query %}
                UPDATE DB_MARKETING.SH_MAIN.CONTROL_CARGA_TABLAS
                SET
                     status          = 'OK'
                    ,finished_at     = CURRENT_TIMESTAMP
                    ,elapsed_seconds = DATEDIFF(
                                         'second',
                                         started_at,
                                         CURRENT_TIMESTAMP
                                       )
                    ,filas_totales   = (
                                         SELECT COUNT(*)
                                         FROM {{ this }}
                                       )
                    ,error_message   = NULL
                WHERE
                    tabla_nombre = '{{ this.name }}'
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
                UPDATE DB_MARKETING.SH_MAIN.CONTROL_CARGA_TABLAS
                SET
                     status          = 'KO'
                    ,finished_at     = CURRENT_TIMESTAMP
                    ,elapsed_seconds = DATEDIFF(
                                         'second',
                                         started_at,
                                         CURRENT_TIMESTAMP
                                       )
                    ,error_message   = '{{ clean_error }}'
                WHERE
                    tabla_nombre = '{{ this.name }}'
                    AND status   = 'PENDING';
            {% endset %}

        {% elif event == 'cleanup' %}

            {% set query %}
                UPDATE DB_MARKETING.SH_MAIN.CONTROL_CARGA_TABLAS
                SET
                     status        = 'KO'
                    ,finished_at   = CURRENT_TIMESTAMP
                    ,error_message = 'Ejecucion interrumpida inesperadamente'
                WHERE
                    status = 'PENDING';
            {% endset %}

        {% endif %}

        {% do run_query(query) %}

    {% endif %}

{% endmacro %}