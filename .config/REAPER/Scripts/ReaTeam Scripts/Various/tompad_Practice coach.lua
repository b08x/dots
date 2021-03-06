-- @description Practice coach
-- @author tompad
-- @version 1.0.5
-- @changelog
--   Added UpdateTimeline to make Time Signature show right bpm after session on Windows
--   Added a check for time selection
-- @about
--   # Practice Coach
--
--   Use Reaper when practicing guitar or bass or flute or bagpipe or......whatever you want to practice.    
--   This reascript will change the practice tempo in 8 steps:    
--   Step 1 plays with 50% of maxBPM in 5 min     
--   Step 2 plays with 70% of maxBPM in 2 min  
--   Step 3 plays with 60% of maxBPM in 2 min      
--   Step 4 plays with 80% of maxBPM in 2 min           
--   Step 5 plays with 65% of maxBPM in 2 min            
--   Step 6 plays with 75% of maxBPM in 2 min            
--   Step 7 plays with 80% of maxBPM in 2 min            
--   Step 8 plays with 50% of maxBPM in 3 min    
--
--   How to use:
--   - Make a time selection on what you want to practice.
--   - Load Practice Coach
--   - Hit Start button (on script window) and practice along
--   - If there is no temposign at start of time selection you will be asked if you want to create one,
--     else Practice Coach will load the tempo from sign and start to play time selection. 
--   - When first step is done Reaper stops
--   - To contine with step 2 hit Continue (if auto-continue is active - just wait)
--   - After finishing the 8th step you have practiced different tempos in 15 min and script resets.
--   - Is auto-increase selected the temposign will be increased by 1 bpm after finishing.

-- Script generated by Lokasenna's GUI Builder


local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
  reaper.MB("Couldn't load the Lokasenna_GUI library. Please run 'Set Lokasenna_GUI v2 library path.lua' in the Lokasenna_GUI folder.", "Whoops!", 0)
  return
end
loadfile(lib_path .. "Core.lua")()


GUI.req("Classes/Class - Button.lua")()
GUI.req("Classes/Class - Textbox.lua")()
GUI.req("Classes/Class - Label.lua")()
GUI.req("Classes/Class - Options.lua")()
GUI.req("Classes/Class - Menubox.lua")()
GUI.req("Classes/Class - Slider.lua")()
-- If any of the requested libraries weren't found, abort the script.
if missing_lib then return 0 end

GUI.name = "Practice Coach"
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 160, 224
GUI.anchor, GUI.corner = "screen", "C"

local xwin
local startTime, endTime, pauseTime, startTime2, endTime2
local practiceTime = {300, 120, 120, 120, 120, 120, 120, 180} -- Time for every step in seconds
--local practiceTime = {5, 2, 2, 2, 2, 2, 2, 5} -- Time for every step in seconds DEV version
local practiceTempo = {0.5, 0.7, 0.6, 0.8, 0.65, 0.75, 0.8, 0.5}
local maxBPM, maxBPMbackup
local stepsLeft = 8
local i = 1
local buttonEnabled = true
local autoContinue, autoIncrease
local autoContMB
local ok
local notFinished = false
local countdownRunning = false
local progress
local length
local ptidx
local retval1, timepos, measurepos, beatpos, bpm_from_marker, timesig_num, timesig_denom, lineartempo

-- <hide-code desc='GUI'>


GUI.New("Slider1", "Slider", {
  z = 11,
  x = 5,
  y = 1,
  w = 218,
  caption = "",
  min = 10000,
  max = 0,
  defaults = {0},
  inc = 1,
  dir = "v",
  font_a = 3,
  font_b = 4,
  col_txt = "txt",
  col_fill = "elm_fill",
  bg = "wnd_bg",
  show_handles = false,
  show_values = false,
  cap_x = 0,
  cap_y = 0
})


GUI.New("Checklist3", "Checklist", {
  z = 5,
  x = 24.0,
  y = 18.0,
  w = 144,
  h = 40,
  caption = "Settings",
  optarray = {"Auto-increase"},
  dir = "v",
  pad = 2,
  font_a = 2,
  font_b = 3,
  col_txt = "txt",
  col_fill = "elm_fill",
  bg = "wnd_bg",
  frame = false,
  shadow = true,
  swap = false,
  opt_size = 20
})


