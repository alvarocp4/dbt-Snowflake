-- =============================================================================
-- fact_mktv_visitas
-- foto diaria, 1 fila/prospecto.
-- Ensamblaje minimo: passthrough del spine (ya trae identidad + salida de los 5 modelos).
-- Merge por id_prospecto; watermark = ssfultmodifica (MAX event_datetime del estado).
-- =============================================================================

with spine as (
    select * from {{ ref('stg_prospect_consolidated') }}
)

select *
from spine
{% if is_incremental() %}
where dh_last_modification > (
    select coalesce(max(dh_last_modification), '1900-01-01'::timestamp_ntz)
    from {{ this }}
)
{% endif %}