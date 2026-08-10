with src_master_acds as (
    select
        src_master_acds.idacd                                 as id_acd,
        ltrim(rtrim(upper(src_master_acds.desacd)))           as abbr_acd,
        collate(trim(src_master_acds.nombre), '')             as ds_acd,
        src_master_acds.fecha_inicio                          as dt_start_acd,
        src_master_acds.fecha_fin                             as dt_end_acd
    from {{ source('odin_staging', 'src_mktv_maestros_acds') }} src_master_acds
    where idacd is not null
      and try_to_number(idacd) is not null
),

foto_crea_criteria as (
    select
        stg_opportunity.id_opportunity,
        stg_opportunity.opportunity_number,
        stg_opportunity.id_prospect,
        stg_opportunity.id_unique_intender,
        stg_opportunity.id_easy_code,
        stg_opportunity.prospect_status,
        stg_opportunity.dh_prospect_creation,
        stg_opportunity.dh_last_modification,
        collate(trim(stg_opportunity.segment_subtype), '')          as segment_subtype,
        collate(trim(stg_opportunity.assigned_user), '')            as assigned_user,
        stg_cost_center.cost_center,
        stg_cost_center.is_tlvanu_flg,
        stg_opportunity.dh_visit_appointment,
        stg_opportunity.dh_end_construction,
        stg_opportunity.closing_reason,
        collate(trim(stg_opportunity.ds_origin), '')                 as ds_origin,
        collate(trim(stg_opportunity.ds_acd), '')                    as ds_acd
    from {{ ref('vw_stg_opportunity_current_state') }} stg_opportunity
    inner join {{ ref('vw_stg_cost_center') }} stg_cost_center
        on stg_cost_center.id_prospect = stg_opportunity.id_prospect
    left join src_master_acds
        on upper(stg_opportunity.ds_acd) = upper(trim(src_master_acds.ds_acd))
       and date(stg_opportunity.dh_prospect_creation) >= date(src_master_acds.dt_start_acd)
       and date(stg_opportunity.dh_prospect_creation) <= date(src_master_acds.dt_end_acd)
    where upper(stg_opportunity.ds_acd) like '%RESTD%'
        and coalesce(
            case 
                when stg_opportunity.prospect_status = 'INSTALLED' then 'Instalada' 
                else stg_opportunity.closing_reason
            end
            , '') not in ('Error / Equivocacion','Duplicado','Anulada por Gerente','Anulada por Telemarketing')
        and coalesce(src_master_acds.abbr_acd,'0') not in
            ('66189','66245','61936','66401','66131','66133','66134','66166','66152',
             '66109','66186','66100','OFFLINE TE','OFFLINE AL','OFFLINE SG','OFFLINE PL',
             'MAPFRE OFF','66060','63926','66330','AliJupiter','48153')
        and upper(src_master_acds.ds_acd) not like '%TELEC%'
        and upper(stg_opportunity.ds_origin) not like '%CAIXA%'
        and upper(stg_opportunity.ds_origin) not like '%MAPFRE%'
        and coalesce(stg_opportunity.ds_origin,'') <> 'VISITA TMK ANDORRA'
        and upper(stg_opportunity.assigned_user) not like '%CAIXA%'
        and upper(stg_opportunity.assigned_user) not like '%RAINBO%'
        and upper(stg_opportunity.assigned_user) <> 'CENRBE'
        and coalesce(stg_cost_center.cost_center,'') not in ('78','92','920','952','98')
        and not (stg_cost_center.cost_center in ('892','895')
                 and not (stg_cost_center.is_tlvanu_flg or upper(coalesce(stg_opportunity.assigned_user,'')) in ('TLVANU','TLVCKO')))
        and ( (upper(stg_opportunity.segment_subtype) like '%COMUNIDAD%'
                 and (case when stg_opportunity.prospect_status='INSTALLED' then 'Instalada' else stg_opportunity.closing_reason end) = 'Instalada')
              or upper(stg_opportunity.segment_subtype) not like '%COMUNIDAD%'
              or stg_opportunity.segment_subtype is null )
),

foto_criteria_filtered as (
    select
        *,
        1 as num_row_id,
        case
            when upper(segment_subtype) like '%COMUNIDAD%'
                 and prospect_status = 'INSTALLED'
                 and to_char(dh_last_modification,'YYYY/MM') > to_char(dh_prospect_creation,'YYYY/MM')
                 then dh_last_modification
            else coalesce(
                    case when year(dh_end_construction) > 1980 then dh_end_construction end,
                    case when year(dh_visit_appointment)      > 1980 then dh_visit_appointment end,
                    dh_prospect_creation)
        end as dh_point_2,
        dh_prospect_creation as dh_point_2_online
    from foto_crea_criteria
),

calculated_fields as (
    select
        id_opportunity,
        opportunity_number,
        id_prospect,
        id_unique_intender,
        id_easy_code,
        case
            when num_row_id <= 1 then 'S'
            when num_row_id >= 2 and prospect_status = 'INSTALLED' then 'S'
            when num_row_id >= 2 and prospect_status = 'INSTALLED'
                    and to_char(dh_last_modification,'YYYY/MM/DD') < to_char(dh_point_2,'YYYY/MM/DD') then 'N'
            when prospect_status = 'INSTALLED'
                    and year(dh_last_modification) = year(dh_point_2)
                    and month(dh_last_modification) = month(dh_point_2)
                    and dh_last_modification <= dh_point_2 then 'N'
            when num_row_id >= 2 and prospect_status <> 'INSTALLED' then 'N'
            else 'R'
        end as is_foto,
        case 
            when num_row_id >= 2
                and to_char(dh_last_modification,'YYYY/MM') > to_char(dh_prospect_creation,'YYYY/MM')
                and prospect_status = 'INSTALLED' then dh_last_modification
            else dh_point_2 
        end as dh_foto,
        case
            when num_row_id <= 1 then 'S'
            when num_row_id >= 2 and prospect_status = 'INSTALLED' then 'S'
            when num_row_id >= 2 and prospect_status <> 'INSTALLED' then 'N'
            else 'R'
        end as is_foto_online,
        case 
            when num_row_id >= 2
                and to_char(dh_last_modification,'YYYY/MM') > to_char(dh_prospect_creation,'YYYY/MM')
                and prospect_status = 'INSTALLED' then dh_last_modification
            else dh_point_2_online 
        end as dh_foto_online,
        cost_center,
        assigned_user,
        prospect_status,
        closing_reason,
        ds_acd,
        ds_origin,
        dh_visit_appointment,
        dh_last_modification,
        dh_end_construction,
        dh_prospect_creation
    from foto_criteria_filtered
)

select
    id_opportunity,
    opportunity_number,
    id_prospect,
    id_unique_intender,
    id_easy_code,
    is_foto,
    dh_foto,
    is_foto_online,
    dh_foto_online,
    cost_center,
    assigned_user,
    prospect_status,
    closing_reason,
    ds_acd,
    ds_origin,
    dh_visit_appointment,
    dh_last_modification,
    dh_end_construction,
    dh_prospect_creation
from calculated_fields