GUI.New("Checklist1", "Checklist", {
  z = 5,
  x = 24.0,
  y = 54.0,
  w = 144,
  h = 40,
  caption = "",
  optarray = {"Auto-continue"},
  dir = "v",
  pad = 2,
  font_a = 2,
  font_b = 3,
  col_txt = "txt",
  col_fill = "elm_fill",
  bg = "wnd_bg",
  frame = false,
  shadow = true,
  swap = false,
  opt_size = 20
})


GUI.New("AutoContMB", "Menubox", {
  z = 5,
  x = 16.0,
  y = 90.0,
  w = 70,
  h = 20,
  caption = "",
  optarray = {"5 sec", "10 sec", "15 sec", "20 sec", "25 sec", "30 sec"},
  retval = 1.0,
  font_a = 3,
  font_b = 4,
  col_txt = "txt",
  col_cap = "txt",
  bg = "wnd_bg",
  pad = 4,
  noarrow = false,
  align = 0
})

GUI.New("OK_btn", "Button", {
  z = 5,
  x = 48,
  y = 160,
  w = 32,
  h = 24,
  caption = "OK",
  font = 3,
  col_txt = "txt",
  col_fill = "elm_frame"
})

GUI.New("Settings_btn", "Button", {
  z = 11,
  x = 136.0,
  y = 1.0,
  w = 18,
  h = 18,
  caption = "S",
  font = 3,
  col_txt = "txt",
  col_fill = "elm_frame"
})


GUI.New("MaxBPM_Label", "Label", {
  z = 11,
  x = 64.0,
  y = 15.0,
  w = 40,
  h = 20,
  caption = "Max BPM:",
  font = 3,
  color = "txt",
  bg = "wnd_bg",
  shadow = false
})
GUI.New("MaxBPM", "Label", {
  z = 11,
  x = 64.0,
  y = 32.0,
  w = 40,
  h = 20,
  caption = "???",
  font = 3,
  color = "txt",
  bg = "wnd_bg",
  shadow = false
})

GUI.New("CurrBPM_Label", "Label", {
  z = 11,
  x = 0,
  y = 64.0,
  caption = "",
  font = 3,
  color = "txt",
  bg = "wnd_bg",
  shadow = false
})

GUI.New("Procent_Label", "Label", {
  z = 11,
  x = 0,
  y = 96.0,
  caption = " % of max BPM",
  font = 3,
  color = "txt",
  bg = "wnd_bg",
  shadow = false
})


GUI.New("Start_Cont_Button", "Button", {
  z = 11,
  x = 0.0,
  y = 128.0,
  w = 120,
  h = 30,
  caption = "START!",
  font = 2,
  col_txt = "txt",
  col_fill = "elm_frame"
})


GUI.New("StepsLeft_Label", "Label", {
  z = 11,
  x = 50.0,
  y = 176.0,
  caption = "Steps left:",
  font = 3,
  color = "txt",
  bg = "wnd_bg",
  shadow = false
})

-- </hide-code>

GUI.Val("StepsLeft_Label", "Steps left: " .. stepsLeft)
GUI.Val("CurrBPM_Label", "Current BPM:")
GUI.Val("Slider1", 10000 )

-- <hide-code desc='Store and restore'>


function writeSettings()
  autoContinue = GUI.Val("Checklist1")
  autoIncrease = GUI.Val("Checklist3")
  autoContMB = GUI.Val("AutoContMB")
  reaper.SetProjExtState(0, "practice_coach", "autoContinue", tostring(autoContinue)) -- store autoContinue
  reaper.SetProjExtState(0, "practice_coach", "autoIncrease", tostring(autoIncrease)) -- store autoIncrease
  reaper.SetProjExtState(0, "practice_coach", "AutoContMB", tostring(autoContMB)) -- store autoContMB
end

