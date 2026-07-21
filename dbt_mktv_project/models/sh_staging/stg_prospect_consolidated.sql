-- =============================================================================
-- stg_prospect_consolidated
-- spine minimo.
-- Une los 5 modelos por id_prospecto. Base = stg_opportunity_current_state (1 fila/prospecto).
-- Sin derivados (is_express, geo, territorial, is_client...) -> se anaden en una pasada posterior.
-- =============================================================================

with base as (
    select * from {{ ref('stg_opportunity_current_state') }}
),

attrs_cc as (
    select
        id_prospect,
        actual_cost_center,
        previous_cost_center,
        is_tlvanu_flg,
        is_due_to_opp_flg
        -- cost_center ya viene en base (lo toma de stg_cost_center)
    from {{ ref('stg_cost_center') }}
),

medio_canal as (
    select
        id_prospect,
        medio_lead,
        canal_lead,
        medio_esp,
        clasificacion_submedio,
        ds_company            as ds_company_lead,
        ds_tipologia_campana  as ds_tipologia_campana_lead,
        origen                as origen_lead,
        campana               as campana_lead,
        criterio              as criterio_medio_canal
    from {{ ref('stg_lead_medio_canal') }}
),

campana_crea as (
    select
        id_prospect,
        creation_campaing
    from {{ ref('stg_campana_crea') }}
),

foto as (
    select
        id_prospect,
        entra_foto,
        fecha_foto,
        entra_foto_online,
        fecha_foto_online,
        est_hist_prospecto_cierre,
        abrvrecurso_his
    from {{ ref('stg_foto_crea_criteria') }}
)

select
    b.*,
    b.assigned_user,
    ac.actual_cost_center,
    ac.previous_cost_center,
    ac.is_tlvanu_flg,
    ac.is_due_to_opp_flg,
    mc.medio_lead,
    mc.canal_lead,
    mc.medio_esp,
    mc.clasificacion_submedio,
    mc.ds_company_lead,
    mc.ds_tipologia_campana_lead,
    mc.origen_lead,
    mc.campana_lead,
    mc.criterio_medio_canal,
    cr.creation_campaing,
    f.entra_foto,
    f.fecha_foto,
    f.entra_foto_online,
    f.fecha_foto_online,
    f.est_hist_prospecto_cierre,
    f.abrvrecurso_his
from base b
left join attrs_cc     ac on ac.id_prospect = b.id_prospect
left join medio_canal  mc on mc.id_prospect = b.id_prospect
left join campana_crea cr on cr.id_prospect = b.id_prospect
left join foto         f  on f.id_prospect  = b.id_prospect