# Attendance Check-In App

This is a basic R-Shiny check-in app, customized for masonic lodges. The app records meeting attendance to a spread sheet, allowing general metrics to be analyzed. The app also prints current meeting information to the screen so data entry can be confirmed. If the wrong information is entered, simply re-enter the information.

![App](./www/app.jpg)

## Recorded Information:
- Attendees with officer designations
- Visitor list (visitors can also indicate officer designation)
- Event type (e.g. MM Degree, SM, etc.)
- Candidate name

## Features:
- Auto-completion for the drop-down menu allows for rapid name selection 
- Date/day auto-detection

## Usage:
- The "Enter" button enters the current information. Multiple fields can be entered simultanesously without issue. 
- The "Save" button appends the currently entered information to the initial spread sheet. There should be no problem clicking save multiple times as the app will simply over-write the current day's column. So, if a member arrives late, it's perfectly fine to add them and click save again.
- Alterations to the spread sheet can also be completed manually: simply open the data sheet in Excel and make any desired changes.
- To customize for new/additional members, add new rows using Excel. 

## Notes:
- To use auto-complete in the member drop-down menu, click the drop down menu, hit "delete", then start typing. 
- Data are stored as a .csv file. As such, avoid the use of commas in entry fields. The app does not currently remove them, so a comma can disrupt the data structure.
- To autom