function readSettings()
  ok, autoContinue = reaper.GetProjExtState(0, "practice_coach", "autoContinue") -- restore autoContinue
  ok, autoIncrease = reaper.GetProjExtState(0, "practice_coach", "autoIncrease") -- restore autoIncrease
  ok, autoContMB = reaper.GetProjExtState(0, "practice_coach", "AutoContMB") -- restore autoContMB
  if autoContinue ~= "" then
    GUI.Val("Checklist1", toboolean(autoContinue))
    --  GUI.Val("Checklist1", (autoContinue == "true" and true or false))
  else
    autoContinue = false
    GUI.Val("Checklist1", autoContinue)
    --  GUI.Val("Checklist1", {(autoContinue == "true" and true or false)})
    writeSettings()
  end

  if autoIncrease ~= "" then
    GUI.Val("Checklist3", toboolean(autoIncrease))
    --  GUI.Val("Checklist3", (autoContinue == "true" and true or false))
  else
    autoIncrease = false
    GUI.Val("Checklist3", autoIncrease)
    --GUI.Val("Checklist3", {(autoContinue == "true" and true or false)})
    writeSettings()
  end

  if autoContMB ~= "" then
    autoContMB = GUI.Val("AutoContMB", tonumber(autoContMB))
  else
    autoContMB = 1
    autoContMB = GUI.Val("AutoContMB", tonumber(autoContMB))
    writeSettings()
  end
end

function toboolean(value)
  if type(value) == "string" then
    if value == "true" then
      return true
    else
      return false
    end
  end
end

function GUI.elms.Checklist1:onmouseup()
  GUI.Checklist.onmouseup(self)
  --autoContinue = GUI.Val("Checklist1")
  writeSettings()
end


function GUI.elms.Checklist3:onmouseup()
  GUI.Checklist.onmouseup(self)
  --  autoIncrease = GUI.Val("Checklist3")
  writeSettings()
end

function GUI.elms.AutoContMB:onwheel()
  GUI.Menubox.onwheel(self)
  autoContMB = GUI.Val("AutoContMB")
  pauseTime = autoContMB * 5
  writeSettings()
end

function GUI.elms.AutoContMB:onmouseup()
  GUI.Menubox.onmouseup(self)
  autoContMB = GUI.Val("AutoContMB")
  pauseTime = autoContMB * 5
  writeSettings()
end

-- </hide-code>

-- <hide-code desc='shift Window'>

function shiftWindow ()
  if GUI.elms.MaxBPM_Label.z == 11 then
    GUI.elms.MaxBPM.z = 5
    GUI.elms.Settings_btn.z = 5
    GUI.elms.MaxBPM_Label.z = 5
    GUI.elms.CurrBPM_Label.z = 5
    GUI.elms.Procent_Label.z = 5
    GUI.elms.Start_Cont_Button.z = 5
    GUI.elms.StepsLeft_Label.z = 5
    GUI.elms.Slider1.z = 5

    GUI.elms.Checklist1.z = 11
    GUI.elms.Checklist3.z = 11
    GUI.elms.AutoContMB.z = 11
    GUI.elms.OK_btn.z = 11

    -- Force a redraw of every layer
    GUI.redraw_z[0] = true


  else
    GUI.elms.MaxBPM.z = 11
    GUI.elms.Settings_btn.z = 11
    GUI.elms.MaxBPM_Label.z = 11
    GUI.elms.CurrBPM_Label.z = 11
    GUI.elms.Procent_Label.z = 11
    GUI.elms.Start_Cont_Button.z = 11
    GUI.elms.StepsLeft_Label.z = 11
    GUI.elms.Slider1.z = 11

    GUI.elms.Checklist1.z = 5
    GUI.elms.Checklist3.z = 5
    GUI.elms.AutoContMB.z = 5
    GUI.elms.OK_btn.z = 5

    -- Force a redraw of every layer
    GUI.redraw_z[0] = true
  end
end

-- Layer 5 will never be shown or updated
GUI.elms_hide[5] = true
-- </hide-code>

function GUI.elms.Settings_btn:onmouseup()
  GUI.Button.onmouseup(self)
  if notFinished then
    -- Do nothing
  else
    shiftWindow()
  end
end

function GUI.elms.OK_btn:onmouseup()
  GUI.Button.onmouseup(self)
  writeSettings()
  shiftWindow()
end

function round2(num, numDecimalPlaces)
  return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

