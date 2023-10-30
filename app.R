suppressMessages(library(shiny))
suppressMessages(library(data.table))
suppressMessages(library(DT))
suppressMessages(library(leaflet))
suppressMessages(library(geojsonio))
suppressMessages(library(sf))
suppressMessages(library(tidyverse))
suppressMessages(library(rsconnect))

itl2_geojson <- geojson_sf("itl2_crs_4326.geojson")

# Define UI
ui <- fluidPage(
    navbarPage(
        title = "ITL2 Chloropleth Mapping Tool",
        tabPanel("Information", includeHTML("info_text.html")),
        tabPanel("File Upload", sidebarLayout(
            sidebarPanel(
                fileInput(inputId = "file_upload", label = "Upload CSV File"),
                numericInput(
                    "size",
                    "Max File Size (MB)",
                    value = 1000,
                    min = 0,
                    max = 10000,
                    step = 100
                )
            ),
            mainPanel(
                verbatimTextOutput("file_info")
            )
        )),
        tabPanel("Chloropleth Map", sidebarLayout(
            sidebarPanel(
                selectInput(
                    inputId = "column",
                    label = "Select column.",
                    choices = NULL
                )
            ),
            mainPanel(
                leafletOutput("leaflet_map", width = "60vw", height = "90vh")
            )
        ))
    )
)


# Define server logic
server <- function(input, output) {
    observe({
        # Update the max file size
        options(shiny.maxRequestSize = input$size * 1024^2)
    })

    output$file_info <- renderPrint({
        if (is.null(input$file_upload)) {
            cat("No file uploaded.")
        } else {
            cat(
                "File name:\t",
                input$file_upload$name,
                "\nFile size:\t",
                round(input$file_upload$size / 1024^2, 1),
                " MB\n\n",
                sep = ""
            )
        }
    })

    upload_output <- reactive({
        req(input$file_upload)
        fread(input$file_upload$datapath)
    })

    observe({
        req(upload_output())
        updateSelectInput(
            inputId = "column",
            # Only list choices if they are numeric
            choices = names(upload_output())[sapply(upload_output(),
                is.numeric)]
        )
    })

    output$leaflet_map <- renderLeaflet({
        req(upload_output())

        # More efficent to do this reactive outside the leaflet render
        map_data <- dplyr::inner_join(itl2_geojson, upload_output())

        column_data <- as.data.frame(map_data) %>%
            dplyr::select(dplyr::all_of(input$column)) %>%
            unlist()

        quantile_num <- 10
        probs <- seq(0, 1, length.out = quantile_num + 1)

        bins <- quantile(
            column_data,
            probs,
            na.rm = TRUE,
            names = FALSE
        )

        while (length(unique(bins)) != length(bins)) {
            quantile_num <- quantile_num - 1
            probs <- seq(0, 1, length.out = quantile_num + 1)
            bins <- quantile(
                    column_data,
                    probs,
                    na.rm = TRUE,
                    names = FALSE
                )
            # Increase top bin value by 5% and decrease bottom by 5%
            # to ensure all values are included after rounding
            bins[1] <- bins[1] - 0.05 * abs(bins[1])
            bins[-1] <- bins[-1] + 0.05 * abs(bins[-1])

            if (quantile_num < 5) {
                bins <- seq(min(column_data,
                        na.rm = TRUE) - 0.05 * abs(min(column_data,
                        na.rm = TRUE)),
                    max(column_data,
                        na.rm = TRUE) +  0.05 * abs(max(column_data,
                        na.rm = TRUE)),
                    length.out = quantile_num + 1)
                break
             }
        }


        pal <- colorBin(
            "YlOrRd",
            domain = column_data,
            bins = signif(bins, 2)
        )

        labels <- sprintf(
            # If input$column matches money term then different label
            ifelse(
                grepl("cost|expenditure", tolower(input$column)),
                "<strong>%s</strong><br/>%s: £%g million",
                "<strong>%s</strong><br/>%s: %g"),
            map_data$ITL221NM, gsub("_", " ", input$column), column_data
        ) %>% lapply(htmltools::HTML)

        leaflet(map_data) %>%
            setView(-2.5, 54, 5) %>%
            addTiles(
                options = providerTileOptions(minZoom = 4, maxZoom = 13),
                group = "OpenStreetMap"
            ) %>%
            addProviderTiles(providers$CartoDB.Positron,
                options = providerTileOptions(minZoom = 4, maxZoom = 13),
                group = "CartoDB Positron"
            ) %>%
            addPolygons(
                fillColor = ~ pal(get(input$column)),
                weight = 1,
                opacity = 1,
                color = "white",
                dashArray = "3",
                fillOpacity = 0.4,
                highlightOptions = highlightOptions(
                    weight = 4,
                    color = "#666",
                    dashArray = "",
                    fillOpacity = 0.4,
                    bringToFront = TRUE
                ),
                label = labels,
                labelOptions = labelOptions(
                    style = list("font-weight" = "normal", padding = "3px 8px"),
                    textsize = "15px",
                    direction = "auto"
                )
            ) %>%
            addLayersControl(
                baseGroups = c("CartoDB Positron", "OpenStreetMap"),
                options = layersControlOptions()
            ) %>%
            addLegend(
                pal = pal, values = ~get(input$column),
                opacity = 0.7,
                title = gsub("_", " ", input$column),
                position = "bottomright",
                # If input$column matches money term then money format
                labFormat = labelFormat(prefix = ifelse(
                    grepl("cost|expenditure", tolower(input$column)),
                    "£", ""
                ), suffix = ifelse(
                    grepl("cost|expenditure", tolower(input$column)),
                    " million", ""
                ))
            ) %>%
            addEasyButton(easyButton(
                icon = "fa-globe", title = "Zoom to Level 5",
                onClick = JS("function(btn, map){ map.setZoom(5); }")
            )) %>%
            addEasyButton(easyButton(
                icon = "fa-crosshairs", title = "Locate Me",
                onClick = JS("function(btn, map){ map.locate({setView: true}); }") # nolint
            )) %>%
            addMeasure(
                position = "bottomleft",
                primaryLengthUnit = "meters",
                secondaryLengthUnit = "kilometers",
                primaryAreaUnit = "sqmeters",
                secondaryAreaUnit = "hectares",
                activeColor = "#3D535D",
                completedColor = "#7D4479"
            )
    })
}

# Run the app
runApp(shinyApp(ui, server), launch.browser = TRUE)
