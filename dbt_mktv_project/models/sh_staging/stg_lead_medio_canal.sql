with vs_acds as (
    select
        cast(idacd as integer)                  as id_acd,
        ltrim(rtrim(upper(desacd)))             as desacd,
        nombre                                  as acd_name,
        medio                                   as acd_source,
        medio_cdm                               as acd_source_cdm,
        canal                                   as acd_channel,
        collate(trim(canal_cdm), '')            as acd_channel_cdm, 
        upper(tlf)                              as tlf,
        medio                                   as acd_source_esp,
        clasificacion_submedio,
        fecha_inicio,
        fecha_fin,
        empresa,
        ds_tipologia_campana
    from {{ source('odin_staging', 'src_mktv_maestros_acds') }}
    where idacd is not null
      and try_to_number(idacd) is not null          -- equivalente a PATINDEX numerico
),

vs_origenes as (
    select distinct
        rtrim(ltrim(upper(origen)))             as origenupper, 
        collate(trim(canal_cdm), '')            as acd_channel_cdm, 
        medio_cdm                               as acd_source_cdm,
        medio                                   as acd_source,
        clasificacion_submedio,
        fecha_inicio,
        fecha_fin,
        compania,
        ds_tipologia_campana
    from {{ source('odin_staging', 'src_mktv_maestros_origenes') }}
    where origen is not null
      and canal  is not null
),

-- 1) FACT_ALTITUDE7_INBOUND ----------------------------------------------------
inbound as (
    select
        'I'                                 as io,
        a.bi_campana                        as campana,
        a.id_easycode                       as easycode,
        a.fentradacampana,
        a.idprospecto,
        a.idnumacd,
        case 
            when a.origeninternet = '' then a.desorigen 
            else a.origeninternet 
        end as origen,
        upper(case 
            when b.acd_source = 'SEGUN ORIGEN' or a.idnumacd is null or a.idnumacd = 0 then c.acd_source_cdm 
            else b.acd_source_cdm              
        end) as medio_cdm,
        upper(case
            when b.acd_channel = 'SEGUN ORIGEN' or a.idnumacd is null or a.idnumacd = 0 then c.acd_channel_cdm 
            else b.acd_channel_cdm
        end) as canal_cdm,
        upper(case 
            when b.acd_source_esp = 'SEGUN ORIGEN' or a.idnumacd is null or a.idnumacd = 0 then c.acd_source 
            else b.acd_source_esp
        end) as medio_esp,
        upper(case 
            when b.acd_source = 'SEGUN ORIGEN' or a.idnumacd is null or a.idnumacd = 0 then c.clasificacion_submedio 
            else b.clasificacion_submedio 
        end) as clasificacion_submedio,
        upper(case 
            when b.acd_source = 'SEGUN ORIGEN' or a.idnumacd is null or a.idnumacd = 0 then c.compania
            else b.empresa
        end) as ds_company,
        upper(case 
            when b.acd_source = 'SEGUN ORIGEN' or a.idnumacd is null or a.idnumacd = 0 then c.ds_tipologia_campana 
            else b.ds_tipologia_campana   
        end) as ds_tipologia_campana,
        a.tfncontacto1, 
        a.tfncontacto2, 
        a.tfnpantalla,
        case 
            when coalesce(a.fentradacampana::varchar,'19500101') = '19500101' then a.momento 
            else a.fentradacampana 
        end as f_crit3,
        cast(null as varchar) as ultimo_result
    from {{ source('marketing', 'fact_altitude7_inbound') }} a
    inner join {{ source('odin_staging', 'aux_altitude7_consultas') }} aux
        on a.bi_campana = aux.campana and aux.mktv = 1
    left join vs_acds b         on a.idnumacd = b.id_acd
       and date(a.fentradacampana) >= date(b.fecha_inicio)
       and date(a.fentradacampana) <= date(b.fecha_fin)
    left join vs_origenes c     on (case when a.origeninternet = '' then a.desorigen else a.origeninternet end) = c.origenupper
       and date(a.fentradacampana) >= date(c.fecha_inicio)
       and date(a.fentradacampana) <= date(c.fecha_fin)
),

