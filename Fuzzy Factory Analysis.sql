
-- FUZZY FACTORY ANALYSIS 
set search_path to Fuzzy_Factory, public;

-- I. EXECUTIVE PERFORMANCE 

-- View for computing Total Refund 
create or replace view total_refund_usd as 
	select
		order_id,
		sum(coalesce(refund_amount_usd, 0))::int as total_refund_amount
	from order_item_refunds
	group by order_id; 

-- View for cleaning order date from created_at (orders table)
create or replace view report_date_orders as
	select
		order_id,
		(created_at::text::timestamp)::date as report_date,
		website_session_id,
		user_id
	from orders;

-- View for computing metrics -- No identifier to join with other queries
create or replace view annual_metrics as 
	select
		date_part('year', date.report_date)::int as report_year,
		sum(orders.price_usd) as revenue,
		sum(coalesce(refund.total_refund_amount, 0)) as refund,
		sum(orders.price_usd) - sum(coalesce(refund.total_refund_amount, 0)) as net_revenue
	from orders 
		left join total_refund_usd refund
			on orders.order_id = refund.order_id 
		left join report_date date 
			on orders.order_id = date.order_id
	group by 1;
 
-- Computing for Total Revenue, Net Revenue, Refund %, Profit,YoY Growth per year
select
	report_year,
	to_char(revenue, 'FM999,999,999,999') as total_revenue,
	to_char(refund, 'FM999,999,999,999') as total_refund,
	to_char(net_revenue, 'FM999,999,999,999') as net_revenue,
	to_char(
		(net_revenue - lag(net_revenue, 1) over (order by report_year))
		/ nullif(lag(net_revenue, 1) over (order by report_year), 0) *100,
		'FM999.99') || '%' as yoy_growth
from annual_metrics	
order by report_year asc;

-- Refund Rate (by year and traffic source)
with refunds as (
	select
		order_id,
		1 as refunded
	from order_item_refunds
	group by 1
)
select 
	date_part('year', date.report_date)::int as report_year,
	case
		when ws.utm_source = 'bsearch' then 'Bing'
		when ws.utm_source = 'gsearch' then 'Google'
		when ws.utm_source = 'socialbook' then 'Social Book'
		else 'Organic'
	end as traffic_source,
	to_char(count(r.refunded)::decimal / nullif(count(date.order_id), 0) * 100, 
		'FM99.99') || '%' as refund_rate
from report_date_orders date
left join website_sessions ws 
	on date.website_session_id = ws.website_session_id
left join refunds r 
	on date.order_id = r.order_id
group by 1, 2
order by 1 asc, 2 asc;

-- Shows Total Sessions per year and per device type, Orders, and Conversion Rate
with sessions as (
	select
		website_session_id,
		(created_at::text::timestamp)::date as session_date,
		(case when device_type = 'desktop' then 1 else 0 end) as desktop_session,
		(case when device_type = 'mobile' then 1 else 0 end) as mobile_session 
	from website_sessions
)
select
	date_part('year', sessions.session_date)::int as session_year,
	count(web.website_session_id) as total_sessions,
	count(orders.order_id) as total_orders,
	-- total conversion rate:
	to_char(
		100.0 * (count(orders.order_id)::decimal / count(web.website_session_id)::decimal),
		'FM99.99') || '%' as total_conversion_rate,
	-- desktop cvr:
	to_char(
		100.0 * (count(case when web.device_type = 'desktop' then orders.order_id else null end))::decimal
		/ nullif(sum(sessions.desktop_session), 0)::decimal,
		'FM99.99') || '%' as desktop_conversion,
	-- mobile conversion rate:
	to_char(
		100.0 * (count(case when web.device_type = 'mobile' then orders.order_id else null end))::decimal
		/ nullif(sum(sessions.mobile_session), 0)::decimal,
		'FM99.99') || '%' as mobile_conversion
from website_sessions web 
left join sessions 
	on sessions.website_session_id = web.website_session_id
left join orders 
	on web.website_session_id = orders.website_session_id
group by 1
order by 1;

-- View for computing gross and net revenue 
create or replace view revenue_order as 
	select
		orders.order_id,
		website_session_id,
		(orders.created_at)::date as order_date,
		orders.price_usd as gross_revenue,
		coalesce((refund.total_refund_amount),0) as refund_amount,
		(orders.price_usd) - coalesce((refund.total_refund_amount), 0) as net_revenue
	from orders
	left join total_refund_usd refund
		on orders.order_id = refund.order_id;

