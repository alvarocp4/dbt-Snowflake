with base_created as (
    select
        created.opportunity_number                                      as opportunity_number,
        try_to_number(created.number_integration_id)                    as id_prospect,
        created.creation_datetime                                       as dh_creation,
        created.event_datetime                                          as dh_event,
        parse_json(created."OWNERSHIP"):"ownerUserId"::varchar          as assigned_user,
        parse_json(created."OWNERSHIP"):"costCenter"::varchar           as cost_center,
        created.ownership_subchannel
    from {{ source('minerva','yukon_opportunity_created_es') }} created
    where id_prospect is not null
),
 
created as (
    select
        base_created.opportunity_number,
        base_created.id_prospect,
        base_created.dh_creation,
        base_created.dh_event,
        base_created.assigned_user,
        base_created.cost_center,
        base_created.ownership_subchannel
    from base_created
    qualify row_number() over (
        partition by id_prospect
        order by dh_event desc
    ) = 1
),

assigned as (
    select
        assigned.opportunity_number                             as opportunity_number,
        try_to_number(assigned.number_integration_id)           as id_prospect,
        assigned.creation_datetime                              as dh_creation,
        assigned.event_datetime                                 as dh_event,
        parse_json("OWNERSHIP"):"costCenter"::varchar           as cost_center
    from {{ source('minerva','yukon_visit_assigned_es') }} assigned
    where id_prospect is not null
    qualify row_number() over (
        partition by id_prospect
        order by dh_event desc
    ) = 1
),

updated as (
    select
        updated.opportunity_number,
        try_to_number(updated.number_integration_id)                    as id_prospect,
        updated.event_datetime                                          as dh_event,
        parse_json("OWNERSHIP"):"costCenter"::varchar                   as raw_cost_center,
        last_value(
            case 
                when raw_cost_center not in ('89','892') then raw_cost_center
            end
        ) ignore nulls over (
            partition by id_prospect
            order by dh_event
            rows between unbounded preceding and 1 preceding)   as prev_cost_center
    from {{ source('minerva','yukon_opportunity_updated_es') }} updated
    where id_prospect is not null
    qualify row_number() over (
        partition by id_prospect 
        order by dh_event desc
    ) = 1
),

tlvanu as (
    select distinct
        id_prospect
    from (
        select 
            base_created.id_prospect
        from base_created
        where base_created.id_prospect is not null
            and upper(base_created.assigned_user) = 'TLVANU'

        union all

        select 
            offersent.number_integration_id              as id_prospect
        from {{ source('minerva','yukon_offer_sent_es') }} offersent
        where offersent.number_integration_id is not null
            and upper(parse_json("OWNERSHIP"):"ownerUserId"::varchar) = 'TLVANU'
  )
),

due_to_opp as (
    select
        closed.opportunity_number                               as opportunity_number,
        base_created.id_prospect                                as id_prospect
    from (
        select 
            closed.opportunity_number
        from {{ source('minerva','yukon_opportunity_closed_es') }} closed
        where closed.change_reason like '%Due to Opp%'
            and closed.number_integration_id is not null
    ) closed
    join base_created on closed.opportunity_number = base_created.opportunity_number
),

calculated_fields as (
    select
        created.opportunity_number,
        created.id_prospect,
        created.ownership_subchannel,
        coalesce(created.cost_center, assigned.cost_center, updated.raw_cost_center)            as actual_cost_center,
        updated.raw_cost_center                                                                 as previous_cost_center,
        iff(tlvanu.id_prospect is not null, 1, 0)                                               as is_tlvanu_flg,
        iff(due_to_opp.id_prospect is not null, 1, 0)                                           as is_due_to_opp_flg,
        case
            when actual_cost_center = '89' then coalesce(updated.prev_cost_center, actual_cost_center)
            when actual_cost_center = '892' and (is_tlvanu_flg = 1 or is_due_to_opp_flg = 1) then coalesce(updated.prev_cost_center, actual_cost_center)
            else actual_cost_center
        end                                                                                     as cost_center
    from created
    left join assigned          on assigned.id_prospect = created.id_prospect
    left join updated           on updated.id_prospect = created.id_prospect
    left join tlvanu            on tlvanu.id_prospect = created.id_prospect
    left join due_to_opp        on due_to_opp.id_prospect = created.id_prospect
    order by id_prospect desc
)

select
    opportunity_number,
    id_prospect,
    ownership_subchannel,
    actual_cost_center,
    previous_cost_center,
    is_tlvanu_flg,
    is_due_to_opp_flg,
    cost_center
from calculated_fields