-- 2) FACT_ALTITUDE7_OUTBOUND ---------------------------------------------------
outbound as (
    select
        'O'                                 as io,
        a.bi_campana                        as campana,
        a.id_easycode                       as easycode,
        a.ct_visita                         as fentradacampana,
        cast(null as number)                as idprospecto,
        b.id_acd                            as idnumacd,
        a.ct_origen                         as origen,
        upper(case 
            when b.acd_source    = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then c.acd_source_cdm
            else b.acd_source_cdm
        end) as medio_cdm,
        upper(case 
            when b.acd_channel    = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then c.acd_channel_cdm
            else b.acd_channel_cdm
        end) as canal_cdm,
        upper(case 
            when b.acd_source_esp = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then c.acd_source
            else b.acd_source_esp
        end) as medio_esp,
        upper(case 
            when b.acd_source    = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then c.clasificacion_submedio 
            else b.clasificacion_submedio 
        end) as clasificacion_submedio,
        upper(case 
            when b.acd_source    = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then c.compania
            else b.empresa
        end) as ds_company,
        upper(case 
            when b.acd_source    = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then c.ds_tipologia_campana
            else b.ds_tipologia_campana
        end) as ds_tipologia_campana,
        a.ct_tfno_contacto1 as tfncontacto1, 
        a.ct_tfno_contacto2 as tfncontacto2, 
        cast(null as varchar) as tfnpantalla,
        case 
            when coalesce(a.horaprimerallamada::varchar,'19500101') = '19500101' then a.moment 
            else a.horaprimerallamada 
        end as f_crit3,
        cast(null as varchar) as ultimo_result
    from {{ source('marketing', 'fact_altitude7_outbound') }} a
    inner join {{ source('odin_staging', 'aux_altitude7_consultas') }} aux
        on a.bi_campana = aux.campana and aux.mktv = 1
    left join vs_acds b         on ltrim(rtrim(upper(a.ct_grupoacd))) = b.acd_name
       and date(a.ct_visita) >= date(b.fecha_inicio)
       and date(a.ct_visita) <= date(b.fecha_fin)
    left join vs_origenes c     on a.ct_origen = c.origenupper
       and date(a.ct_visita) >= date(c.fecha_inicio)
       and date(a.ct_visita) <= date(c.fecha_fin)
),

-- 3) FACT_ALTITUDE8_ReportingTotalCTs ------------------------------------------
a8 as (
    select
        '8'                                 as io,
        a.scampanacreacionprospecto         as campana,
        a.perfildirectorio                  as easycode,
        a.fentradacampana,
        a.idprospecto,
        a.idnumacd,
        case 
            when a.origeninternet = '' then a.desorigen 
            else a.origeninternet 
        end as origen,
        upper(case 
            when b2.acd_source_cdm is not null then b2.acd_source_cdm              
            when b.acd_source = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then c.acd_source_cdm              
            else b.acd_source_cdm              
        end) as medio_cdm,
        upper(case 
            when b2.acd_channel_cdm is not null then b2.acd_channel_cdm              
            when b.acd_channel = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then c.acd_channel_cdm              
            else b.acd_channel_cdm              
        end) as canal_cdm,
        upper(case 
            when b2.acd_source_esp is not null then b2.acd_source_esp              
            when b.acd_source_esp = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then c.acd_source              
            else b.acd_source_esp              
        end) as medio_esp,
        upper(case 
            when b2.clasificacion_submedio is not null then b2.clasificacion_submedio 
            when b.acd_source = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then c.clasificacion_submedio 
            else b.clasificacion_submedio 
        end) as clasificacion_submedio,
        upper(case 
            when b2.empresa is not null then b2.empresa                
            when b.acd_source = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then c.compania              
            else b.empresa
        end) as ds_company,
        upper(case 
            when b2.ds_tipologia_campana   is not null then b2.ds_tipologia_campana   
            when b.acd_source    = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then c.ds_tipologia_campana  
            else b.ds_tipologia_campana   
        end) as ds_tipologia_campana,
        a.tfncontacto1, 
        a.tfncontacto2, 
        a.tfnpantalla,
        a.fentradacampana as f_crit3,
        a.ultimoresult    as ultimo_result
    from {{ source('marketing', 'fact_altitude8_reportingtotalcts') }} a
    inner join {{ source('odin_staging', 'src_mktv_campains') }} smc
        on a.campania = smc.altitude
       and smc.linea_de_negocio = 'Contact Center'
       and smc.altitude not in ('SP_AsignMkt')
       and date(a.fentradacampana) >= date(smc.fecha_inicio)
       and date(a.fentradacampana) <= date(smc.fecha_fin)
    left join vs_acds b
        on a.idnumacd = b.id_acd
       and date(a.fentradacampana) >= date(b.fecha_inicio)
       and date(a.fentradacampana) <= date(b.fecha_fin)
    left join vs_acds b2
        on b2.tlf is not null and b2.tlf <> 'X' and substr(b2.desacd,1,1) <> '6'
       and a.tr_num_900 = b2.tlf
       and a.campania = 'SP_RcvAbandoned'
       and date(a.fentradacampana) >= date(b2.fecha_inicio)
       and date(a.fentradacampana) <= date(b2.fecha_fin)
    left join vs_origenes c
        on rtrim(ltrim(upper(a.desorigen))) = c.origenupper
       and date(a.fentradacampana) >= date(c.fecha_inicio)
       and date(a.fentradacampana) <= date(c.fecha_fin)
),

