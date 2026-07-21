with src_maestros_acds as (
    select
        src_maestros_acds.idacd                                 as id_acd,
        ltrim(rtrim(upper(src_maestros_acds.desacd)))           as vl_acd,
        collate(trim(src_maestros_acds.nombre), '')             as ds_acd,
        src_maestros_acds.fecha_inicio                          as dt_start_date,
        src_maestros_acds.fecha_fin                             as dt_end_date,
    from {{ source('odin_staging', 'src_mktv_maestros_acds') }} src_maestros_acds
    where idacd is not null
      and try_to_number(idacd) is not null
),

base as (
    select
        o.opportunity_number,
        o.id_prospect,
        o.dh_prospect_creation,
        o.dh_visit_appointment              as fec_visita,
        o.dh_end_construction              as fec_final_obra,
        o.dh_last_modification                      as fec_ult_mod_prospecto,
        -- fec_est_prospecto (SSFESTADO): fecha del estado actual. FLAG mapeo
        coalesce(o.dh_installation, o.dh_closing) as fec_est_prospecto,
        -- DESCODTERM (codigo terminacion) derivado del status. FLAG: confirmar valores anulacion
        case when o.prospect_status = 'INSTALLED' then 'Instalada'
             else o.closing_reason end        as descodterm,
        o.prospect_status,
        collate(trim(o.acd_description), '')        as acd_description,-- ABRVRECURSO (RE%) + join ACD
        collate(trim(o.segment_subtype), '') as segment_subtype, -- DESTIPOINST (COMUNIDAD)
        collate(trim(o.origen), '') as origen, -- DESORIGEN
        collate(trim(o.assigned_user), '') as assigned_user, -- ASIGNADOA (agente visita)
        cc.cost_center                         as cc_visita,
        cc.is_tlvanu_flg
    from {{ ref('stg_opportunity_current_state') }} o
    inner join {{ ref('stg_cost_center') }} cc
        on cc.id_prospect = o.id_prospect
    left join src_maestros_acds acd
        on upper(acd_description) = upper(trim(acd.ds_acd))
       and date(o.dh_prospect_creation) >= date(acd.dt_start_date)
       and date(o.dh_prospect_creation) <= date(acd.dt_end_date)
    where
        -- PUNTO 1: recurso empresa. Legacy ABRVRECURSO LIKE 'RE%'. FLAG: confirmar patron
        upper(acd_description) like 'RE%'
        -- PUNTO 3: excluir terminaciones no validas
        and coalesce(
                case when o.prospect_status = 'INSTALLED' then 'Instalada' else o.closing_reason end
            , '') not in ('Error / Equivocacion','Duplicado','Anulada por Gerente','Anulada por Telemarketing')
        -- PUNTO 4: ACD abreviatura excluida + descripcion TELEC
        and coalesce(acd.vl_acd,'0') not in
            ('66189','66245','61936','66401','66131','66133','66134','66166','66152',
             '66109','66186','66100','OFFLINE TE','OFFLINE AL','OFFLINE SG','OFFLINE PL',
             'MAPFRE OFF','66060','63926','66330','AliJupiter','48153')
        and upper(acd.ds_acd) not like '%TELEC%'   -- FLAG: DESNUMACD = descripcion ACD
        -- Origen
        and upper(origen) not like '%CAIXA%'
        and upper(origen) not like '%MAPFRE%'
        and coalesce(o.origen,'') <> 'VISITA TMK ANDORRA'
        -- Asignado
        and upper(assigned_user) not like '%CAIXA%'
        and upper(assigned_user) not like '%RAINBO%'
        and upper(assigned_user) <> 'CENRBE'
        -- PUNTO 6: centros de coste excluidos
        and coalesce(cc.cost_center,'') not in ('78','92','920','952','98')
        -- 892/895: solo se quedan TLVANU/TLVCKO. FLAG: is_tlvanu + TLVCKO
        and not (cc.cost_center in ('892','895')
                 and not (cc.is_tlvanu_flg or upper(coalesce(o.assigned_user,'')) in ('TLVANU','TLVCKO')))
        -- PUNTO 7: comunidades solo si Instalada
        and ( (upper(segment_subtype) like '%COMUNIDAD%'
                 and (case when o.prospect_status='INSTALLED' then 'Instalada' else o.closing_reason end) = 'Instalada')
              or upper(segment_subtype) not like '%COMUNIDAD%'
              or o.segment_subtype is null )
),

