peripheral.find("modem",rednet.open)

local original = {}
local dirs = {}

local spaces = {}

-- init
function getDisks()
    local disks = {peripheral.find("drive")}
    for i,d in ipairs(disks) do
        local dir = d.getMountPath()
        if dir then
            print("AVAIL disk: "..dir)
            table.insert(dirs,dir)
        end
    end
end

getDisks()

function getSize()
    for i,v in ipairs(dirs) do
        spaces[v] = fs.getFreeSpace(v)
    end
end

original = dirs

function write(name,content)
    getSize()
    local file_size = string.len(content)
    local wdisks = {}
    local get = 1
    for i,v in ipairs(dirs) do
        local space = spaces[v]
        if space ~= 0 then
            local used = space - file_size
            local write = string.sub(content,get,get+space-1)
            get = get + space
            local writing = fs.open(v.."/"..name,"w")
            writing.write(write)
            writing.close()
            table.insert(wdisks,v)
            if get > file_size then
                print("wrote "..name.." to "..table.concat(wdisks,", "))
                break
            end
        end
    end
    if #wdisks == 0 then
        error("STORAGE IS FULL (create more storage)")
    end
end

function read(name)
    local r = ""
    for i,v in ipairs(dirs) do
        local dir = v.."/"..name
        if fs.exists(dir) then
            local read = fs.open(dir,"r")
            r = r..read.readAll()
            read.close()
        end
    end
    return r
end

function rename(name,newname)
    for i,v in ipairs(dirs) do
        local dir = v.."/"..name
        if fs.exists(dir) then
            fs.move(dir,v.."/"..newname)
        end
    end
end

function delete(name)
    for i,v in ipairs(dirs) do
        local dir = v.."/"..name
        if fs.exists(dir) then
            fs.delete(dir)
        end
    end
end

function healthCheck()
    while true do
        term.setTextColor(colors.green)
        print("HEALTH CHECK")
        local tfree = 0
        local tused = 0
        for i,v in pairs(dirs) do
            local free = spaces[v] or 0
            local used = fs.getSize(v) - free
            tfree = tfree + free
            tused = tused + used
            print(v.." - free: "..free..", used: "..used)
        end
        print("OVERALL - free: "..tfree..", used: "..tused)
        term.setTextColor(colors.orange)
        getDisks()
        for i,v in pairs(original) do
            local loss = true
            for i,pair in pairs(original) do
                if pair == v then
                    loss = false
                end
            end
            if loss then
                print("WARNING: LOST "..v)
            end
        end
        sleep(60)
    end
end

function main()
    while true do
        local id,msg = rednet.receive("MSS")
        term.setTextColor(colors.lightGray)
        getDisks()
        local type = msg[1]
        if type then
    
            if type == "write" then
                local name = msg[2]
                local content = msg[3]
                print(id.." requested to "..type.." on "..name)
    
                if name and content then
                    write(name,content)
                end
            end
    
            if type == "read" then
                local name = msg[2]
                print(id.." requested to "..type.." "..name)
    
                if name then
                    sleep(0.05)
                    rednet.send(id,read(name),"MSS")
                end
            end
    
            if type == "rename" then
                local name = msg[2]
                local newname = msg[3]
                print(id.." requested to "..type.." "..name.." to "..newname)
    
                if name and newname then
                    rename(name,newname)
                end
            end
    
            if type == "delete" then
                local name = msg[2]
                print(id.." requested to "..type.." on "..name)
    
                if name then
                    delete(name)
                end
            end
    
        end
    end
end

parallel.waitForAll(main,healthCheck)
