# Ecommerce Growth and Performance Analysis
This project uses Maven Analytics' Fuzzy Factory dataset to explore marketing, website, and financial performance using PostgreSQL and PowerBI (upcoming).

> **Context:** Fuzzy Factory is an online retailer of teddy bears. With detailed marketing (website sessions, website pageviews per user id) and order data, the retailer is looking to optimize its marketing channels, and measure and understand its website conversion performance.

## Key Insights
### Traffic and Channel Performance
**Bing remains supreme in terms of Revenue per Session (RPS) and conversion with Google coming in as a close second.**  
- Bing's performance in branded RPS (6.21%) and conversion rate (8.75%) indicates a high buying intent among customers in this channel.
- Google's performance in nonbrand RPS (5.2%) and conversion rate of 8.55% shows that SEO strategies and landing pages are efficient in converting strangers to customers.
  
**Recommendation:** As high-intention is already present in Bing, shifting the budget to enhancing visibility in Google can optimize traffic channels and influence awareness. Increasing online presence in social media channels may boost organic traffic. 


**Customers are mainly present via desktop.**
- RPS through desktop devices is the highest across all traffic channels (Organic searches, Google, and Bing)
- May imply that purchases are characterized by high intent rather than impulse. 

**Recommendation:** Optimize website experience for desktop users. To capitalize on impulse buying behavior, boosting social media visibility is key to direct traffic from social media channels to the official website. Providing a seamless mobile shopping experience is crucial in boosting mobile conversion rates. 

### Conversion Behavior
**Bing is the touchpoint of first-time buyers and repeat purchases.**  
- While Organic traffic remains supreme in repeat purchases, Bing consistently outperforms Google in bringing repeat purchases.
- This further enforces Bing's efficiency in bringing high-intent and repeat customers.

**Organic traffic brings the shortest second purchase interval (18 days), followed by Google (27 days) and Bing (34 days).**
- Second purchases take over a month in Bing despite its high efficiency and conversion.

**Recommendation:** Strengthen after-sales relationships with customers through email marketing by sending follow-up emails after ~15 days of the previous purchase. Provide exclusive small discounts after a month of inactivity. 




## Measures Explored (SQL)
**Executive Performance:** Gross Revenue, Net Revenue, Refund %, Profit, YoY Growth, Refund Rate (by traffic source), Average Order Value (AOV), Revenue per Session (RPS), Total Sessions (by device type, and conversion rate.  

**Traffic and Channel Performance:** Sessions, Orders, Revenue, and Conversion Rate by channel; RPS per source and campaign; RPS per content; RPS per device type and source.  

**Conversion Behavior:** First Time Buyer Rate (FTBR), Repeat Purchase Rate, Time to Second Purchase, Pageview Drop Off Analysis  

**Profit Margin Analysis:** Profit Margin against traffic source, Profit Margin against product line, Market Basket Analysis, Hook vs Filler Product  
