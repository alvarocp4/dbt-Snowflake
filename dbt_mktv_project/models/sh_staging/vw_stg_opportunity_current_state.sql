with created as (
    select
        created.opportunity_id                                                      as id_opportunity,
        created.opportunity_number,
        try_to_number(created.number_integration_id)                                as id_prospect,
        created.unique_intender_id                                                  as id_unique_intender,
        parse_json("INTEGRATIONS"):"altitudeContactProfile":"id"::varchar           as id_easy_code,
        created.status_name,
        created.creation_datetime                                                   as dh_creation,
        created.event_datetime                                                      as dh_event,
        created.ownership_channel,
        created.ownership_subchannel,
        created.segment,
        created.segment_subtype,
        created.zip_code,
        parse_json(property_data):existingAlarm.currentAlarmSystem::string          as current_alarm_system,
        parse_json(created."OWNERSHIP"):"ownerUserId"::varchar                      as assigned_user,
        convert_timezone('UTC','Europe/Madrid', created.lead_generation_datetime)   as dh_prospect_creation,
        upper(created.campaign_standard)                                            as ds_origin,
        upper(created.acd_description)                                              as ds_acd
    from {{ source('minerva','yukon_opportunity_created_es') }} created
    where id_prospect is not null
    qualify row_number() over (
        partition by id_prospect
        order by dh_event desc
    ) = 1
),

booked as (
    select
        booked.opportunity_id                                                   as id_opportunity,
        booked.opportunity_number,
        try_to_number(booked.number_integration_id)                             as id_prospect,
        booked.unique_intender_id                                               as id_unique_intender,
        booked.status_name,
        booked.creation_datetime                                                as dh_creation,
        booked.event_datetime                                                   as dh_event,
        booked.ownership_channel,
        booked.ownership_subchannel,
        booked.segment,
        booked.segment_subtype,
        booked.zip_code,
        booked.booker_user,
        convert_timezone('UTC','Europe/Madrid', booked.visit_appointment_date)  as dh_visit_appointment,
        booked.end_construction_date                                            as dh_end_construction
    from {{ source('minerva','yukon_visit_booked_es') }} booked
    where id_prospect is not null
    qualify row_number() over (
        partition by id_prospect
        order by dh_event desc
    ) = 1
),

assigned as (
    select
        assigned.opportunity_id                                 as id_opportunity,
        assigned.opportunity_number,
        try_to_number(assigned.number_integration_id)           as id_prospect,
        assigned.unique_intender_id                             as id_unique_intender,
        assigned.status_name,
        assigned.creation_datetime                              as dh_creation,
        assigned.event_datetime                                 as dh_event,
        assigned.zip_code,
        assigned.asssigned_user                                 as assigned_user,
        assigned.allocator_user
    from {{ source('minerva','yukon_visit_assigned_es') }} assigned
    where id_prospect is not null
    qualify row_number() over (
        partition by id_prospect
        order by dh_event desc
    ) = 1
),

updated as (
    select distinct
        try_to_number(updated.number_integration_id)            as id_prospect,
        updated.event_datetime                                  as dh_event
    from {{ source('minerva','yukon_opportunity_updated_es') }} updated
    where id_prospect is not null
    qualify row_number() over (
        partition by id_prospect
        order by dh_event desc
    ) = 1
),

installed as (
    select
        installed.opportunity_id                                            as id_opportunity,
        installed.opportunity_number,
        try_to_number(installed.number_integration_id)                      as id_prospect,
        installed.unique_intender_id                                        as id_unique_intender,
        installed.status_name,
        installed.creation_datetime                                         as dh_creation,
        installed.event_datetime                                            as dh_event,
        parse_json(installed."OWNERSHIP"):"ownerUserId"::varchar            as assigned_user,
        installed.installation_code,
        installed.installation_date                                         as dh_installation
    from {{ source('minerva','yukon_opportunity_installed_es') }} installed
    where id_prospect is not null
    qualify row_number() over (
        partition by id_prospect
        order by dh_event desc
    ) = 1
),

closed as (
    select
        closed.opportunity_id                                           as id_opportunity,
        closed.opportunity_number,
        try_to_number(closed.number_integration_id)                     as id_prospect,
        closed.unique_intender_id                                       as id_unique_intender,
        closed.status_name,
        closed.creation_datetime                                        as dh_creation,
        closed.event_datetime                                           as dh_event,
        parse_json(closed."OWNERSHIP"):"ownerUserId"::varchar           as assigned_user,
        closed.change_reason                                            as closing_reason,
        closed.event_datetime                                           as dh_closing
    from {{ source('minerva','yukon_opportunity_closed_es') }} closed
    qualify row_number() over (
        partition by opportunity_number
        order by dh_event desc
    ) = 1
),

