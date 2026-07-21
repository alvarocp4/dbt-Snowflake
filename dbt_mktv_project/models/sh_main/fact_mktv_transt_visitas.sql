-- =============================================================================
-- fact_mktv_transt_visitas
-- misma base que visitas + freeze de cierre.
-- estado_prospecto_his = estado congelado en el cierre (viene de stg_foto: est_hist_prospecto_cierre).
-- fecha_contabilizacion: TODO -> depende del calendario/maestro de cierre (aun no disponible).
-- =============================================================================

with spine as (
    select * from {{ ref('stg_prospect_consolidated') }}
)

select
    s.*,
    -- estado congelado del prospecto en el momento de cierre
    s.est_hist_prospecto_cierre  as estado_prospecto_his,
    -- fecha de contabilizacion comercial: pendiente del calendario de cierre
    cast(null as date)           as fecha_contabilizacion  -- TODO: regla/maestro de cierre
from spine s
{% if is_incremental() %}
where s.dh_last_modification > (
    select coalesce(max(dh_last_modification), '1900-01-01'::timestamp_ntz)
    from {{ this }}
)

{% endif %}