calc as (
    select
        *,
        1 as num_row_id,   -- dedup bloqueado (sin telefono). TODO: rango real de stg_duplicados

        -- FECHA_PUNTO_2 (marketing): finobra -> visita -> asig -> creacion; override comunidad+instalada
        case
            when upper(segment_subtype) like '%COMUNIDAD%'
                 and descodterm = 'Instalada'
                 and to_char(fec_est_prospecto,'YYYY/MM') > to_char(dh_prospect_creation,'YYYY/MM')
                 then fec_est_prospecto
            else coalesce(
                    case when year(fec_final_obra) > 1980 then fec_final_obra end,
                    case when year(fec_visita)      > 1980 then fec_visita end,
                    dh_prospect_creation)
        end as fecha_punto_2,

        -- FECHA_PUNTO_2_ONLINE: legacy usa SSFVISITA si L37602 (Lourdes) else SSFCREACION.
        -- FLAG: caso historico L37602 omitido -> usamos fec_creacion_prospecto.
        dh_prospect_creation as fecha_punto_2_online
    from base
),

final as (
    select
        opportunity_number,
        id_prospect,

        -- ENTRA_FOTO (marketing). num_row_id=1 -> siempre 'S' para elegibles.
        case
            -- when tfnocontacto1 like '%X%' and segment_subtype not like '%COMUNIDAD%' then 'S'  -- Robinson (telefono, TODO)
            when num_row_id <= 1 then 'S'
            when num_row_id >= 2 and descodterm = 'Instalada' then 'S'
            when num_row_id >= 2 and descodterm = 'Instalada'
                 and to_char(fec_est_prospecto,'YYYY/MM/DD') < to_char(fecha_punto_2,'YYYY/MM/DD') then 'N'
            when prospect_status = 'INSTALLED'
                 and year(fec_est_prospecto) = year(fecha_punto_2)
                 and month(fec_est_prospecto) = month(fecha_punto_2)
                 and fec_est_prospecto <= fecha_punto_2 then 'N'
            when num_row_id >= 2 and descodterm <> 'Instalada' then 'N'
            else 'R'
        end as entra_foto,

        -- FECHA_FOTO (marketing). num_row_id=1 -> fecha_punto_2
        case when num_row_id >= 2
                  and to_char(fec_est_prospecto,'YYYY/MM') > to_char(dh_prospect_creation,'YYYY/MM')
                  and descodterm = 'Instalada' then fec_est_prospecto
             else fecha_punto_2 end as fecha_foto,

        -- ENTRA_FOTO_ONLINE (misma logica de entrada)
        case
            when num_row_id <= 1 then 'S'
            when num_row_id >= 2 and descodterm = 'Instalada' then 'S'
            when num_row_id >= 2 and descodterm <> 'Instalada' then 'N'
            else 'R'
        end as entra_foto_online,

        case when num_row_id >= 2
                  and to_char(fec_est_prospecto,'YYYY/MM') > to_char(dh_prospect_creation,'YYYY/MM')
                  and descodterm = 'Instalada' then fec_est_prospecto
             else fecha_punto_2_online end as fecha_foto_online,

        -- campos historicos que arrastra la fact
        cc_visita              as num_his_cc_visita,
        assigned_user         as nom_his_agent_crea_visita,
        descodterm             as est_hist_prospecto_cierre,
        acd_description        as abrvrecurso_his,
        origen                 as desorigen,
        fec_visita,
        fec_est_prospecto,
        fec_ult_mod_prospecto,
        fec_final_obra,
        dh_prospect_creation as fec_crea_prospecto_r1
    from calc
)

select * from final