-- Shows Average Order Value (AOV) (revenue/orders)
select
	date_part('year', date.report_date)::int as report_year,
	to_char(
		sum(revenue.net_revenue) / count(revenue.order_id)::decimal, 'FM999,999,999,999.99') as aov
from revenue_order revenue
left join report_date_orders date
	on revenue.order_id = date.order_id
group by 1
order by 1 asc
;

-- Shows Revenue Per Session (RPS) per year 
select
	date_part('year', date.report_date)::int as year,
	case
		when ws.utm_source = 'bsearch' then 'Bing'
		when ws.utm_source = 'gsearch' then 'Google'
		when ws.utm_source = 'socialbook' then 'Social Book'
		else 'Organic'
	end as traffic_source,
	to_char(
		sum(ro.gross_revenue) - sum(ro.refund_amount),
		'FM999,999,999,999') as net_revenue,
	to_char(count(ro.website_session_id), 'FM999,999,999') as total_sessions,
	to_char(
		(sum(ro.gross_revenue) - sum(ro.refund_amount)) / 
		count(ro.website_session_id),
		'FM99.99') as rps
from revenue_order ro
left join report_date_orders date
	on ro.order_id = date.order_id
left join website_sessions ws
	on ro.website_session_id = ws.website_session_id
group by date_part('year', date.report_date)::int, traffic_source
order by year asc;

-- II. Traffic & Channel Performance

-- By Channel: Sessions, Orders, Revenue, Conversion Rate
with ws_date_clean as (
	select 
		website_session_id,
		(created_at::text::timestamp)::date as session_date
	from website_sessions
)
select
	date_part('year', date.session_date)::int as year,
	case
		when ws.utm_source = 'bsearch' then 'Bing'
		when ws.utm_source = 'gsearch' then 'Google'
		when ws.utm_source = 'socialbook' then 'Social Book'
		else 'Organic'
	end as traffic_source,
	to_char(count(ws.website_session_id), 'FM999,999,999') as total_sessions,
	count(ro.order_id) as total_orders,
	to_char(
		sum(ro.gross_revenue) - sum(ro.refund_amount),
		'FM999,999,999,999') as net_revenue,
	to_char(
		100.0 * (count(ro.order_id)::decimal / count(ws.website_session_id)::decimal),
		'FM999.99') || '%' as total_conversion_rate
from website_sessions ws
left join revenue_order ro
	on ws.website_session_id = ro.website_session_id
left join ws_date_clean date
	on ws.website_session_id = date.website_session_id
group by 1, 2
order by 1 asc;

-- By Channel: Sessions, Orders, Revenue, Conversion Rate - 2015 (latest)
with ws_date_clean as (
	select 
		website_session_id,
		(created_at::text::timestamp)::date as session_date
	from website_sessions
)
select
	date_part('year', date.session_date)::int as year,
	case
		when ws.utm_source = 'bsearch' then 'Bing'
		when ws.utm_source = 'gsearch' then 'Google'
		when ws.utm_source = 'socialbook' then 'Social Book'
		else 'Organic'
	end as traffic_source,
	to_char(count(ws.website_session_id), 'FM999,999,999') as total_sessions,
	count(ro.order_id) as total_orders,
	to_char(
		sum(ro.gross_revenue) - sum(ro.refund_amount),
		'FM999,999,999,999') as net_revenue,
	to_char(
		100.0 * (count(ro.order_id)::decimal / count(ws.website_session_id)::decimal),
		'FM999.99') || '%' as total_conversion_rate
from website_sessions ws
left join revenue_order ro
	on ws.website_session_id = ro.website_session_id
left join ws_date_clean date
	on ws.website_session_id = date.website_session_id
where date_part('year', date.session_date)::int = 2015
group by 1, 2
order by 1 asc, 6 desc;

-- RPS per Source and Campaign - 2015 
with ws_date_clean as (
	select 
		website_session_id,
		(created_at::text::timestamp)::date as session_date
	from website_sessions
)
select
	case
		when ws.utm_source = 'bsearch' then 'Bing'
		when ws.utm_source = 'gsearch' then 'Google'
		when ws.utm_source = 'socialbook' then 'Social Book'
		else 'Organic'
	end as traffic_source,
	ws.utm_campaign as campaign,
	to_char(sum(ro.gross_revenue) - sum(ro.refund_amount), 'FM999,999,999,999') as net_revenue,
	to_char(count(ws.website_session_id), 'FM999,999,999') as total_sessions,
	to_char(
		(sum(ro.gross_revenue) - sum(ro.refund_amount))
		/ count(ws.website_session_id), 'FM99.99') as rps
