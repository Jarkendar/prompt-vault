Here is the raw market data for analysis:

<market_data>
{{ JSON.stringify($json, null, 2) }}
</market_data>

## DATA LEGEND

- **Symbol:** Stock ticker.
- **Current_Price:** Closing price.
- **1D, 7D, 30D, 1Y:** Percentage changes (value 5 = 5%).
- **[PLN], [USD], [%]:** Data units.

## INSTRUCTIONS

Today's date is: <current_date>

1. Use Google Search to find the latest news. Completely ignore articles older than 3 days. If Google returns only old articles, assume there is NO fresh news and state this explicitly (Importance 0–2).
2. Identify events from the last 24 hours.
3. Assess the importance of this information on a scale of 0–10 according to the criteria in the system prompt.