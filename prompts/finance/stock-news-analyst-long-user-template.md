Here is the raw market data for analysis:

<market_data>
{{ JSON.stringify($json, null, 2) }}
</market_data>

## DATA LEGEND

- **Symbol:** Stock ticker.
- **Current_Price:** Closing price.
- **1D, 7D, 30D, 1Y:** Percentage changes (value 5 = 5%).
- **[PLN], [USD], [%]:** Data units.

## TASK

Today's date is: <current_date>

1. Use Google Search to find the latest news. Completely ignore articles older than 3 days. If Google returns only old articles from 2023, 2024, or 2025, assume there is NO fresh news and state this explicitly (Importance 0–2).
2. Assess the importance level (0–10) and write a brief explanation.
3. Return the result as JSON with fields `"importance"` and `"description"`.