function checkTimeSelection ()
  --Kollar om en timeselection ??r gjord - om inte starta en dialogruta som p??pekar att det m??ste finnas en. Return
  local starttime3, endtime3 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)

  if starttime3 == endtime3 then
    reaper.ShowMessageBox("No time selection is done - please make one!", "Info", 0)

  else
    CheckForTimSig()
  end

end

function CheckForTimSig ()
  reaper.Main_OnCommandEx( 40630, 0, 0 ) --- Go to start of time selection
  curpos = reaper.GetCursorPosition()
  for ptidx = 0, reaper.CountTempoTimeSigMarkers(0) - 1 do
    retval1, timepos, measurepos, beatpos, bpm_from_marker, timesig_num, timesig_denom, lineartempo = reaper.GetTempoTimeSigMarker(0, ptidx)
    if math.abs(timepos - curpos) < 0.0001 then
      maxBPM = bpm_from_marker
      GUI.Val("MaxBPM", maxBPM)
      maxBPMbackup = maxBPM
      break
    end
  end
  if timepos == nil then
    local svar = reaper.ShowMessageBox( "There is no tempo marker at start of time selection - do you want to create one?", "No tempo marker!", 4 )
    if svar == 6 then
      local retval2, bpm_from_input = reaper.GetUserInputs( "What tempo?", 1, "What BPM to tempo marker?", " " )
      if retval2 then
        maxBPM = bpm_from_input
        reaper.SetTempoTimeSigMarker( 0, - 1, reaper.GetCursorPosition(), - 1, - 1, bpm_from_input, 0, 0, false )
        GUI.Val("MaxBPM", maxBPM)
        maxBPMbackup = maxBPM
        startButton()
      end
      -- Do nothing
    end
  else
    if math.abs(timepos - curpos) > 0.0001 then
      local svar = reaper.ShowMessageBox( "There is no tempo marker at start of time selection - do you want to create one?", "No tempo marker!", 4 )
      if svar == 6 then
        local retval2, bpm_from_input = reaper.GetUserInputs( "What tempo?", 1, "What BPM to tempo marker?", " " )
        if retval2 then
          maxBPM = bpm_from_input
          reaper.SetTempoTimeSigMarker( 0, - 1, reaper.GetCursorPosition(), - 1, - 1, bpm_from_input, 0, 0, false )
          GUI.Val("MaxBPM", maxBPM)
          maxBPMbackup = maxBPM
          startButton()
        end
        -- Do nothing
      end
    else
      startButton()
    end
  end
  --  startButton()
end

function GUI.elms.Start_Cont_Button:onmouseup()
  GUI.Button.onmouseup(self)

  if notFinished then

    if autoContinue == false then
      if countdownRunning then
        --do nothing
      else
        buttonEnabled = true
        startButton()
      end
    end
    -- Do nothing
  else
    if buttonEnabled then
      checkTimeSelection()
      --CheckForTimSig()
    else
      --do nothing
    end
  end
end

function startButton ()

  if buttonEnabled then
    startTime = reaper.time_precise()
    endTime = startTime + practiceTime[i]
    setBPM()
    countDownTimer()
    GUI.elms.Start_Cont_Button.caption = "...."
    reaper.Main_OnCommandEx( 40630, 0, 0 )
    reaper.OnPlayButton()
    buttonEnabled = false
    i = i + 1
    stepsLeft = stepsLeft - 1
    GUI.Val("StepsLeft_Label", "Steps left: " .. stepsLeft)
  else
    --...nothing should happen - button is disabled
  end
end