-- 4) SRC_MKTV_JOTFORMS ---------------------------------------------------------
jotforms as (
    select
        'J'                                 as io,
        a.descrct                           as campana,
        a.perfildirectorio / 10000000000000 as easycode,
        a.fentradacampana,
        cast(null as number)                as idprospecto,
        cast(null as number)                as idnumacd,
        rtrim(ltrim(upper(a.origeninternet))) as origen,
        upper(c.acd_source_cdm)              as medio_cdm,
        upper(c.acd_channel_cdm)              as canal_cdm,
        upper(c.acd_source)              as medio_esp,
        upper(c.clasificacion_submedio) as clasificacion_submedio,
        upper(c.compania)              as ds_company,
        upper(c.ds_tipologia_campana)  as ds_tipologia_campana,
        cast(null as varchar) as tfncontacto1, cast(null as varchar) as tfncontacto2, 
        a.tfnpantalla_e as tfnpantalla,
        a.fentradacampana as f_crit3,
        cast(null as varchar) as ultimo_result
    from {{ source('odin_staging', 'src_mktv_jotforms') }} a
    left join vs_origenes c
        on rtrim(ltrim(upper(a.origeninternet))) = c.origenupper
       and date(a.fentradacampana) >= date(c.fecha_inicio)
       and date(a.fentradacampana) <= date(c.fecha_fin)
),

leads_altitude as (
    select * from inbound
    union all
    select * from outbound
    union all
    select * from a8
    union all
    select * from jotforms
),

-- ##LEADS_MC: leads validos ----------------------------------------------------
leads_mc as (
    select distinct
        io, 
        campana, 
        easycode, 
        fentradacampana, 
        idprospecto, 
        idnumacd, 
        origen,
        canal_cdm, 
        medio_cdm, 
        medio_esp, 
        clasificacion_submedio, 
        ds_company, 
        ds_tipologia_campana
    from leads_altitude
    where (idnumacd is not null or (origen is not null and origen <> '' and origen <> ' '))
      and canal_cdm not like '%RELL%'
      and coalesce(idnumacd, 0) not in (26,117,504,532,600)
      and coalesce(try_to_number(easycode::varchar), 0) <> 0
      and rtrim(ltrim(coalesce(medio_cdm, ''))) <> ''
      and rtrim(ltrim(coalesce(canal_cdm, ''))) <> ''
),

-- ##Visitas: lado prospecto (de stg_opportunity + stg_opportunity_attrs) --------
-- ACD del prospecto (acd_description) -> NOMBRE del maestro (sin IDs)
visitas as (
    select distinct
        o.opportunity_number,
        o.id_prospect,
        o.id_easy_code,
        o.dh_prospect_creation,
        acd.desacd     as abrvnumacd,
        acd.acd_channel_cdm  as canal_visita
    from {{ ref('stg_opportunity_current_state') }} o
    left join vs_acds acd
        on upper(trim(o.acd_description)) = upper(trim(acd.acd_name))
       and date(o.dh_prospect_creation) >= date(acd.fecha_inicio)
       and date(o.dh_prospect_creation) <= date(acd.fecha_fin)
    where year(o.dh_prospect_creation) >= 2017
      and canal_visita not like '%RELL%'
),

