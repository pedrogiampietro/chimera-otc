-- Test file to determine which UI functions are available

function init()
  g_logger.info("Test module initialization...")
  
  -- Create a simple window
  testWindow = g_ui.createWidget('UIWindow', rootWidget)
  testWindow:setId('testWindow')
  testWindow:setText('Test Window')
  testWindow:setSize({width = 300, height = 200})
  testWindow:setPosition({x = 100, y = 100})
  
  -- Create a button to test methods
  local button = g_ui.createWidget('UIButton', testWindow)
  button:setId('testButton')
  button:setText('Test Button')
  button:setPosition({x = 50, y = 50})
  button:setSize({width = 100, height = 30})
  
  -- Try to set font
  g_logger.info("Testing setFont...")
  local testSetFont = pcall(function() button:setFont('verdana-11px-rounded') end)
  g_logger.info("setFont available: " .. tostring(testSetFont))
  
  -- Try to set text alignment
  g_logger.info("Testing setTextAlign...")
  local testSetTextAlign = pcall(function() button:setTextAlign(AlignCenter) end)
  g_logger.info("setTextAlign available: " .. tostring(testSetTextAlign))
  
  -- Try to set background color
  g_logger.info("Testing setBackgroundColor...")
  local testSetBgColor = pcall(function() button:setBackgroundColor('#FF5555') end)
  g_logger.info("setBackgroundColor available: " .. tostring(testSetBgColor))
  
  -- Try to set text color
  g_logger.info("Testing setTextColor...")
  local testSetTextColor = pcall(function() button:setTextColor('#FFFFFF') end)
  g_logger.info("setTextColor available: " .. tostring(testSetTextColor))
  
  -- Try to set bold
  g_logger.info("Testing setBold...")
  local testSetBold = pcall(function() button:setBold(true) end)
  g_logger.info("setBold available: " .. tostring(testSetBold))
  
  -- Try to set opacity
  g_logger.info("Testing setOpacity...")
  local testSetOpacity = pcall(function() testWindow:setOpacity(0.8) end)
  g_logger.info("setOpacity available: " .. tostring(testSetOpacity))
  
  g_logger.info("Test complete!")
end

function terminate()
  if testWindow then
    testWindow:destroy()
    testWindow = nil
  end
end 