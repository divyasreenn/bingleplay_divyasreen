-- Minor Project 4 : Binge Play --

-- Q1: finding active MRR as of june 30
-- have to check for null end_date too otherwise active open subs get missed
select 
    sub.plan as tier,
    count(sub.subscription_id) as total_active,
    sum(sub.monthly_price_inr) as mrr_inr
from subscriptions sub
where sub.status = 'active' 
  and (sub.end_date is null or sub.end_date > '2024-06-30')
group by sub.plan;

-- Q2: monthly signups from jan to june 2024 to see which month peaked
select 
    date_format(u.signup_date, '%Y-%m') as yr_month,
    count(*) as new_users
from users u
where u.signup_date >= '2024-01-01' and u.signup_date <= '2024-06-30'
group by yr_month
order by yr_month;

-- Q3: stats by device type
-- filtering out guest/null users first
select
 ws.device_type as platform,
    count(ws.session_id) as sessions_cnt,
    sum(ws.watch_minutes) as mins_watched,
    round(avg(ws.watch_minutes), 2) as avg_mins,
    round((sum(ws.completed) / count(ws.session_id)) * 100, 2) as comp_rate
from watch_sessions ws
where ws.user_id is not null
group by ws.device_type
order by mins_watched desc;

-- Q4: distribution of star ratings and share of 4 & 5 stars
select 
    r.stars as rating_val,
    count(r.rating_id) as cnt,
    round(count(r.rating_id) * 100.0 / (select count(*) from ratings), 2) as pct_share
from ratings r
group by r.stars
order by r.stars desc;

-- quick check just for 4 and 5 star combined % too
select 
    round(sum(case when stars in (4, 5) then 1 else 0 end) * 100.0 / count(*), 2) as top_ratings_pct
from ratings;

-- Q5: comparing bingeplay originals vs acquired shows
select 
    if(s.is_original = 1, 'Original', 'Acquired') as category_flag,
    count(*) as total_titles,
    round(avg(s.imdb_rating), 2) as mean_imdb,
    round(avg(s.release_year), 1) as mean_yr
from shows s
group by s.is_original;

-- Q6: checking for binge sessions in q2 (same user, same show >= 5 times a day)
-- gotta group by show_id too or else it counts different shows mixed together
select 
    ws.user_id,
    ws.show_id,
    ws.session_date,
    count(*) as watches_on_day
from watch_sessions ws
where ws.session_date between '2024-04-01' and '2024-06-30'
  and ws.user_id is not null
group by ws.user_id, ws.show_id, ws.session_date
having count(*) >= 5
order by watches_on_day desc;

-- Q7: q1 signups who never watched anything
-- using not exists instead of not in to avoid silent null trap bugs
select 
    u.user_id,
    u.name,
    u.signup_date
from users u
where u.signup_date between '2024-01-01' and '2024-03-31'
  and not exists (
      select 1 
      from watch_sessions ws 
      where ws.user_id = u.user_id
  );
  
  -- Q8: premium/family users whose history is only basic tier shows
-- checking with not exists so we rule out anyone who ever watched a non-basic show
select distinct
    u.user_id,
    u.name,
    sub.plan as current_tier
from users u
join subscriptions sub on u.user_id = sub.user_id
where sub.status = 'active'
  and sub.plan in ('Premium', 'Family')
  and not exists (
      select 1 
      from watch_sessions ws
      join shows s on ws.show_id = s.show_id
      where ws.user_id = u.user_id
        and s.min_plan != 'Basic'
  );
  
-- Q9: jan basic signups who upgraded and stayed active through june 30
-- tracking subscription changes and calculating days elapsed
-- as this was a complicated one i did use ai assist --
select 
    u.user_id,
    u.name,
    sub_basic.start_date as basic_signup_date,
    sub_upgrade.start_date as upgrade_date,
    datediff(sub_upgrade.start_date, sub_basic.start_date) as days_to_upgrade
from users u
join subscriptions sub_basic on u.user_id = sub_basic.user_id
join subscriptions sub_upgrade on u.user_id = sub_upgrade.user_id
where sub_basic.plan = 'Basic'
  and sub_basic.start_date between '2024-01-01' and '2024-01-31'
  and sub_upgrade.plan in ('Premium', 'Family')
  and sub_upgrade.start_date > sub_basic.start_date
  and exists (
      select 1 
      from subscriptions sub_check 
      where sub_check.user_id = u.user_id 
        and sub_check.status = 'active'
        and (sub_check.end_date is null or sub_check.end_date > '2024-06-30')
  );
  
-- Q10: cliffhanger comebacks (watched incomplete, returned 1-7 days later)
-- self joining watch sessions to compare initial session with the follow-up
select distinct
    ws1.user_id,
    ws1.show_id,
    ws1.session_date as initial_session_date,
    ws2.session_date as comeback_session_date,
    datediff(ws2.session_date, ws1.session_date) as days_gap
from watch_sessions ws1
join watch_sessions ws2 on ws1.user_id = ws2.user_id
                       and ws1.show_id = ws2.show_id
where ws1.completed = 0
  and ws2.session_date > ws1.session_date
  and datediff(ws2.session_date, ws1.session_date) between 1 and 7
order by ws1.user_id, days_gap;

-- Q11: consecutive week streaks (4+ weeks)
-- using row_number minus week number to find islands, classic gaps & islands trick
with weekly_activity as (
    select distinct 
        user_id,
        yearweek(session_date, 3) as iso_week
    from watch_sessions
    where user_id is not null
),
numbered_weeks as (
    select 
        user_id,
        iso_week,
        row_number() over (partition by user_id order by iso_week) as rk
    from weekly_activity
),
island_groups as (
    select 
        user_id,
        iso_week,
        date_sub(str_to_date(concat(iso_week, ' ' , '1'), '%X%V %w'), interval rk week) as grp
    from numbered_weeks
)
select distinct 
    user_id
from island_groups
group by user_id, grp
having count(*) >= 4;


-- Q12: churn signal (june watch mins dropped 50%+ compared to may)
-- calculated monthly totals in cte first so we can use math safely in where clause
with monthly_watch as (
    select 
        user_id,
        date_format(session_date, '%Y-%m') as mth,
        sum(watch_minutes) as total_mins
    from watch_sessions
    where user_id is not null
      and session_date between '2024-05-01' and '2024-06-30'
    group by user_id, mth
),
comparison as (
    select 
        user_id,
        sum(case when mth = '2024-05' then total_mins else 0 end) as may_mins,
        sum(case when mth = '2024-06' then total_mins else 0 end) as june_mins
    from monthly_watch
    group by user_id
)
select 
    user_id,
    may_mins,
    june_mins,
    round((may_mins - june_mins) * 100.0 / may_mins, 2) as drop_pct
from comparison
where may_mins > 0
  and june_mins <= (may_mins * 0.5)
order by drop_pct desc;