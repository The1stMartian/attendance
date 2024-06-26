# Auto-install required packages
list.of.packages <- c("shiny", "readr", "shinyjs", "shinydashboard", "htmltools", "htmltools", "dplyr", "shiny.fluent", "shinythemes")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library(shiny)
library(readr)
library(shinyjs)
library(shinydashboard)
library(htmltools)
library(dplyr)
library(shiny.fluent)
library(shinythemes)
library(stringi)

# Customize
attendanceFile = "wnp.csv"
data <- read.csv(paste0("www/", attendanceFile), check.names=F)
backupFolder = "daily_backup_data"
pageTitle = HTML("<b>West Nashville Phoenix Lodge #131</b><br>Digital Log Book")
pageLogo = "wnpLogo.jpg" #expected in folder ./www

eventDefault = "None"
candidateDefault = "None"
visitorDefault = "None"

current_date = as.Date(format(Sys.Date(), "%Y-%m-%d"))
day = weekdays(current_date)

# Input data cleanup: remove columns of "NA" values based on "" col name
allCols = colnames(data)
goodCols = allCols[allCols != ""]
data = data %>% select(goodCols)

events = c("Unspecified", 
           "SM", "EA Degree", 
           "FC Degree", 
           "MM Degree", 
           "Education", 
           "Practice")

# Officer station options for drop down menu
stations = c("None",
             "Worshipful Master",
             "Secretary",
             "Treasurer",
             "Senior Warden",
             "Junior Warden",
             "Senior Deacon",
             "Junior Deacon",
             "Senior Steward",
             "Junior Steward",
             "Tyler",
             "Chaplain")

roleList = c("None",
  "MM-KS",
       "MM-RWSGW",
       "MM-RWSGS",
       "MM-GC",
       "MM-SD",
       "MM-R1",
       "MM-R2",
       "MM-R3",
       "MM-WFM",
       "MM-SC",
       "MM-C1",
       "MM-C2",
       "MM-C3",
       "MM-stereoptics",
       "MM-LectureAnswers",
       "MM-Charge"
      )

# Define UI
ui <- fluidPage(
  useShinyjs(), # Initialize shinyjs for buttons
  titlePanel(pageTitle),
  theme = shinytheme("cerulean"),
  
  sidebarLayout(
    sidebarPanel(
      selectizeInput("name", "Select Name:",
                     choices = unique(data$FullName), 
                     options = list(placeholder = 'Select or type a name')),
      selectInput("station", "Station:", choices = unique(stations)),
      selectInput("role", "Role:", choices = unique(roleList)),
      textInput("date", "Date:", value = current_date),
      textInput("day", "Day:", value = day),
      #textInput("eventType", "Event Type:"),
      selectInput("eventType", "Event:", choices = unique(events)),
      textInput("candidate", "Candidate:", ""),
      textInput("visitor", "Guest & Lodge Info.:"),
      actionButton("enterButton", "Enter"),
      
    ),
    
    mainPanel(
      uiOutput("currentInfo"),
      HTML("<br><br>"),
      #tags$img(src = "wnpLogo.jpg", height = "350", width = "350"),
      HTML('<center><img src = "wnpLogo.jpg", height = "350", width = "350"></center>'),
      div(style = "text-align: right;", actionButton("Save", "Save Meeting"))
    )
  )
)

