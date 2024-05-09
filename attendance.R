# Changes: overwrites same date

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


# Customize
attendanceFile = "wnp.csv"
data <- read.csv(paste0("www/", attendanceFile), check.names=F)
pageTitle = "West Nashville Phoenix Lodge #131 - Digital Log Book"
pageLogo = "wnpLogo.jpg" #expected in folder ./www

eventDefault = "None"
candidateDefault = "None"
visitorDefault = "None"

current_date = as.Date(format(Sys.Date(), "%Y-%m-%d"))
day = weekdays(current_date)

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
      textInput("date", "Date:", value = current_date),
      textInput("day", "Day:", value = day),
      textInput("eventType", "Event Type:"),
      textInput("candidate", "Candidate:", ""),
      textInput("visitor", "Visitor Name and Lodge Number:"),
      actionButton("enterButton", "Enter"),
      actionButton("Save", "Save")
    ),
    
    mainPanel(
      verbatimTextOutput("currentInfo"),
      tags$img(src = pageLogo, height = 480, width = 480)
      )
  )
)

# Server function
server <- function(input, output, session) {
    
    # Initialize an empty data frame to store the entries
    entries <- reactiveVal(data.frame(
      Station = character(),
      Name = character(),
      Date = as.Date(character()),
      Day = character(),
      Event = character(),
      Candidate = character(),
      Visitors = character(),
      stringsAsFactors = FALSE
    ))
    
    
    # Save data when Quit and Save button has been clicked
    observeEvent(input$Save, {
      
      # Edit the data:
      infile = as.data.frame(entries())
      
      # Combine visitors with stations in case they're helping out
      infile$V2 = apply(infile[ , c("Visitors", "Station")] , 1 , paste , collapse = "-" )
      
      # Collect correct candidate entry
      oc = unique(infile$Candidate)  # all candidate entries
      oc = oc[oc != ""]              # get rid of blanks
      if (length(oc) == 1){oc = sapply(oc, "[[", 1)} # get first entry
      else if (length(oc) < 1){oc = candidateDefault}
      else if (length(oc) > 1){oc = tail(oc, n=1)}  # if many entries, get last
      
      # Collect correct event entry
      oe = infile$Event  # all event entries
      oe = oe[oe != ""] # get rid of blank events
      if (length(oe) < 1){oe = eventDefault}
      else if (length(oe) == 1){oe = sapply(oe, "[[", 1)} # get the only
      else if (length(oe) > 1){oe = tail(oe, n=1)} # if multiple, get last 
      
      # Calendar info
      oday = unique(infile$Day)  # day
      odate = unique(infile$Date)  # date
      meetingDate = format(Sys.Date(), "%Y-%m-%d")
      print("MEETING DATE")
      print(meetingDate)
      
      # Collect visitor info
      vis = infile %>% filter(Visitors != "") %>% select(V2) # Visitors
      visPaste = sapply(vis, paste, collapse=":") # visitors as one string
      
      
      # Create data frame of today's info
      officers = infile %>% filter(Station != "None") %>% select(c("Name","Station"))
      officers = rbind(officers, c("Day", oday))
      officers = rbind(officers, c("Candidate", oc))
      officers = rbind(officers, c("Event", oe))
      officers = rbind(officers, c("Visitors", visPaste))
      
      # filter out double entries 
      officers = officers[!duplicated(officers[,c('Name')]),]
      
      # Change new data column to today's date
      colnames(officers)[1] = "FullName"
      colnames(officers)[2] = meetingDate
      
      # Remove blank entries
      officers = officers[officers["FullName"] != "<WNP Member>",]
      
      print("officers: ")
      print(officers)
      
      # Merge original data with current:
      merged = left_join(data, officers)
      
      # Clean up data: replace "NA" with "A" for absent
      merged[is.na(merged[meetingDate]), meetingDate] = "A"
      
      # Define the file path and name
      savePath <- "www/"
      saveFile <- paste0(format(Sys.Date(), "%Y-%m-%d"), "_wnp.csv")
      
      # Save the entries to a .csv file
      write.csv(merged, file.path(savePath, saveFile), row.names = FALSE, quote=F)
      
      # Save entries - update original file
      write.csv(merged, file.path(savePath, attendanceFile), row.names = FALSE, quote=F)
      
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
    
    # Create a new entry
    new_entry <- data.frame(
      Station = input$station,
      Name = input$name,
      Date = as.Date(input$date),
      Day = input$day,
      Event = input$eventType,
      Candidate = input$candidate,
      Visitors = paste(input$visitor, collapse = ", "),
      stringsAsFactors = FALSE
    )
    
    # Update the entries data frame
    entries(rbind(entries(), new_entry))
    
    # Append entry to attendee data
    if (!is.null(input$name) && input$name != "" && input$name != "<WNP Member>") {
      newAttendee <- data.frame(Name = input$name, Station = input$station, stringsAsFactors = FALSE)
      values$attendeeData <- rbind(values$attendeeData, newAttendee)
    }
    
    # Update visitorList only if a new visitor is entered and it's not empty
    if (!is.null(input$visitor) && input$visitor != "") {
      values$visitorList <- unique(c(values$visitorList, input$visitor))
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
  
  # Output only the last data entered
  output$lastDataEntered <- renderText({
    if (nrow(values$attendeeData) > 0) {
      lastEntry <- tail(values$attendeeData, 1)
      paste(
        "Name:", lastEntry$Name,
        "Station:", lastEntry$Station,
        "Visitors:", toString(lastEntry$Visitors)
      )
    } else {
      "No data entered yet."
    }
  })
  
  # Outputs all data
  output$currentInfo <- renderText({
    attendeeInfo <- apply(values$attendeeData, 1, function(row) {
      paste0(row["Name"], " (", row["Station"], ")")
    })
    
    info <- c(
      paste0("Today's Event: ", weekdays(Sys.Date()), ", ", format(Sys.Date(), "%B %d, %Y")),
      "",
      paste("Event Type:", htmlEscape(values$event)),
      paste("Candidate:", htmlEscape(values$candidate)),
      paste("Attendees:", htmlEscape(toString(attendeeInfo))),
      paste("Visitors:", htmlEscape(toString(sapply(values$visitorList, as.character))))
    )
    paste(info, collapse = "\n")
  })
}

# Run the application 
shinyApp(ui = ui, server = server)