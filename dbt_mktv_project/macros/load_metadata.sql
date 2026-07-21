{% macro load_metadata() %}
    current_timestamp() as int_cre_ts,
    current_timestamp() as int_tec_chg_from_ts,
    current_user() as int_cre_usr
{% endmacro %}