from website_sessions ws
left join revenue_order ro
	on ws.website_session_id = ro.website_session_id
left join ws_date_clean as date
	on ws.website_session_id = date.website_session_id
where date_part('year', date.session_date)::int = 2015
group by 1, 2
order by 5 desc;

-- RPS per content - 2015
with ws_date_clean as (
	select 
		website_session_id,
		(created_at::text::timestamp)::date as session_date
	from website_sessions
)
select
	case
		when ws.utm_source = 'bsearch' then 'Bing'
		when ws.utm_source = 'gsearch' then 'Google'
		when ws.utm_source = 'socialbook' then 'Social Book'
		else 'Organic'
	end as traffic_source,
	ws.utm_content as content,
	to_char(sum(ro.gross_revenue) - sum(ro.refund_amount), 'FM999,999,999,999') as net_revenue,
	to_char(count(ws.website_session_id), 'FM999,999,999') as total_sessions,
	to_char(
		(sum(ro.gross_revenue) - sum(ro.refund_amount))
		/ count(ws.website_session_id), 'FM99.99') as rps
from website_sessions ws
left join revenue_order ro
	on ws.website_session_id = ro.website_session_id
left join ws_date_clean as date
	on ws.website_session_id = date.website_session_id
where date_part('year', date.session_date)::int = 2015
group by 1, 2
order by 5 desc;

-- RPS per device type and source
with ws_date_clean as (
	select 
		website_session_id,
		(created_at::text::timestamp)::date as session_date
	from website_sessions
)
select
	case
		when ws.utm_source = 'bsearch' then 'Bing'
		when ws.utm_source = 'gsearch' then 'Google'
		when ws.utm_source = 'socialbook' then 'Social Book'
		else 'Organic'
	end as traffic_source,
	ws.device_type as device,
	to_char(sum(ro.gross_revenue) - sum(ro.refund_amount), 'FM999,999,999,999') as net_revenue,
	to_char(count(ws.website_session_id), 'FM999,999,999') as total_sessions,
	to_char(
		(sum(ro.gross_revenue) - sum(ro.refund_amount))
		/ count(ws.website_session_id), 'FM99.99') as rps
from website_sessions ws
left join revenue_order ro
	on ws.website_session_id = ro.website_session_id
left join ws_date_clean as date
	on ws.website_session_id = date.website_session_id
where date_part('year', date.session_date)::int = 2015
group by 1, 2
order by 5 desc;

-- III. Conversion Behavior 

-- First Time Buyer Rate (first time buyer / unique visitors) * 100
with order_ranking as (
	select
		date_part('year', date.report_date)::int as order_year,
		o.order_id,
		o.website_session_id,
		o.user_id,
		row_number() over (partition by o.user_id order by date.report_date) as order_rank
	from orders o
	left join report_date_orders date
		on o.order_id = date.order_id
),
first_order_count as (
	select
		r.order_year,
		r.user_id,
		count (distinct r.user_id) as first_time_buyer,
		case
			when ws.utm_source = 'bsearch' then 'Bing'
			when ws.utm_source = 'gsearch' then 'Google'
			when ws.utm_source = 'socialbook' then 'Social Book'
			else 'Organic'
		end as traffic_source
	from order_ranking r
	inner join website_sessions ws
		on r.website_session_id = ws.website_session_id
	where order_rank = 1
	group by 1, 2, 4
),
unique_visitors as (
	select
		date_part('year', created_at::text::date)::int as order_year,
		count(distinct user_id) as unique_visitors,
		case
			when utm_source = 'bsearch' then 'Bing'
			when utm_source = 'gsearch' then 'Google'
			when utm_source = 'socialbook' then 'Social Book'
			else 'Organic'
		end as traffic_source
	from website_sessions
	group by 1, 3
)
select 
	v.order_year,
	sum(f.first_time_buyer) as first_time_buyers,
	v.unique_visitors,
	v.traffic_source,
	to_char(
		(sum(f.first_time_buyer) / nullif(v.unique_visitors, 0)) * 100,
		'FM999.99') || '%' as ftbr
