-- init.lua
-- Visual AI Screenshot Analyzer for macOS with Hammerspoon and OpenAI

-------------------------------------
-- CONFIGURATION
-------------------------------------
local config = {
    openai_api_key = "API_KEY",
    model = "gpt-4o",
    prompt = [[
        Analyze this screenshot from my Mac and:
        - Answer the question highlighted
        - If there is no question highlighted then answer the question closest to the mouse
        - limit the answer to a maximum of 30 words
    ]]
}

local json = require("hs.json")

-------------------------------------
-- HELPERS
-------------------------------------
local function shellEscape(str)
    return "'" .. tostring(str):gsub("'", "'\\''") .. "'"
end

-------------------------------------
-- CORE FUNCTIONALITY
-------------------------------------
local function analyzeScreenshot()
    local screenshot_path = os.tmpname() .. ".png"
    local json_path = os.tmpname() .. ".json"

    -- Take screenshot
    hs.execute("screencapture -x -t png " .. screenshot_path)

    -- Read and encode image as base64 (in Lua)
    local f = io.open(screenshot_path, "rb")
    local img_raw = f:read("*all")
    f:close()
    local img_data = hs.base64.encode(img_raw)

    -- Prepare JSON body for OpenAI
    local payload = {
        model = config.model,
        messages = {{
            role = "user",
            content = {
                {type = "text", text = config.prompt:gsub("\n", " ")},
                {type = "image_url", image_url = {url = "data:image/png;base64," .. img_data, detail = "auto"}}
            }
        }}
    }

    -- Write JSON payload to temp file
    local fjson = io.open(json_path, "w")
    fjson:write(json.encode(payload))
    fjson:close()

    -- Run curl with JSON file input
    local cmd = string.format([[
curl -s -X POST https://api.openai.com/v1/chat/completions \
-H "Content-Type: application/json" \
-H "Authorization: Bearer %s" \
-d @%s
    ]], config.openai_api_key, json_path)

    local response_json = hs.execute(cmd)

    -- Delete temp files
    os.remove(screenshot_path)
    os.remove(json_path)

    local ok, response = pcall(json.decode, response_json)
    local answer = response.choices[1].message.content or ""

    hs.notify.new({
        title = "Screen Analysis Result",
        informativeText = answer,
        contentImage = hs.image.imageFromPath(screenshot_path),
        withdrawAfter = 10
    }):send()

    hs.execute("say " .. shellEscape(answer))
  
end

-------------------------------------
-- GESTURE SETUP
-------------------------------------

local middleClickWatcher = hs.eventtap.new({hs.eventtap.event.types.otherMouseDown}, function(event)
    local button = event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber)
    
    if button == 2 then  -- Button 2 = middle mouse (scroll wheel click)
        analyzeScreenshot()  -- 👈 Replace with your function
    end

    return false
end)

middleClickWatcher:start()


-------------------------------------
-- HOTKEY SETUP
-------------------------------------

hs.hotkey.bind({"ctrl", "cmd"}, "G", analyzeScreenshot)
hs.alert.show("Visual AI Ready\nPress Ctrl+Cmd+G", 2)
