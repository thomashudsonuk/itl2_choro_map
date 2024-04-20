# Automatic ITL2 Choropleth Map
An R Shiny app for automatically mapping ITL2 data on a choropleth map.

https://github.com/thomashudsonuk/itl2_choro_map/assets/5777564/eb157d07-eac6-47e0-9c69-717d16390c4f

## How to use

- Ensure libraries are installed (provide code to install if not already - bake into the app if possible).
- Run following `R` code:
``` R
library(shiny)
runGitHub("itl2_choro_map", "thomashudsonuk") 
```
- Upload data (client side so no storage of data)
- Make sure the first column is the ITL221NM (the name of the ITL2)
- Future versions will have ITL1 and ITL3 as options.

### Things to add

- Normalisation options e.g. per hectare, or per capita
- Add explanation of geojson source
- Explain bins and colour palette
- Choose ITL1, ITL2, and ITL3
- Choose number of significant figures