-- CRITERIO 1: easycode + ventana de fecha (fentradacampana + 100 dias) ----------
crit1 as (
    select
        d.opportunity_number,
        d.id_prospect,
        1                                   as criterio_prio,
        'CRITERIO 1'                        as criterio,
        a.io, 
        a.campana, 
        a.easycode, 
        a.fentradacampana, 
        a.idnumacd, 
        a.origen,
        a.canal_cdm, 
        a.medio_cdm, 
        a.medio_esp, 
        a.clasificacion_submedio, 
        a.ds_company, 
        a.ds_tipologia_campana,
        d.dh_prospect_creation
    from visitas d
    inner join leads_mc a
        on coalesce(try_to_number(a.easycode::varchar),0) = coalesce(try_to_number(d.id_easy_code::varchar),0)
       and dateadd('day', 100, a.fentradacampana) >= d.dh_prospect_creation
    where coalesce(d.abrvnumacd, '0') not in ('-900','66188','66419','60051','66988')
      and a.easycode is not null
      and a.campana <> 'SP_RunScript'
      and coalesce(try_to_number(a.easycode::varchar),0) <> 0
      and coalesce(a.idnumacd, -1) not in (26,117,504,532,600)
      and a.canal_cdm not like '%RELL%'
      and rtrim(ltrim(coalesce(a.canal_cdm,''))) <> ''
      and rtrim(ltrim(coalesce(a.medio_cdm,''))) <> ''
      and rtrim(ltrim(coalesce(a.medio_esp,''))) <> ''
      and rtrim(ltrim(coalesce(a.ds_company,''))) <> ''
      and rtrim(ltrim(coalesce(a.ds_tipologia_campana,''))) <> ''
),

-- CRITERIO 2: por id_prospecto -------------------------------------------------
crit2 as (
    select
        d.opportunity_number,
        d.id_prospect,
        2                                   as criterio_prio,
        'CRITERIO 2'                        as criterio,
        a.io, 
        a.campana, 
        a.easycode, 
        a.fentradacampana, 
        a.idnumacd, 
        a.origen,
        a.canal_cdm, 
        a.medio_cdm, 
        a.medio_esp, 
        a.clasificacion_submedio, 
        a.ds_company, 
        a.ds_tipologia_campana,
        d.dh_prospect_creation
    from visitas d
    inner join leads_mc a
        on a.idprospecto = d.id_prospect
    where a.easycode is not null
      and a.campana <> 'SP_RunScript'
      and not (coalesce(a.idnumacd, -1) in (21,26,132,10)
               and (a.origen is null or a.origen = '' or a.origen = ' '))
      and rtrim(ltrim(coalesce(a.canal_cdm,''))) <> ''
      and rtrim(ltrim(coalesce(a.medio_cdm,''))) <> ''
      and rtrim(ltrim(coalesce(a.medio_esp,''))) <> ''
      and rtrim(ltrim(coalesce(a.ds_company,''))) <> ''
      and rtrim(ltrim(coalesce(a.ds_tipologia_campana,''))) <> ''
),

/* -------------------------------------------------------------------------
   CRITERIO 3 / 4 / 5 (por telefono) -- PENDIENTE
   Bloqueado: el prospecto Yukon no expone telefono (NUM_TELF_*).
   Cuando esten disponibles, se anaden como crit3/crit4/crit5 con su
   criterio_prio = 3/4/5 y se incluyen en el union all de 'candidatos'.
   Logica legacy: match por tfnpantalla / tfncontacto1 / tfncontacto2
   contra leads (tfn*) con ventana de fecha F_CRIT3.
   ------------------------------------------------------------------------- */

candidatos as (
    select * from crit1
    union all
    select * from crit2
    -- union all select * from crit3
    -- union all select * from crit4
    -- union all select * from crit5
),

-- pick unico por prospecto: menor prioridad de criterio, luego mas antiguo -----
picked as (
    select *
    from candidatos
    qualify row_number() over (
        partition by id_prospect
        order by criterio_prio, fentradacampana
    ) = 1
)

select
    opportunity_number,
    try_to_number(id_prospect) as id_prospect,
    medio_cdm              as medio_lead,
    canal_cdm              as canal_lead,
    medio_esp,
    clasificacion_submedio,
    ds_company,
    ds_tipologia_campana,
    dh_prospect_creation,
    origen,
    campana,
    io,
    fentradacampana,
    criterio
from picked
order by id_prospect