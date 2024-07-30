local logs = {}
local drives = {}
local original = {}

local accessCode = nil -- the password for the storage center
local allowed = {}

local drivesY = 0
local logsY = 0

local s,e = pcall(function () peripheral.find("modem",rednet.open) end)
if not s then
    print("connect a modem")
    return
end

local mon = peripheral.find("monitor")

-- window creation.

local w,h = term.getSize()

local bg = window.create(term.current(),1,2,w,h)
bg.setBackgroundColor(colors.white)
bg.setTextColor(colors.lightGray)
local title = window.create(term.current(),1,1,w,1)
title.setBackgroundColor(colors.gray)
title.setTextColor(colors.white)

local drivestats = window.create(term.current(),2,4,w-2,(h/2)-2)
drivestats.setBackgroundColor(colors.lightGray)
local drivetitle = window.create(term.current(),2,3,w-2,1)
drivetitle.setBackgroundColor(colors.gray)
drivetitle.setTextColor(colors.lightGray)

local logshow = window.create(term.current(),2,(h/2)+4,w-2,(h/2)-3)
logshow.setBackgroundColor(colors.lightGray)
local logtitle = window.create(term.current(),2,(h/2)+3,w-2,1)
logtitle.setBackgroundColor(colors.gray)
logtitle.setTextColor(colors.lightGray)

function table.find(list,element)
    for i,v in pairs(list) do
        if v == element then
            return i
        end
    end
    return nil
end

function log(log,color)
    table.insert(logs,{log,color})
end

function getDisks()
    drives = {}
    for i,v in pairs({peripheral.find("drive")}) do
        local path = v.getMountPath()
        if path then
            table.insert(drives,path)
        end
    end
end

function render()
    term.clear()
    bg.clear()
    title.clear()
    title.setCursorPos(1,1)
    title.write("Mass Storage System [TEST]")

    drivestats.clear()
    drivetitle.clear()
    drivetitle.setCursorPos(2,1)
    drivetitle.write("Drive Status (restart to register more)")
    
    local tfree = 0
    local tused = 0
    local overall = 0
    for i,v in ipairs(original) do
        drivestats.setCursorPos(2,i+drivesY)
        if table.find(drives,v) then
            drivestats.setTextColor(colors.green)
            local free = fs.getFreeSpace(v)
            local used = fs.getCapacity(v) - free
            tfree = tfree + free
            tused = tused + used
            drivestats.write(v.." - "..free.." free, "..used.." used.")
        else
            drivestats.setTextColor(colors.yellow)
            drivestats.write(v.." - LOST")
        end
        overall = i+1
    end
    drivestats.setCursorPos(2,overall)
    drivestats.write("OVERALL - "..tfree.." free, "..tused.." used.")

    logshow.clear()
    logtitle.clear()
    logtitle.setCursorPos(2,1)
    logtitle.write("Logs")
    
    for i,v in ipairs(logs) do
        logshow.setCursorPos(2,i+logsY)
        logshow.setTextColor(v[2])
        logshow.write(v[1])
    end
end

function renderingTask()
    while true do
        render()
        if mon then 
            term.redirect(mon)
            render()
            term.redirect(term.native())
        end
        sleep(1)
    end
end

getDisks()
original = drives

-- the main FUNCTIONS

function write(name,content)
    local size = string.len(content)
    local getPos = 1
    local wdisks = {}
    for i,v in pairs(drives) do
        local space = fs.getFreeSpace(v)
        if space ~= 0 then
            local write = string.sub(content,getPos,getPos+space-1)
            getPos = getPos + space
            local writing = fs.open(v.."/"..name,"w")
            writing.write(write)
            writing.close()
            table.insert(wdisks,v)
            if getPos > size then
                log("wrote "..name.." to "..table.concat(wdisks,", "),colors.blue)
                break
            end
        end
    end
    if #wdisks == 0 then
        log("STORAGE IS FULL, UNABLE TO WRITE "..name,colors.red)
    end
end

function read(name)
    local r = ""
    for i,v in pairs(drives) do
        local path = v.."/"..name
        if fs.exists(path) then
            local reading = fs.open(path,"r")
            r =r..reading.readAll()
            reading.close()
        end
    end
    return r
end

function rename(name,nname)
    for i,v in pairs(drives) do
        local path = v.."/"..name
        if fs.exists(path) then
            fs.move(path,v.."/"..nname)
        end
    end
end

function delete(name)
    for i,v in pairs(drives) do
        local path = v.."/"..name
        if fs.exists(path) then
            fs.delete(path)
        end
    end
end

function communicationTask()
    local id,msg = rednet.receive("MSS")
    local mode = msg[1]
    
    if mode == "login" then
        if msg[2] == accessCode then
            table.insert(allowed,id)
        end
    end

    if table.find(allowed,id) then

        if mode == "logout" then
            local pos = table.find(allowed,id)
            table.remove(allowed,pos)
        end

        if mode == "write" then
            local name = msg[2]
            local content = msg[3]
            if name and content then
                log(id.." requested to "..mode.." on "..name,colors.green)
                write(name,content)
            end
        end
    
        if mode == "read" then
            local name = msg[2]
            if name then
                log(id.." requested to "..mode.." on "..name,colors.green)
                local r = read(name)
                rednet.send(id,r,"MSS")
            end
        end
    
        if mode == "rename" then
            local name = msg[2]
            local nname = msg[3]
            if name and nname then
                log(id.." requested to "..mode.." "..name.."to "..nname,colors.yellow)
                rename(name,nname)
            end
        end
    
        if mode == "delete" then
            local name = msg[2]
            if name then
                log(id.." requested to "..mode.." "..name,colors.red)
                delete(name)
            end
        end

    end
end

function inBounds(px,py,x,y,sx,sy)
    return px >= x and px <= x+sx and py >= y and py <= y+sy
end

function interactionTask()
    while true do
        local event, dir, x, y = os.pullEvent("mouse_scroll")

        if inBounds(x,y,2,4,w-2,(h/2)-2) then
            drivesY = math.max(0,drivesY + dir)
        end

        if inBounds(x,y,w-2,(h/2)-3) then
            logsY = math.max(0,logsY + dir)
        end
    end
end

parallel.waitForAll(renderingTask,communicationTask,interactionTask)
