#!/bin/bash
curl -sf "api.openweathermap.org/data/2.5/weather?id=3128760&appid=8323d066a70160450c499b7ed6d4bf98&units=metric" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f\"{d['main']['temp']:.0f}°C {d['weather'][0]['description']}\")" 2>/dev/null || echo "N/A"