function countDownTimer()
  countdownRunning = true
  if (reaper.time_precise() <= endTime) then
    reaper.defer(countDownTimer)
    notFinished = true
    progress = endTime - reaper.time_precise()
    length = endTime - startTime
    progress = math.floor(progress / length * GUI.elms.Slider1.steps)
    GUI.Val("Slider1", progress )
  else
    reaper.OnStopButton()
    GUI.Val("Slider1", 10000 )
    countdownRunning = false
    buttonEnabled = true
    if i <= 8 then
      notFinished = true
      if autoContinue then
        GUI.elms.Start_Cont_Button.caption = "Auto-Continue"
      else
        GUI.elms.Start_Cont_Button.caption = "Continue"
      end
      GUI.elms.Start_Cont_Button:redraw()
    else
      notFinished = false
      GUI.elms.Start_Cont_Button.caption = "Start"
      GUI.elms.Start_Cont_Button:redraw()
      stepsLeft = 8
      GUI.Val("StepsLeft_Label", "Steps left: " .. stepsLeft)
      reaper.Main_OnCommandEx( 40630, 0, 0 ) --- Go to start of time selection
      if autoIncrease then
        maxBPM = maxBPMbackup + 1
      else
        maxBPM = maxBPMbackup
      end
      reaper.SetTempoTimeSigMarker( 0, reaper.FindTempoTimeSigMarker( 0, reaper.GetCursorPosition() ), reaper.GetCursorPosition(), - 1, - 1, maxBPM, 0, 0, false )
      reaper.UpdateTimeline()

      GUI.Val("MaxBPM", maxBPM)
      GUI.Val("StepsLeft_Label", "Steps left: " .. stepsLeft)
      GUI.Val("CurrBPM_Label", "Current BPM:")
      i = 1
    end
    if autoContinue and notFinished then
      autoContMB = GUI.Val("AutoContMB")
      pauseTime = autoContMB * 5
      startTime2 = endTime
      endTime2 = startTime2 + pauseTime
      countDownTimer2()
    else

    end
  end
end

function countDownTimer2 ()
  if (reaper.time_precise() <= endTime2) then
    reaper.defer(countDownTimer2)
  else
    startButton()
  end
end

function setBPM ()
  reaper.SetCurrentBPM(0, (maxBPM * practiceTempo[i]), false)
  GUI.Val("CurrBPM_Label", "Current BPM:" .. (maxBPM * practiceTempo[i]))
  GUI.Val("Procent_Label", (100 * practiceTempo[i]) .. "% of max BPM")
  GUI.elms.CurrBPM_Label.x = xwin - ((gfx.measurestr(GUI.elms.CurrBPM_Label.caption)) / 2)
  GUI.elms.Procent_Label.x = xwin - ((gfx.measurestr(GUI.elms.Procent_Label.caption)) / 2)
end

------------------------------------
-------- Main functions ------------
------------------------------------
-- This will be run on every update loop of the GUI script; anything you would put
-- inside a reaper.defer() loop should go here. (The function name doesn't matter)
local function Main()

  -- Get the keyboard/window state
  local char = gfx.getchar()

  -- Reasons to end the script:
  --  Esc           Window closed
  if char == 27 or char == -1 then return end

  -- Prevent the user from resizing the window
  if GUI.resized then
    -- If the window's size has been changed, reopen it
    -- at the current position with the size we specified
    local __, x, y, w, h = gfx.dock(-1, 0, 0, 0, 0)
    gfx.quit()
    gfx.init(GUI.name, GUI.w, GUI.h, 0, x, y)
    GUI.redraw_z[0] = true
  end

end

GUI.Init()
readSettings()

-- Tell the GUI library to run Main on each update loop
-- Individual elements are updated first, then GUI.func is run, then the GUI is redrawn
GUI.func = Main
-- How often (in seconds) to run GUI.func. 0 = every loop.
GUI.freq = 0
xwin = (GUI.w / 2)
GUI.elms.MaxBPM_Label.x = xwin - ((gfx.measurestr(GUI.elms.MaxBPM_Label.caption)) / 2)
GUI.elms.CurrBPM_Label.x = xwin - ((gfx.measurestr(GUI.elms.CurrBPM_Label.caption)) / 2)
GUI.elms.Procent_Label.x = xwin - ((gfx.measurestr(GUI.elms.Procent_Label.caption)) / 2)
GUI.elms.OK_btn.x = xwin - ((GUI.elms.OK_btn.w) / 2)
GUI.elms.Start_Cont_Button.x = xwin - ((GUI.elms.Start_Cont_Button.w) / 2) + 6
GUI.elms.AutoContMB.x = xwin - ((GUI.elms.AutoContMB.w) / 2)
GUI.elms.Checklist1.x = xwin - ((GUI.elms.Checklist1.w) / 2) + 16
reaper.atexit(writeSettings)
-- Start the main loop
GUI.Main()