# Server function
server <- function(input, output, session) {
  
  # Initialize an empty data frame to store the entries
  entries <- reactiveVal(data.frame(
    Name = character(),
    Station = character(),
    Role = character(),
    Date = as.Date(character()),
    Day = character(),
    Event = character(),
    Candidate = character(),
    Visitors = character(),
    stringsAsFactors = FALSE
  ))
  
  # Delete me
  #oc = data.frame(Station=c("a", "b", "c", "d", "e"), 
  #                Name = c("jeff", "chris", "chris", "Mike", ""),
  #                Date = c("", "", "", "Date!", ""),
  #                Event = c("", "", "", "", "Event!"))
  
  
  # Save data when Quit and Save button has been clicked
  observeEvent(input$Save, {
    
    # Edit the data:
    todaysData = as.data.frame(entries())
    
    # Collect attendee names and station/role
    attendeeDF = todaysData[todaysData$Name != "",]     # get rid of blanks
    attendeeDF = attendeeDF %>% group_by(Name) %>% slice_tail() %>% ungroup() 
    
    # Collect candidate
    oc = unique(todaysData$Candidate)
    if (length(oc) > 1){oc = tail(oc, n=1)} # get last candidate entry
    
    # Collect last event entry 
    oe = todaysData$Event  # all event entries
    oe = oe[oe != ""] # get rid of blank events
    if (length(oe) < 1){oe = eventDefault}
    else if (length(oe) == 1){oe = sapply(oe, "[[", 1)} # get the only
    else if (length(oe) > 1){oe = tail(oe, n=1)} # if multiple, get last 
    
    # Calendar info
    oday = unique(todaysData$Day)  # day
    odate = unique(todaysData$Date)  # date
    meetingDate = format(Sys.Date(), "%Y-%m-%d")
    
    # Collect visitor info
    vis = todaysData %>% filter(Visitors != "") %>% select(Visitors, Station) # Visitors
    vis$Combo = paste(vis$Visitors, " ", vis$Station)
    #visPaste = sapply(vis$Combo, paste, collapse=" | ") # visitors as one string
    
    # Create data frame of today's info
    todayDF = attendeeDF %>% select(c("Name","Station"))
    todayDF = rbind(todayDF, c("Day", oday))
    todayDF = rbind(todayDF, c("Candidate", oc))
    todayDF = rbind(todayDF, c("Event", oe))
    todayDF = rbind(todayDF, c("Visitors", paste(vis$Combo, collapse = "| ")))
    
    # filter out double entries 
    todayDF = todayDF[!duplicated(todayDF[,c('Name')]),]
    
    # Change new data column to today's date
    colnames(todayDF)[1] = "FullName"
    colnames(todayDF)[2] = meetingDate
    
    # Remove blank entries
    todayDF = todayDF[todayDF["FullName"] != "<WNP Member>",]
    
    # Store temp data as file in case of column-header duplication error
    savePath = "www/"
    tempFolder = "temp/"
    dir.create(file.path(savePath, tempFolder), showWarnings = FALSE) # make temp dir
    t = format(Sys.time(), "%b %d %X %Y")
    t = gsub(":", ".", t)
    tempFile <- paste0(t, "_wnp.csv")
    write.csv(todayDF, file.path(savePath, tempFolder, tempFile), row.names = FALSE, quote=F)
    
    # Overwrite column if it already exists in the data file
    
    # Get new column name
    newColName = colnames(todayDF)[2] # new column to be merged to old data
    
    # If new column name (the date) exists in input data, drop original col. 
    if (newColName %in% colnames(data) == "TRUE"){
      data = data %>% select(!newColName)
    }
    
    # Merge original data with current:
    merged = left_join(data, todayDF, by="FullName")
    
    # Clean up data: replace "NA" with "A" for absent
    merged[is.na(merged[meetingDate]), meetingDate] = "A"
    
    # Define the main output file path
    saveFile <- paste0(format(Sys.Date(), "%Y-%m-%d"), "_wnp.csv")
    
    # Save the entries to a backup.csv file
    backupPath = file.path("www/", backupFolder)
    dir.create(backupPath, showWarnings = FALSE)
    write.csv(merged, file.path(backupPath, saveFile), row.names = FALSE, quote=F)
    
    
    # Save entries - update original file
    tryCatch({
      write.csv(merged, file.path(savePath, attendanceFile), row.names = FALSE, quote=F)
    },
    error = function(cond){print("Cannot save. Is data file open in another app?")})
    
    # Add quit app function to the Save button
    # stopApp()
  })
  
  # Reactive values for persistent data storage
  values <- reactiveValues(
    event = "",
    candidate = "",
    visitorList = c(),
    attendeeData = data.frame(Name = character(), Station = character(), stringsAsFactors = FALSE)
  )
  
  
  observeEvent(input$enterButton, {
    
    # Database entry (not display)
    new_entry <- data.frame(
      Name = input$name,
      Station = paste0(input$station, " ", input$role),
      Date = as.Date(input$date),
      Day = input$day,
      Event = input$eventType,
      Candidate = input$candidate,
      Visitors = paste(input$visitor, collapse = "| "),
      stringsAsFactors = FALSE
    )
    
    # Update the entries data frame
    entries(rbind(entries(), new_entry))
    
    # Gui display entry: Attendee (station, role)
    if (!is.null(input$name) && input$name != "" && input$name != "<WNP Member>") {
      stationRole = paste0(input$station, ", ", input$role)
      newAttendee <- data.frame(Name = input$name, Station = stationRole, stringsAsFactors = FALSE)
      values$attendeeData <- rbind(values$attendeeData, newAttendee)
    }
    
    # Update visitorList only if a new visitor is entered and it's not empty
    if (!is.null(input$visitor) && input$visitor != "") {
      newVisitorEntry = paste0(input$visitor, " ", input$station, " ", input$role)
      values$visitorList <- unique(c(values$visitorList, newVisitorEntry))
    }
    
    # Update candidate
    if (!is.null(input$candidate) && input$candidate != "") {
      values$candidate <- input$candidate
    }
    
    # Update event
    if (!is.null(input$eventType) && input$eventType != "") {
      values$event <- input$eventType
    }
    
    # Clear input fields
    updateSelectInput(session, "name", selected = "None")
    updateSelectInput(session, "station", selected = "None")
    updateTextInput(session, "date", value = format(Sys.Date(), "%Y-%m-%d"))
    updateTextInput(session, "day", value = weekdays(Sys.Date()))
    updateTextInput(session, "eventType", value = "")
    updateTextInput(session, "candidate", value = "")
    updateTextInput(session, "visitor", value = "")
    updateSelectInput(session, "role", selected = "None")
    reset("name")
  })
  
  observe({
    runjs("
      $(document).on('keyup', function(e) {
        if(e.which == 13 && !e.shiftKey) {
          e.preventDefault();
          $('#enterButton').click();
        }
      });
    ")
  })
  
  # Outputs all data with HTML formatting
  output$currentInfo <- renderUI({
    attendeeInfo <- apply(values$attendeeData, 1, function(row) {
      paste0(row["Name"], " (", row["Station"], ")")
    })
    
    info <- list(
      paste0("<b>Date: </b>", htmlEscape(weekdays(Sys.Date())), ", ", htmlEscape(format(Sys.Date(), "%b %d, %Y"))),
      paste(""),
      paste("<b>Event:</b>", htmlEscape(values$event)),
      paste(""),
      paste("<b>Candidate:</b>", htmlEscape(values$candidate)),
      paste(""),
      paste("<b>Attendees:</b>", htmlEscape(toString(attendeeInfo))),
      paste(""),
      paste("<b>Guests:</b>", htmlEscape(toString(sapply(values$visitorList, as.character))))
    )
    
    HTML(paste(info, collapse = "<br/>"))
  })
}

# Run the application 
shinyApp(ui = ui, server = server)