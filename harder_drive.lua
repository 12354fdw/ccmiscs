local disks = {peripheral.find("drive")}
peripheral.find("modem",rednet.open)

local dirs = {}

local spaces = {}

-- init
for i,d in ipairs(disks) do
    local dir = d.getMountPath()
    if dir then
        print("AVAIL disk: "..dir)
        table.insert(dirs,dir)
    end
end

function getSize()
    for i,v in ipairs(dirs) do
        spaces[v] = fs.getFreeSpace(v)
    end
end

function write(name,content)
    getSize()
    local file_size = string.len(content)
    local wdisks = {}
    local get = 1
    for i,v in ipairs(dirs) do
        local space = spaces[v]
        if space ~= 0 then
            local used = space - file_size
            local write = string.sub(content,get,get+(math.abs(used)-1))
            get = get + space
            local writing = fs.open(v.."/"..name,"w")
            writing.write(write)
            writing.close()
            table.insert(wdisks,v)
            if get > file_size then
                break
            end
        end
        print("wrote "..name.."to "..table.concat(wdisks,", "))
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

local i = 1

while true do
    while true do
        write("TESTy"..i, "1234567890")
        local data = read("TESTy" .. i)
        print(data)
        
        i = i + 1
        sleep(1)
    end
end