offersent as (
    select
        offersent.opportunity_id                                as id_opportunity,
        offersent.opportunity_number,
        try_to_number(offersent.number_integration_id)          as id_prospect,
        offersent.unique_intender_id                            as id_unique_intender,
        offersent.status_name,
        offersent.creation_datetime                             as dh_creation,
        offersent.event_datetime                                as dh_event,
        offersent.zip_code
    from {{ source('minerva','yukon_offer_sent_es') }} offersent
    where id_prospect is not null
    qualify row_number() over (
        partition by id_prospect
        order by dh_event desc
    ) = 1
),

closed_last_event as (
    select
        coalesce(try_to_number(closed.number_integration_id), pcn.id_prospect) as id_prospect,
        max(closed.event_datetime) as dh_closed_event
    from {{ source('minerva','yukon_opportunity_closed_es') }} closed
    left join (
        select distinct
            created.opportunity_number,
            try_to_number(created.number_integration_id) as id_prospect
        from {{ source('minerva','yukon_opportunity_created_es') }} created
        where try_to_number(created.number_integration_id) is not null
    ) pcn on closed.opportunity_number = pcn.opportunity_number
    where id_prospect is not null
    group by 1
),

calculated_fields as (
    select
        created.id_opportunity,
        created.opportunity_number,
        created.id_prospect,
        created.id_unique_intender,
        created.id_easy_code,
        coalesce(
            iff(installed.id_prospect is not null, 'INSTALLED', null),
            iff(offersent.id_prospect is not null, 'OFFERSENT', null),
            iff(closed.id_prospect    is not null, 'CLOSED',    null),
            iff(assigned.id_prospect  is not null, 'ASSIGNED',  null),
            iff(booked.id_prospect    is not null, 'BOOKED',    null),
            iff(updated.id_prospect   is not null, 'UPDATED',   'CREATED')
        )                                                                                                   as prospect_status,
        iff(created.dh_prospect_creation is null, created.dh_creation, created.dh_prospect_creation)        as dh_prospect_creation,
        convert_timezone('UTC','Europe/Madrid',
            greatest_ignore_nulls(
                created.dh_event,
                booked.dh_event,
                assigned.dh_event,
                installed.dh_event,
                offersent.dh_event,
                updated.dh_event,
                closed.dh_event,
                closed_last_event.dh_closed_event
            )
        )                                                                                                   as dh_last_modification,
        created.ownership_channel,
        created.ownership_subchannel,
        coalesce(created.segment,booked.segment)                                                            as segment,
        coalesce(created.segment_subtype,booked.segment_subtype)                                            as segment_subtype,
        coalesce(created.zip_code,booked.zip_code, assigned.zip_code, offersent.zip_code)                   as zip_code,
        created.current_alarm_system,
        booked.booker_user,
        coalesce(created.assigned_user,booked.booker_user, installed.assigned_user, closed.assigned_user)   as assigned_user,
        assigned.allocator_user,
        stg_cost_center.cost_center,
        booked.dh_visit_appointment,
        booked.dh_end_construction,
        installed.installation_code,
        installed.dh_installation,
        created.ds_origin,
        created.ds_acd,
        iff(created.ds_acd in ('OFFLINE SEGUROS', 'ALIANZAS RETAIL'), 1, 0)                                 as grupo_ln,
        coalesce(installed.status_name, offersent.status_name,
                    closed.status_name, assigned.status_name, booked.status_name)                           as status_name,
        coalesce(installed.dh_installation, closed.dh_closing, assigned.dh_event, booked.dh_event)          as dh_status,
        closed.closing_reason,
        closed.dh_closing
    from created
    left join booked                   on created.id_prospect = booked.id_prospect
    left join assigned                 on created.id_prospect = assigned.id_prospect
    left join installed                on created.id_prospect = installed.id_prospect
    left join closed                   on created.opportunity_number = closed.opportunity_number
    left join updated                  on created.id_prospect = updated.id_prospect
    left join offersent                on created.id_prospect = offersent.id_prospect
    left join closed_last_event        on created.id_prospect = closed_last_event.id_prospect
    left join {{ ref('vw_stg_cost_center') }} stg_cost_center
        on created.id_prospect = stg_cost_center.id_prospect
)

select
    id_opportunity,
    opportunity_number,
    id_prospect,
    id_unique_intender,
    id_easy_code,
    prospect_status,
    dh_prospect_creation,
    dh_last_modification,
    ownership_channel,
    ownership_subchannel,
    segment,
    segment_subtype,
    zip_code,
    current_alarm_system,
    booker_user,
    assigned_user,
    allocator_user,
    cost_center,
    dh_visit_appointment,
    dh_end_construction,
    installation_code,
    dh_installation,
    ds_origin,
    ds_acd,
    grupo_ln,
    status_name,
    dh_status,
    closing_reason,
    dh_closing
from calculated_fields