from unique_visitors v
left join first_order_count f 
		on v.order_year = f.order_year
	and v.traffic_source = f.traffic_source
group by 1, 3, 4
order by v.order_year asc, v.traffic_source asc;

-- Repeat Purchase Rate (by traffic source) (# of repeat orders / total orders)
	-- repeat purchase definition: user_id appearing more than once 
with repeat_purchase as (
	select
		user_id,
		count(user_id) as total_purchase
	from orders
	group by 1
)
select
	date_part('year', o.created_at::timestamp)::int as report_year,
	case
		when ws.utm_source = 'bsearch' then 'Bing'
		when ws.utm_source = 'gsearch' then 'Google'
		when ws.utm_source = 'socialbook' then 'Social Book'
		else 'Organic'
	end as traffic_source,
	count(case when rp.total_purchase > 1 then o.user_id else null end) as repeat_purchase,
	count(o.user_id) as total_orders,
	to_char(
		count(case when rp.total_purchase > 1 then o.user_id else null end)::decimal
			/ nullif(count(o.user_id), '0') * 100.0, 'FM99.99') as repeat_purchase_rate
from orders o
left join repeat_purchase rp
	on o.user_id = rp.user_id
left join website_sessions ws 
	on o.website_session_id = ws.website_session_id
group by 1, 2
order by 1 asc, 5 desc;

-- Time to Second Purchase (avg days between first and second order by channel)
with ranked_orders as (
	select
		date.website_session_id,
		(date.report_date::text::timestamp)::date as order_date,
		lead(date.report_date, 1) over (partition by o.user_id order by date.report_date::text::timestamp::date) as next_order_date,
		row_number() over (partition by o.user_id order by date.report_date::text::timestamp::date) as purchase_number
	from orders o 
	left join report_date_orders date
		on o.order_id = date.order_id
)
select
	date_part('year', order_date)::int as report_year,
	case
		when ws.utm_source = 'bsearch' then 'Bing'
		when ws.utm_source = 'gsearch' then 'Google'
		when ws.utm_source = 'socialbook' then 'Social Book'
		else 'Organic'
	end as traffic_source,
	to_char(avg(next_order_date - order_date), 'FM999.99') || ' days' as timeto_second_purchase
from ranked_orders ro
left join website_sessions ws
	on ro.website_session_id = ws.website_session_id
where purchase_number = 1
	and next_order_date is not null
group by 1, 2;

-- Pageview Drop Off Analysis
with pageviews_date as (
	select
		(created_at::text::timestamp)::date as view_date,
		pageview_url,
		website_session_id
	from website_pageviews
),
funnel_count as (
	select
		date_part('year', view_date)::int as pageview_year,
		count(case when pageview_url in ('/home', '/lander-1', '/lander-2', '/lander-3', '/lander-4', '/lander-5') then website_session_id else null end) as landing,
		count(case when pageview_url like '%/products%' then website_session_id else null end) as product,
		count(case when pageview_url like '%/cart%' then website_session_id else null end) as cart_activity,
		count(case when pageview_url like '%/shipping%' then website_session_id else null end) as shipping,
		count(case when pageview_url in ('/billing', '/billing-2') then website_session_id else null end) as billing,
		count(case when pageview_url like '%/thank-you-for-your-order%' then website_session_id else null end) as order_completion
	from pageviews_date
	group by 1
	order by 1 asc
)
select
	pageview_year,
	to_char(100.0 * product / nullif(landing, 0), 'FM99.99') || '%' as landing_to_prod,
	to_char(100.0 * cart_activity / nullif(product, 0), 'FM99.99') || '%' as prod_to_cart,
	to_char(100.0 * shipping / nullif(cart_activity, 0), 'FM99.99') || '%' as cart_to_shipping,
	to_char(100.0 * billing / nullif(shipping, 0), 'FM99.99') || '%' as shipping_to_billing,
	to_char(100.0 * order_completion / nullif(billing, 0), 'FM99.99') || '%' as billing_to_complete
from funnel_count
order by 1;

-- IV. Profit Margin Analysis 

-- Update revenue_order view to include cogs and profit
create or replace view revenue_order as 
	select
		orders.order_id,
		website_session_id,
		(orders.created_at)::date as order_date,
		orders.price_usd as gross_revenue,
		coalesce((refund.total_refund_amount),0) as refund_amount,
		(orders.price_usd) - coalesce((refund.total_refund_amount), 0) as net_revenue,
		orders.cogs_usd as cogs,
		(orders.price_usd) - coalesce((refund.total_refund_amount), 0) - orders.cogs_usd as profit
	from orders
	left join total_refund_usd refund
		on orders.order_id = refund.order_id;

-- Against Traffic Source
with ws_date as (
	select
		(created_at::text::timestamp)::date as view_date,
		website_session_id
	from website_sessions
)
select
	date_part('year', view_date)::int as report_year,
	case
		when ws.utm_source = 'bsearch' then 'Bing'
		when ws.utm_source = 'gsearch' then 'Google'
		when ws.utm_source = 'socialbook' then 'Social Book'
		else 'Organic'
	end as traffic_source,
	to_char(
		(sum(ro.profit) / nullif(sum(ro.net_revenue), 0)) * 100.0, 'FM999.999') || '%' as profit_margin
from website_sessions ws
left join orders o 
	on o.website_session_id = ws.website_session_id
left join ws_date date
	on ws.website_session_id = date.website_session_id
left join revenue_order ro
	on o.order_id = ro.order_id
group by 1, 2;

-- Against Product Line
with ws_date as (
	select
		(created_at::text::timestamp)::date as view_date,
		website_session_id
	from website_sessions
),
session_product_bridge as (
	select
	website_session_id,
	coalesce(
		max(case
				when pageview_url like '%sugar-panda%' then 'Birthday Sugar Panda'
				when pageview_url like '%love-bear%' then 'Forever Love Bear'
				when pageview_url like '%mini-bear%' then 'Hudson River Mini Bear'
				when pageview_url like '%mr-fuzzy%' then 'Original Mr. Fuzzy'
				else null
			end),
		'Other') as primary_product_viewed
	from website_pageviews
	group by 1
)
select
	date_part('year', view_date)::int as report_year,
	bridge.primary_product_viewed,
	to_char(sum(ro.gross_revenue), 'FM999,999,999,999') as gross_revenue,
	to_char(sum(ro.profit), 'FM999,999,999,999') as profit,
	to_char(
		(sum(ro.profit) / nullif(sum(ro.net_revenue), 0)) * 100.0, 'FM999.99') || '%' as profit_margin
from website_sessions ws 
left join ws_date date
	on ws.website_session_id = date.website_session_id
left join session_product_bridge bridge
	on ws.website_session_id = bridge.website_session_id
left join orders o 
	on o.website_session_id = ws.website_session_id
left join revenue_order ro
	on o.order_id = ro.order_id
group by 1, 2
having sum(ro.net_revenue) > 0
order by 1 asc, 5 desc;

-- Market Basket Analysis
with primary_item as (
	select
		date.report_date as date,
		oi.order_id as order_id,
		oi.product_id as product_id,
		p.product_name as product_name,
		oi.is_primary_item as is_primary
	from order_items oi
	left join report_date_orders date
		on oi.order_id = date.order_id
	left join products p 
		on oi.product_id = p.product_id
)
select
	date_part('year', p.date)::int as order_year,
	p.product_name as primary_product,
	s.product_name as secondary_product,
	count(distinct p.order_id) as total_orders
from primary_item p
left join primary_item s
	on p.order_id = s.order_id
	and s.is_primary = 0
where p.is_primary = 1
	and s.product_id is not null
group by 1, 2, 3
order by 1 asc, 4 desc;

-- Hook vs Filler Product
select
	date_part('year', date.report_date)::int as order_year,
	p.product_name,
	count(case when oi.is_primary_item = 1 then oi.order_id end) primary_purchase,
	count(case when oi.is_primary_item = 0 then oi.order_id end) as secondary_purchase,
	to_char(
			count(case when oi.is_primary_item = 0 then oi.order_id end)::numeric
				/ count(oi.order_id) * 100.0, 'FM99.99') as cross_sell_rate
from order_items oi
left join report_date_orders date
	on oi.order_id = date.order_id
left join products p 
	on oi.product_id = p.product_id
group by 1, 2
order by 1 asc, 
	(count(case when oi.is_primary_item = 0 then oi.order_id end):: numeric / nullif(count(oi.order_id), 0)) desc;
 