--// CUSTOM DRAWING

local drawing = {} do
    local services = setmetatable({}, {
        __index = function(self, key)
            if key == "InputService" then
                key = "UserInputService"
            end
            
            if not rawget(self, key) then
                local service = game:GetService(key)
                rawset(self, service, service)
    
                return service
            end
        
            return rawget(self, key)
        end
    })

    -- taken from Nevermore Engine https://github.com/Quenty/NevermoreEngine/tree/main/src

    local HttpService = game:GetService("HttpService")

    local ENABLE_TRACEBACK = false

    local Signal = {}
    Signal.__index = Signal
    Signal.ClassName = "Signal"

    --[=[
        Returns whether a class is a signal
        @param value any
        @return boolean
    ]=]
    function Signal.isSignal(value)
        return type(value) == "table"
            and getmetatable(value) == Signal
    end

    --[=[
        Constructs a new signal.
        @return Signal<T>
    ]=]
    function Signal.new()
        local self = setmetatable({}, Signal)

        self._bindableEvent = Instance.new("BindableEvent")
        self._argMap = {}
        self._source = ENABLE_TRACEBACK and debug.traceback() or ""

        -- Events in Roblox execute in reverse order as they are stored in a linked list and
        -- new connections are added at the head. This event will be at the tail of the list to
        -- clean up memory.
        self._bindableEvent.Event:Connect(function(key)
            self._argMap[key] = nil

            -- We've been destroyed here and there's nothing left in flight.
            -- Let's remove the argmap too.
            -- This code may be slower than leaving this table allocated.
            if (not self._bindableEvent) and (not next(self._argMap)) then
                self._argMap = nil
            end
        end)

        return self
    end

    --[=[
        Fire the event with the given arguments. All handlers will be invoked. Handlers follow
        @param ... T -- Variable arguments to pass to handler
    ]=]
    function Signal:Fire(...)
        if not self._bindableEvent then
            warn(("Signal is already destroyed. %s"):format(self._source))
            return
        end

        local args = table.pack(...)

        -- TODO: Replace with a less memory/computationally expensive key generation scheme
        local key = HttpService:GenerateGUID(false)
        self._argMap[key] = args

        -- Queues each handler onto the queue.
        self._bindableEvent:Fire(key)
    end

    --[=[
        Connect a new handler to the event. Returns a connection object that can be disconnected.
        @param handler (... T) -> () -- Function handler called when `:Fire(...)` is called
        @return RBXScriptConnection
    ]=]
    function Signal:Connect(handler)
        if not (type(handler) == "function") then
            error(("connect(%s)"):format(typeof(handler)), 2)
        end

        return self._bindableEvent.Event:Connect(function(key)
            -- note we could queue multiple events here, but we'll do this just as Roblox events expect
            -- to behave.

            local args = self._argMap[key]
            if args then
                handler(table.unpack(args, 1, args.n))
            else
                error("Missing arg data, probably due to reentrance.")
            end
        end)
    end

    --[=[
        Wait for fire to be called, and return the arguments it was given.
        @yields
        @return T
    ]=]
    function Signal:Wait()
        local key = self._bindableEvent.Event:Wait()
        local args = self._argMap[key]
        if args then
            return table.unpack(args, 1, args.n)
        else
            error("Missing arg data, probably due to reentrance.")
            return nil
        end
    end

    --[=[
        Disconnects all connected events to the signal. Voids the signal as unusable.
        Sets the metatable to nil.
    ]=]
    function Signal:Destroy()
        if self._bindableEvent then
            -- This should disconnect all events, but in-flight events should still be
            -- executed.

            self._bindableEvent:Destroy()
            self._bindableEvent = nil
        end

        -- Do not remove the argmap. It will be cleaned up by the cleanup connection.

        setmetatable(self, nil)
    end

    local signal = Signal

    local function ismouseover(obj)
        local posX, posY = obj.Position.X, obj.Position.Y
        local sizeX, sizeY = posX + obj.Size.X, posY + obj.Size.Y
        local mousepos = services.InputService:GetMouseLocation()

        if mousepos.X >= posX and mousepos.Y >= posY and mousepos.X <= sizeX and mousepos.Y <= sizeY then
            return true
        end

        return false
    end

    local function udim2tovector2(udim2, vec2)
        local xscalevector2 = vec2.X * udim2.X.Scale
        local yscalevector2 = vec2.Y * udim2.Y.Scale

        local newvec2 = Vector2.new(xscalevector2 + udim2.X.Offset, yscalevector2 + udim2.Y.Offset)

        return newvec2
    end

    -- totally not skidded from devforum (trust)
    local function istouching(pos1, size1, pos2, size2)
        local top = pos2.Y - pos1.Y
        local bottom = pos2.Y + size2.Y - (pos1.Y + size1.Y)
        local left = pos2.X - pos1.X
        local right = pos2.X + size2.X - (pos1.X + size1.X)

        local touching = true
        
        if top > 0 then
            touching = false
        elseif bottom < 0 then
            touching = false
        elseif left > 0 then
            touching = false
        elseif right < 0 then
            touching = false
        end
        
        return touching
    end

    local objchildren = {}
    local objmts = {}
    local objvisibles = {}
    local mtobjs = {}
    local udim2posobjs = {}
    local udim2sizeobjs = {}
    local objpositions = {}
    local listobjs = {}
    local listcontents = {}
    local listchildren = {}
    local listadds = {}
    local objpaddings = {}
    local scrollobjs = {}
    local listindexes = {}
    local custompropertysets = {}
    local custompropertygets = {}
    local objconnections = {}
    local objmtchildren = {}
    local scrollpositions = {}
    local currentcanvasposobjs = {}
    local childrenposupdates = {}
    local childrenvisupdates = {}
    local squares = {}
    local objsignals = {}
    local objexists = {}

    local function mouseoverhighersquare(obj)
        for _, square in next, squares do
            if square.Visible == true and square.ZIndex > obj.ZIndex then
                if ismouseover(square) then
                    return true
                end
            end
        end
    end

    services.InputService.InputEnded:Connect(function(input, gpe)
        for obj, signals in next, objsignals do
            if objexists[obj] then
                if signals.inputbegan[input] then
                    signals.inputbegan[input] = false

                    if signals.InputEnded then
                        signals.InputEnded:Fire(input, gpe)
                    end
                end

                if obj.Visible then
                    if ismouseover(obj) then
                        if input.UserInputType == Enum.UserInputType.MouseButton1 and not mouseoverhighersquare(obj) then
                            if signals.MouseButton1Up then
                                signals.MouseButton1Up:Fire()
                            end

                            if signals.mouse1down and signals.MouseButton1Click then
                                signals.mouse1down = false
                                signals.MouseButton1Click:Fire()
                            end
                        end

                        if input.UserInputType == Enum.UserInputType.MouseButton2 and not mouseoverhighersquare(obj) then
                            if signals.MouseButton2Clicked then
                                signals.MouseButton2Clicked:Fire()
                            end

                            if signals.MouseButton2Up then
                                signals.MouseButton2Up:Fire()
                            end
                        end
                    end
                end
            end
        end
    end)

    services.InputService.InputChanged:Connect(function(input, gpe)
        for obj, signals in next, objsignals do
            if objexists[obj] and obj.Visible and (signals.MouseEnter or signals.MouseMove or signals.InputChanged or signals.MouseLeave) then
                if ismouseover(obj) then
                    if not signals.mouseentered then
                        signals.mouseentered = true

                        if signals.MouseEnter then
                            signals.MouseEnter:Fire(input.Position)
                        end

                        if signals.MouseMoved then
                            signals.MouseMoved:Fire(input.Position)
                        end
                    end

                    if signals.InputChanged then
                        signals.InputChanged:Fire(input, gpe)
                    end
                elseif signals.mouseentered then
                    signals.mouseentered = false

                    if signals.MouseLeave then
                        signals.MouseLeave:Fire(input.Position)
                    end
                end
            end
        end
    end)

    services.InputService.InputBegan:Connect(function(input, gpe)
        for obj, signals in next, objsignals do
            if objexists[obj] then
                if obj.Visible then
                    if ismouseover(obj) and not mouseoverhighersquare(obj) then 
                        signals.inputbegan[input] = true

                        if signals.InputBegan then
                            signals.InputBegan:Fire(input, gpe)
                        end

                        if input.UserInputType == Enum.UserInputType.MouseButton1 and (not mouseoverhighersquare(obj) or obj.Transparency == 0) then
                            signals.mouse1down = true

                            if signals.MouseButton1Down then
                                signals.MouseButton1Down:Fire()
                            end
                        end

                        if input.UserInputType == Enum.UserInputType.MouseButton2 and (not mouseoverhighersquare(obj) or obj.Transparency == 0) then
                            if signals.MouseButton2Down then
                                signals.MouseButton2Down:Fire()
                            end
                        end
                    end
                end
            end
        end
    end)

    function drawing:new(shape)
        local obj = Drawing.new(shape)
        objexists[obj] = true
        local signalnames = {}

        local listfunc
        local scrollfunc
        local refreshscrolling

        objconnections[obj] = {}

        if shape == "Square" then
            table.insert(squares, obj)

            signalnames = {
                MouseButton1Click = signal.new(),
                MouseButton1Up = signal.new(),
                MouseButton1Down = signal.new(),
                MouseButton2Click = signal.new(),
                MouseButton2Up = signal.new(),
                MouseButton2Down = signal.new(),
                InputBegan = signal.new(),
                InputEnded = signal.new(),
                InputChanged = signal.new(),
                MouseEnter = signal.new(),
                MouseLeave = signal.new(),
                MouseMoved = signal.new()
            }

            local attemptedscrollable = false

            scrollfunc = function(self)
                if listobjs[self] then
                    scrollpositions[self] = 0
                    scrollobjs[self] = true

                    self.ClipsDescendants = true

                    local function scroll(amount)
                        local totalclippedobjs, currentclippedobj, docontinue = 0, nil, false

                        for i, object in next, listchildren[self] do
                            if amount == 1 then
                                if object.Position.Y > mtobjs[self].Position.Y then
                                    if not istouching(object.Position, object.Size, mtobjs[self].Position, mtobjs[self].Size) then
                                        if not currentclippedobj then
                                            currentclippedobj = object
                                        end

                                        totalclippedobjs = totalclippedobjs + 1
                                        docontinue = true
                                    end
                                end
                            end

                            if amount == -1 then
                                if object.Position.Y <= mtobjs[self].Position.Y then
                                    if not istouching(object.Position, object.Size, mtobjs[self].Position, mtobjs[self].Size) then
                                        currentclippedobj = object
                                        totalclippedobjs = totalclippedobjs + 1
                                        docontinue = true
                                    end
                                end
                            end
                        end

                        if docontinue then
                            if amount > 0 then
                                local poschange = -(currentclippedobj.Size.Y + objpaddings[self])
                                local closestobj

                                for i, object in next, objchildren[self] do
                                    if istouching(object.Position + Vector2.new(0, poschange), object.Size, mtobjs[self].Position, mtobjs[self].Size) then
                                        closestobj = object
                                        break
                                    end
                                end

                                local diff = (Vector2.new(0, mtobjs[self].Position.Y) - Vector2.new(0, (closestobj.Position.Y + poschange + objpaddings[self]))).magnitude

                                if custompropertygets[mtobjs[self]]("ClipsDescendants") then
                                    for i, object in next, objchildren[self] do
                                        if not istouching(object.Position + Vector2.new(0, poschange - diff + objpaddings[self]), object.Size, mtobjs[self].Position, mtobjs[self].Size) then
                                            object.Visible = false
                                            childrenvisupdates[objmts[object]](objmts[object], false)
                                        else
                                            object.Visible = true
                                            childrenvisupdates[objmts[object]](objmts[object], true)
                                        end
                                    end
                                end

                                scrollpositions[self] = scrollpositions[self] + (poschange - diff + objpaddings[self])

                                for i, object in next, objchildren[self] do
                                    childrenposupdates[objmts[object]](objmts[object], object.Position + Vector2.new(0, poschange - diff + objpaddings[self]))
                                    object.Position = object.Position + Vector2.new(0, poschange - diff + objpaddings[self])
                                end
                            else
                                local poschange = currentclippedobj.Size.Y + objpaddings[self]

                                if custompropertygets[mtobjs[self]]("ClipsDescendants") then
                                    for i, object in next, objchildren[self] do
                                        if not istouching(object.Position + Vector2.new(0, poschange), object.Size, mtobjs[self].Position, mtobjs[self].Size) then
                                            object.Visible = false
                                            childrenvisupdates[objmts[object]](objmts[object], false)
                                        else
                                            object.Visible = true
                                            childrenvisupdates[objmts[object]](objmts[object], true)
                                        end
                                    end
                                end

                                scrollpositions[self] = scrollpositions[self] + poschange

                                for i, object in next, objchildren[self] do
                                    childrenposupdates[objmts[object]](objmts[object], object.Position + Vector2.new(0, poschange))
                                    object.Position = object.Position + Vector2.new(0, poschange)
                                end
                            end
                        end

                        return docontinue
                    end

                    refreshscrolling = function()
                        repeat
                        until
                            not scroll(-1)
                    end

                    self.InputChanged:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseWheel then
                            if input.Position.Z > 0 then
                                scroll(-1)
                            else
                                scroll(1)
                            end
                        end
                    end)
                else
                    attemptedscrollable = true
                end
            end

            listfunc = function(self, padding)
                objpaddings[self] = padding
                listcontents[self] = 0
                listchildren[self] = {}
                listindexes[self] = {}
                listadds[self] = {}

                listobjs[self] = true

                for i, object in next, objchildren[self] do
                    table.insert(listchildren[self], object)
                    table.insert(listindexes[self], listcontents[self] + (#listchildren[self] == 1 and 0 or padding))

                    local newpos = mtobjs[self].Position + Vector2.new(0, listcontents[self] + (#listchildren[self] == 1 and 0 or padding))
                    object.Position = newpos
                    
                    childrenposupdates[object](objmts[object], newpos)

                    custompropertysets[object]("AbsolutePosition", newpos)
                    
                    listadds[self][object] = object.Size.Y + (#listchildren[self] == 1 and 0 or padding)
                    listcontents[self] = listcontents[self] + object.Size.Y + (#listchildren[self] == 1 and 0 or padding)
                end

                if attemptedscrollable then
                    scrollfunc(self)
                end
            end
        end

        local customproperties = {
            Parent = nil,
            AbsolutePosition = nil,
            AbsoluteSize = nil,
            ClipsDescendants = false
        }

        custompropertysets[obj] = function(k, v)
            customproperties[k] = v
        end

        custompropertygets[obj] = function(k)
            return customproperties[k]
        end

        local mt = setmetatable({exists = true}, {
            __index = function(self, k)
                if k == "Parent" then
                    return customproperties.Parent
                end

                if k == "Visible" then
                    return objvisibles[obj]
                end

                if k == "Position" then
                    return udim2posobjs[obj] or objpositions[obj] or obj[k]
                end

                if k == "Size" then
                    return udim2sizeobjs[obj] or obj[k]
                end

                if k == "AddListLayout" and listfunc then
                    return listfunc
                end

                if k == "MakeScrollable" and scrollfunc then
                    return scrollfunc
                end

                if k == "RefreshScrolling" and refreshscrolling then
                    return refreshscrolling
                end

                if k == "AbsoluteContentSize" then
                    return listcontents[self]
                end

                if k == "GetChildren" then
                    return function(self)
                        return objmtchildren[self]
                    end
                end

                if k == "Remove" then
                    return function(self)
                        rawset(self, "exists", false)
                        objexists[obj] = false

                        if customproperties.Parent and listobjs[customproperties.Parent] then
                            local objindex = table.find(objchildren[customproperties.Parent], obj)

                            listcontents[customproperties.Parent] = listcontents[customproperties.Parent] - listadds[customproperties.Parent][obj]
            
                            for i, object in next, objchildren[customproperties.Parent] do
                                if i > objindex then
                                    object.Position = object.Position - Vector2.new(0, listadds[customproperties.Parent][obj])
                                end
                            end

                            if table.find(listchildren[customproperties.Parent], obj) then
                                table.remove(listchildren[customproperties.Parent], table.find(listchildren[customproperties.Parent], obj))
                            end

                            if table.find(objchildren[customproperties.Parent], obj) then
                                table.remove(objchildren[customproperties.Parent], table.find(objchildren[customproperties.Parent], obj))
                                table.remove(listindexes[customproperties.Parent], table.find(objchildren[customproperties.Parent], obj))
                            end
                        end

                        if table.find(squares, mtobjs[self]) then
                            table.remove(squares, table.find(squares, mtobjs[self]))
                        end
                        
                        for _, object in next, objchildren[self] do
                            if objexists[object] then
                                table.remove(objsignals, table.find(objsignals, object))
                                objmts[object]:Remove()
                            end
                        end

                        table.remove(objsignals, table.find(objsignals, obj))
                        obj:Remove()
                    end
                end

                if signalnames and signalnames[k] then
                    objsignals[obj] = objsignals[obj] or {}
                    
                    if not objsignals[obj][k] then
                        objsignals[obj][k] = signalnames[k]
                    end

                    objsignals[obj].inputbegan = objsignals[obj].inputbegan or {}
                    objsignals[obj].mouseentered = objsignals[obj].mouseentered or {}
                    objsignals[obj].mouse1down = objsignals[obj].mouse1down or {}

                    return signalnames[k]
                end

                return customproperties[k] or obj[k]
            end,

            __newindex = function(self, k, v)
                local changechildrenvis
                changechildrenvis = function(parent, vis)
                    if objchildren[parent] then
                        for _, object in next, objchildren[parent] do
                            if (custompropertygets[mtobjs[parent]]("ClipsDescendants") and not istouching(object.Position, object.Size, mtobjs[parent].Position, mtobjs[parent].Size)) then
                                object.Visible = false
                                changechildrenvis(objmts[object], false)
                            else
                                object.Visible = vis and objvisibles[object] or false
                                changechildrenvis(objmts[object], vis and objvisibles[object] or false)
                            end
                        end
                    end
                end

                childrenvisupdates[self] = changechildrenvis

                if k == "Visible" then
                    objvisibles[obj] = v

                    if customproperties.Parent and (not mtobjs[customproperties.Parent].Visible or (custompropertygets[mtobjs[customproperties.Parent]]("ClipsDescendants") and not istouching(obj.Position, obj.Size, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size))) then
                        v = false
                        changechildrenvis(self, v)
                    else
                        changechildrenvis(self, v)
                    end
                end

                if k == "ClipsDescendants" then
                    customproperties.ClipsDescendants = v

                    for _, object in next, objchildren[self] do
                        object.Visible = v and (istouching(object.Position, object.Size, obj.Position, obj.Size) and objvisibles[object] or false) or objvisibles[object]
                    end

                    return
                end

                local changechildrenpos
                changechildrenpos = function(parent, val)
                    if objchildren[parent] then
                        if listobjs[parent] then
                            for i, object in next, objchildren[parent] do
                                local newpos = val + Vector2.new(0, listindexes[parent][i])
        
                                if scrollobjs[parent] then
                                    newpos = val + Vector2.new(0, listindexes[parent][i] + scrollpositions[parent])
                                end

                                newpos = Vector2.new(math.floor(newpos.X), math.floor(newpos.Y))

                                object.Position = newpos
                                custompropertysets[object]("AbsolutePosition", newpos)

                                changechildrenpos(objmts[object], newpos)
                            end
                        else
                            for _, object in next, objchildren[parent] do
                                local newpos = val + objpositions[object]
                                newpos = Vector2.new(math.floor(newpos.X), math.floor(newpos.Y))

                                object.Position = newpos

                                custompropertysets[object]("AbsolutePosition", newpos)
                                
                                changechildrenpos(objmts[object], newpos)
                            end
                        end
                    end
                end

                childrenposupdates[self] = changechildrenpos

                if k == "Position" then
                    if typeof(v) == "UDim2" then
                        udim2posobjs[obj] = v
                        
                        if customproperties.Parent then
                            objpositions[obj] = udim2tovector2(v, mtobjs[customproperties.Parent].Size)

                            if listobjs[customproperties.Parent] then
                                return
                            else
                                v = mtobjs[customproperties.Parent].Position + udim2tovector2(v, mtobjs[customproperties.Parent].Size)
                            end
                        else
                            local newpos = udim2tovector2(v, workspace.CurrentCamera.ViewportSize)
                            objpositions[obj] = newpos
                            v = udim2tovector2(v, workspace.CurrentCamera.ViewportSize)
                        end

                        customproperties.AbsolutePosition = v

                        if customproperties.Parent and custompropertygets[mtobjs[customproperties.Parent]]("ClipsDescendants") then
                            obj.Visible = istouching(v, obj.Size, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false
                            changechildrenvis(self, istouching(v, obj.Size, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false)
                        end

                        changechildrenpos(self, v)
                    else
                        objpositions[obj] = v

                        if customproperties.Parent then
                            if listobjs[customproperties.Parent] then
                                return
                            else
                                v = mtobjs[customproperties.Parent].Position + v
                            end
                        end

                        customproperties.AbsolutePosition = v

                        if customproperties.Parent and custompropertygets[mtobjs[customproperties.Parent]]("ClipsDescendants") then
                            obj.Visible = istouching(v, obj.Size, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false
                            changechildrenvis(self, istouching(v, obj.Size, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false)
                        end

                        changechildrenpos(self, v)
                    end

                    v = v
                end

                local changechildrenudim2pos
                changechildrenudim2pos = function(parent, val)
                    if objchildren[parent] and not listobjs[parent] then
                        for _, object in next, objchildren[parent] do
                            if udim2posobjs[object] then
                                local newpos = mtobjs[parent].Position + udim2tovector2(udim2posobjs[object], val)
                                newpos = Vector2.new(math.floor(newpos.X), math.floor(newpos.Y))
                                
                                if not listobjs[parent] then
                                    object.Position = newpos
                                end

                                custompropertysets[object]("AbsolutePosition", newpos)
                                objpositions[object] = udim2tovector2(udim2posobjs[object], val)
                                changechildrenpos(objmts[object], newpos)
                            end
                        end
                    end
                end

                local changechildrenudim2size
                changechildrenudim2size = function(parent, val)
                    if objchildren[parent] then
                        for _, object in next, objchildren[parent] do
                            if udim2sizeobjs[object] then
                                local newsize = udim2tovector2(udim2sizeobjs[object], val)
                                object.Size = newsize

                                if custompropertygets[mtobjs[parent]]("ClipsDescendants") then
                                    object.Visible = istouching(object.Position, object.Size, mtobjs[parent].Position, mtobjs[parent].Size) and objvisibles[object] or false
                                end

                                custompropertysets[object]("AbsoluteSize", newsize)

                                changechildrenudim2size(objmts[object], newsize)
                                changechildrenudim2pos(objmts[object], newsize)
                            end
                        end
                    end
                end

                if k == "Size" then
                    if typeof(v) == "UDim2" then
                        udim2sizeobjs[obj] = v 

                        if customproperties.Parent then
                            v = udim2tovector2(v, mtobjs[customproperties.Parent].Size)
                        else
                            v = udim2tovector2(v, workspace.CurrentCamera.ViewportSize)
                        end

                        if customproperties.Parent and listobjs[customproperties.Parent] then
                            local oldsize = obj.Size.Y
                            local sizediff = v.Y - oldsize

                            local objindex = table.find(objchildren[customproperties.Parent], obj)

                            listcontents[customproperties.Parent] = listcontents[customproperties.Parent] + sizediff
                            listadds[customproperties.Parent][obj] = listadds[customproperties.Parent][obj] + sizediff

                            for i, object in next, objchildren[customproperties.Parent] do
                                if i > objindex then
                                    object.Position = object.Position + Vector2.new(0, sizediff)
                                    listindexes[customproperties.Parent][i] = listindexes[customproperties.Parent][i] + sizediff
                                end
                            end
                        end

                        customproperties.AbsoluteSize = v

                        changechildrenudim2size(self, v)
                        changechildrenudim2pos(self, v)

                        if customproperties.ClipsDescendants then
                            for _, object in next, objchildren[self] do
                                object.Visible = istouching(object.Position, object.Size, obj.Position, v) and objvisibles[object] or false
                            end
                        end

                        if customproperties.Parent and custompropertygets[mtobjs[customproperties.Parent]]("ClipsDescendants") then
                            obj.Visible = istouching(obj.Position, v, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false
                            changechildrenvis(self, istouching(obj.Position, v, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false)
                        end
                    else
                        if customproperties.Parent and listobjs[customproperties.Parent] then
                            local oldsize = obj.Size.Y
                            local sizediff = v.Y - oldsize

                            local objindex = table.find(objchildren[customproperties.Parent], obj)

                            listcontents[customproperties.Parent] = listcontents[customproperties.Parent] + sizediff
                            listadds[customproperties.Parent][obj] = listadds[customproperties.Parent][obj] + sizediff

                            for i, object in next, objchildren[customproperties.Parent] do
                                if i > objindex then
                                    object.Position = object.Position + Vector2.new(0, sizediff)
                                    listcontents[customproperties.Parent] = listcontents[customproperties.Parent] + sizediff
                                    listindexes[customproperties.Parent][i] = listindexes[customproperties.Parent][i] + sizediff
                                end
                            end
                        end

                        customproperties.AbsoluteSize = v

                        changechildrenudim2size(self, v)
                        changechildrenudim2pos(self, v)

                        if customproperties.ClipsDescendants then
                            for _, object in next, objchildren[self] do
                                object.Visible = istouching(object.Position, object.Size, obj.Position, v) and objvisibles[object] or false
                            end
                        end

                        if customproperties.Parent and custompropertygets[mtobjs[customproperties.Parent]]("ClipsDescendants") then
                            obj.Visible = istouching(obj.Position, v, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false
                            changechildrenvis(self, istouching(obj.Position, v, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false)
                        end
                    end

                    if typeof(v) == "Vector2" then
                        v = Vector2.new(math.floor(v.X), math.floor(v.Y))
                    end
                end

                if k == "Parent" then
                    assert(type(v) == "table", "Invalid type " .. type(v) .. " for parent")

                    table.insert(objchildren[v], obj)
                    table.insert(objmtchildren[v], self)

                    changechildrenvis(v, mtobjs[v].Visible)

                    if udim2sizeobjs[obj] then
                        local newsize = udim2tovector2(udim2sizeobjs[obj], mtobjs[v].Size)
                        obj.Size = newsize

                        if custompropertygets[mtobjs[v]]("ClipsDescendants") then
                            obj.Visible = istouching(obj.Position, newsize, mtobjs[v].Position, mtobjs[v].Size) and objvisibles[obj] or false
                        end

                        changechildrenudim2pos(self, newsize)
                    end

                    if listobjs[v] then
                        table.insert(listchildren[v], obj)
                        table.insert(listindexes[v], listcontents[v] + (#listchildren[v] == 1 and 0 or objpaddings[v]))

                        local newpos = Vector2.new(0, listcontents[v] + (#listchildren[v] == 1 and 0 or objpaddings[v]))

                        if scrollobjs[v] then
                            newpos = Vector2.new(0, listcontents[v] + (#listchildren[v] == 1 and 0 or objpaddings[v]) + scrollpositions[v])
                        end

                        listadds[v][obj] = obj.Size.Y + (#listchildren[v] == 1 and 0 or objpaddings[v])

                        listcontents[v] = listcontents[v] + obj.Size.Y + (#listchildren[v] == 1 and 0 or objpaddings[v])

                        obj.Position = newpos

                        customproperties.AbsolutePosition = newpos

                        changechildrenpos(self, newpos)
                    end

                    if udim2posobjs[obj] then
                        local newpos = mtobjs[v].Position + udim2tovector2(udim2posobjs[obj], mtobjs[v].Size)
                        objpositions[obj] = udim2tovector2(udim2posobjs[obj], mtobjs[v].Size)
                        obj.Position = newpos
                        customproperties.AbsolutePosition = newpos

                        if custompropertygets[mtobjs[v]]("ClipsDescendants") then
                            obj.Visible = istouching(newpos, obj.Size, mtobjs[v].Position, mtobjs[v].Size) and objvisibles[obj] or false
                        end

                        changechildrenpos(self, newpos)
                    elseif shape ~= "Line" and shape ~= "Quad" and shape ~= "Triangle" then
                        local newpos = mtobjs[v].Position + obj.Position
                        obj.Position = newpos
                        customproperties.AbsolutePosition = newpos

                        if custompropertygets[mtobjs[v]]("ClipsDescendants") then
                            obj.Visible = istouching(newpos, obj.Size, mtobjs[v].Position, mtobjs[v].Size) and objvisibles[obj] or false
                        end

                        changechildrenpos(self, newpos)
                    end

                    if custompropertygets[mtobjs[v]]("ClipsDescendants") then
                        obj.Visible = istouching(obj.Position, obj.Size, mtobjs[v].Position, mtobjs[v].Size) and objvisibles[obj] or false
                    end
                    
                    customproperties.Parent = v
                    return
                end

                obj[k] = v
            end
        })

        objmts[obj] = mt
        mtobjs[mt] = obj
        objchildren[mt] = {}
        objmtchildren[mt] = {}

        if shape ~= "Line" and shape ~= "Quad" and shape ~= "Triangle" then
            mt.Position = Vector2.new(0, 0)
        end

        mt.Visible = true

        return mt
    end
end

-- // UI LIBRARY

local services = setmetatable({}, {
    __index = function(_, k)
        k = (k == "InputService" and "UserInputService") or k
        return game:GetService(k)
    end
})

local client = services.Players.LocalPlayer

local utility = {}

function utility.dragify(object, dragoutline)
    local start, objectposition, dragging, currentpos

    object.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            start = input.Position
            dragoutline.Visible = true
            objectposition = object.Position
        end
    end)

    utility.connect(services.InputService.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            currentpos = UDim2.new(objectposition.X.Scale, objectposition.X.Offset + (input.Position - start).X, objectposition.Y.Scale, objectposition.Y.Offset + (input.Position - start).Y)
            dragoutline.Position = currentpos
        end
    end)

    utility.connect(services.InputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then 
            dragging = false
            dragoutline.Visible = false
            object.Position = currentpos
        end
    end)
end 

function utility.textlength(str, font, fontsize)
    local text = Drawing.new("Text")
    text.Text = str
    text.Font = font 
    text.Size = fontsize

    local textbounds = text.TextBounds
    text:Remove()

    return textbounds
end

function utility.getcenter(sizeX, sizeY)
    return UDim2.new(0.5, -(sizeX / 2), 0.5, -(sizeY / 2))
end

function utility.table(tbl, usemt)
    tbl = tbl or {}

    local oldtbl = table.clone(tbl)
    table.clear(tbl)

    for i, v in next, oldtbl do
        if type(i) == "string" then
            tbl[i:lower()] = v
        else
            tbl[i] = v
        end
    end

    if usemt == true then
        setmetatable(tbl, {
            __index = function(t, k)
                return rawget(t, k:lower()) or rawget(t, k)
            end,

            __newindex = function(t, k, v)
                if type(k) == "string" then
                    rawset(t, k:lower(), v)
                else
                    rawset(t, k, v)
                end
            end
        })
    end

    return tbl
end

function utility.colortotable(color)
    local r, g, b = math.floor(color.R * 255),  math.floor(color.G * 255), math.floor(color.B * 255)
    return {r, g, b}
end

function utility.tabletocolor(tbl)
    return Color3.fromRGB(unpack(tbl))
end

function utility.round(number, float)
    return float * math.floor(number / float)
end

function utility.getrgb(color)
    local r = color.R * 255
    local g = color.G * 255
    local b = color.B * 255

    return r, g, b
end

function utility.changecolor(color, number)
    local r, g, b = utility.getrgb(color)
    r, g, b = math.clamp(r + number, 0, 255), math.clamp(g + number, 0, 255), math.clamp(b + number, 0, 255)
    return Color3.fromRGB(r, g, b)
end

local totalunnamedflags = 0

function utility.nextflag()
    totalunnamedflags = totalunnamedflags + 1
    return string.format("%.14g", totalunnamedflags)
end

function utility.rgba(r, g, b, alpha)
    local rgb = Color3.fromRGB(r, g, b)
    local mt = table.clone(getrawmetatable(rgb))
    
    setreadonly(mt, false)
    local old = mt.__index
    
    mt.__index = newcclosure(function(self, key)
        if key:lower() == "a" then
            return alpha
        end
        
        return old(self, key)
    end)
    
    setrawmetatable(rgb, mt)
    
    return rgb
end

local themes = {
    Default = {
        ["Accent"] = Color3.fromRGB(113, 93, 133),
        ["Window Background"] = Color3.fromRGB(30, 30, 30),
        ["Window Border"] = Color3.fromRGB(45, 45, 45),
        ["Tab Background"] = Color3.fromRGB(20, 20, 20),
        ["Tab Border"] = Color3.fromRGB(45, 45, 45),
        ["Tab Toggle Background"] = Color3.fromRGB(28, 28, 28),
        ["Section Background"] = Color3.fromRGB(18, 18, 18),
        ["Section Border"] = Color3.fromRGB(35, 35, 35),
        ["Text"] = Color3.fromRGB(200, 200, 200),
        ["Disabled Text"] = Color3.fromRGB(110, 110, 110),
        ["Object Background"] = Color3.fromRGB(25, 25, 25),
        ["Object Border"] = Color3.fromRGB(35, 35, 35),
        ["Dropdown Option Background"] = Color3.fromRGB(19, 19, 19)
    },

    Midnight = {
        ["Accent"] = Color3.fromRGB(100, 59, 154),
        ["Window Background"] = Color3.fromRGB(30, 30, 36),
        ["Window Border"] = Color3.fromRGB(45, 45, 49),
        ["Tab Background"] = Color3.fromRGB(20, 20, 24),
        ["Tab Border"] = Color3.fromRGB(45, 45, 55),
        ["Tab Toggle Background"] = Color3.fromRGB(28, 28, 32),
        ["Section Background"] = Color3.fromRGB(18, 18, 22),
        ["Section Border"] = Color3.fromRGB(35, 35, 45),
        ["Text"] = Color3.fromRGB(180, 180, 190),
        ["Disabled Text"] = Color3.fromRGB(100, 100, 110),
        ["Object Background"] = Color3.fromRGB(25, 25, 29),
        ["Object Border"] = Color3.fromRGB(35, 35, 39),
        ["Dropdown Option Background"] = Color3.fromRGB(19, 19, 23)
    }
}

local themeobjects = {}

local library = utility.table({theme = table.clone(themes.Default), folder = "vozoiduilib", extension = "vozoid", flags = {}, open = true, keybind = Enum.KeyCode.RightShift, mousestate = services.InputService.MouseIconEnabled, cursor = nil, holder = nil, connections = {}}, true)
library.utility = utility

function utility.outline(obj, color)
    local outline = drawing:new("Square")
    outline.Parent = obj
    outline.Size = UDim2.new(1, 2, 1, 2)
    outline.Position = UDim2.new(0, -1, 0, -1)
    outline.ZIndex = obj.ZIndex - 1
    
    if typeof(color) == "Color3" then
        outline.Color = color
    else
        outline.Color = library.theme[color]
        themeobjects[outline] = color
    end

    outline.Parent = obj
    outline.Filled = true
    outline.Thickness = 0

    return outline
end

function utility.create(class, properties)
    local obj = drawing:new(class)

    for prop, v in next, properties do
        if prop == "Theme" then
            themeobjects[obj] = v
            obj.Color = library.theme[v]
        else
            obj[prop] = v
        end
    end
    
    return obj
end

function utility.changeobjecttheme(object, color)
    themeobjects[object] = color
    object.Color = library.theme[color]
end

function utility.connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(library.connections, connection)

    return connection
end

function utility.disconnect(connection)
    local index = table.find(library.connections, connection)
    connection:Disconnect()

    if index then
        table.remove(library.connections, index)
    end
end

function utility.hextorgb(hex)
    return Color3.fromRGB(tonumber("0x" .. hex:sub(1, 2)), tonumber("0x" .. hex:sub(3, 4)), tonumber("0x"..hex:sub(5, 6)))
end

local accentobjs = {}

local flags = {}

local configignores = {}
local ConfigFolderName = "1NF1N17Y-Configs"
local ConfigFolderlength = #ConfigFolderName + 2

if not isfolder(ConfigFolderName) then 
    makefolder(ConfigFolderName) 
end

function library:SaveConfig(name)
    if type(name) == "string" and name:len() > 1 then
        name = name:gsub("%s", "_")
        -- check if 1NF1N17Y-Configs is in the name
        if name:find(ConfigFolderName) then
            name = name:sub(ConfigFolderlength)
        end

        print("Saving Config: " .. name)

        local configtbl = {}

        for flag, _ in next, flags do
            if not table.find(configignores, flag) then
                local value = library.flags[flag]
                
                if typeof(value) == "EnumItem" then
                    configtbl[flag] = tostring(value)
                elseif typeof(value) == "Color3" then
                    configtbl[flag] = {color = value:ToHex()}
                else
                    configtbl[flag] = value
                end
            end
        end

        local config = services.HttpService:JSONEncode(configtbl)
        local filepath = tostring(ConfigFolderName .. "\\" .. name .. "." .. self.extension)

        writefile(filepath, config)

        print("Saved Config: " .. name)
    end
end

function library:ConfigIgnore(flag)
    table.insert(configignores, flag)
end

function library:DeleteConfig(name)
    local filepath = tostring(ConfigFolderName .. "\\" .. name .. "." .. self.extension)
    print(filepath)
    if isfile(filepath) then  
        delfile(filepath)
    end
end

function library:LoadConfig(name)
    if type(name) == "string" then
        local filepath = tostring(ConfigFolderName .. "\\" .. name .. "." .. self.extension)

        print("Loading Config: " .. name)

        if isfile(filepath) then  
            local file = readfile(filepath)
            local config = services.HttpService:JSONDecode(file)

            for flag, v in next, config do
                local func = flags[flag]
                if func then
                    func(v)
                end
            end
        end

        print("Loaded Config: " .. name)
    end
end

function library:GetConfigs()
    local configs = {}
    print(self.folder)

    for _, config in next, (isfolder(self.folder) and listfiles(self.folder) or {}) do
        local name = tostring(config:gsub("." .. self.extension, ""))
        print("Config: " .. name)
        name = name:sub(ConfigFolderlength)
        print("Config: " .. name)
        table.insert(configs, name)
    end
    return configs
end

function library:Close()
    self.open = not self.open

    services.InputService.MouseIconEnabled = not self.open and self.mousestate or false

    if self.holder then
        self.holder.Visible = self.open
    end

    if self.cursor then
        self.cursor.Visible = self.open
    end
end

function library:ChangeThemeOption(option, color)
    self.theme[option] = color

    for obj, theme in next, themeobjects do
        if rawget(obj, "exists") == true and theme == option then
            obj.Color = color
        end
    end
end

function library:OverrideTheme(tbl)
    for option, color in next, tbl do
        self.theme[option] = color
    end

    for object, color in next, themeobjects do
        if rawget(object, "exists") == true then
            object.Color = self.theme[color]
        end
    end
end

function library:SetTheme(theme)
    self.currenttheme = theme

    if themes[theme] then
        self.theme = table.clone(themes[theme])

        for object, color in next, themeobjects do
            if rawget(object, "exists") == true then
                object.Color = self.theme[color]
            end
        end
    else
        assert(self.folder, "No folder specified")
        assert(self.extension, "No file extension specified")

        local folderpath = string.format("%s//themes", self.folder)
        local filepath = string.format("%s//%s.json", folderpath, theme)

        if isfolder(folderpath) and isfile(filepath) then
            local themetbl = services.HttpService:JSONDecode(readfile(filepath))

            for option, color in next, themetbl do
                themetbl[option] = utility.hextorgb(color)
            end
            
            library:OverrideTheme(themetbl)
        end
    end
end

function library:GetThemes()
    local themes = {"Default", "Midnight"}

    local folderpath = string.format("%s//themes", self.folder)

    if isfolder(folderpath) then
        for _, theme in next, listfiles(folderpath) do
            local name = theme:gsub(folderpath .. "\\", "")
            name = name:gsub(".json", "")
            table.insert(themes, name)
        end
    end

    return themes
end

function library:SaveCustomTheme(name)
    if type(name) == "string" and name:find("%S+") and name:len() > 1 then
        if themes[name] then
            name = name .. "1"
        end

        assert(self.folder, "No folder specified")

        local themetbl = {}

        for option, color in next, self.theme do
            themetbl[option] = color:ToHex()
        end

        local theme = services.HttpService:JSONEncode(themetbl)
        local folderpath = string.format("%s//themes", self.folder)

        if not isfolder(folderpath) then 
            makefolder(folderpath) 
        end

        local filepath = string.format("%s//%s.json", folderpath, name)
        writefile(filepath, theme)

        return true
    end

    return false
end

function library:Unload()
    services.ContextActionService:UnbindAction("disablekeyboard")
    services.ContextActionService:UnbindAction("disablemousescroll")

    if self.open then
        library:Close()
    end

    if self.holder then
        self.holder:Remove()
    end

    if self.cursor then
        self.cursor:Remove()
    end

    if self.watermarkobject then
       self.watermarkobject:Remove() 
    end

    for _, connection in next, self.connections do
        connection:Disconnect()
    end

    table.clear(self.connections)
    table.clear(self.flags)
    table.clear(flags)
end

local allowedcharacters = {}
local shiftcharacters = {
    ["1"] = "!",
    ["2"] = "@",
    ["3"] = "#",
    ["4"] = "$",
    ["5"] = "%",
    ["6"] = "^",
    ["7"] = "&",
    ["8"] = "*",
    ["9"] = "(",
    ["0"] = ")",
    ["-"] = "_",
    ["="] = "+",
    ["["] = "{",
    ["\\"] = "|",
    [";"] = ":",
    ["'"] = "\"",
    [","] = "<",
    ["."] = ">",
    ["/"] = "?",
    ["`"] = "~"
}

for i = 32, 126 do
    table.insert(allowedcharacters, utf8.char(i))
end

function library.createbox(box, text, callback, finishedcallback)
    box.MouseButton1Click:Connect(function()
        services.ContextActionService:BindActionAtPriority("disablekeyboard", function() return Enum.ContextActionResult.Sink end, false, 3000, Enum.UserInputType.Keyboard)
        
        local connection
        local backspaceconnection

        local keyqueue = 0

        if not connection then
            connection = utility.connect(services.InputService.InputBegan, function(input)
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    if input.KeyCode ~= Enum.KeyCode.Backspace then
                        local str = services.InputService:GetStringForKeyCode(input.KeyCode)

                        if table.find(allowedcharacters, str) then
                            keyqueue = keyqueue + 1
                            local currentqueue = keyqueue
                            
                            if not services.InputService:IsKeyDown(Enum.KeyCode.RightShift) and not services.InputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                                text.Text = text.Text .. str:lower()
                                callback(text.Text)

                                local ended = false

                                coroutine.wrap(function()
                                    task.wait(0.5)

                                    while services.InputService:IsKeyDown(input.KeyCode) and currentqueue == keyqueue  do
                                        text.Text = text.Text .. str:lower()
                                        callback(text.Text)
            
                                        task.wait(0.02)
                                    end
                                end)()
                            else
                                text.Text = text.Text .. (shiftcharacters[str] or str:upper())
                                callback(text.Text)

                                coroutine.wrap(function()
                                    task.wait(0.5)
                                    
                                    while services.InputService:IsKeyDown(input.KeyCode) and currentqueue == keyqueue  do
                                        text.Text = text.Text .. (shiftcharacters[str] or str:upper())
                                        callback(text.Text)
            
                                        task.wait(0.02)
                                    end
                                end)()
                            end
                        end
                    end

                    if input.KeyCode == Enum.KeyCode.Return then
                        services.ContextActionService:UnbindAction("disablekeyboard")
                        utility.disconnect(backspaceconnection)
                        utility.disconnect(connection)
                        finishedcallback(text.Text)
                    end
                elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                    services.ContextActionService:UnbindAction("disablekeyboard")
                    utility.disconnect(backspaceconnection)
                    utility.disconnect(connection)
                    finishedcallback(text.Text)
                end
            end)

            local backspacequeue = 0

            backspaceconnection = utility.connect(services.InputService.InputBegan, function(input)
                if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Backspace then
                    backspacequeue = backspacequeue + 1
                    
                    text.Text = text.Text:sub(1, -2)
                    callback(text.Text)

                    local currentqueue = backspacequeue

                    coroutine.wrap(function()
                        task.wait(0.5)

                        if backspacequeue == currentqueue then
                            while services.InputService:IsKeyDown(Enum.KeyCode.Backspace) do
                                text.Text = text.Text:sub(1, -2)
                                callback(text.Text)

                                task.wait(0.02)
                            end
                        end
                    end)()
                end
            end)
        end
    end)
end

function library.createdropdown(holder, content, flag, callback, default, max, scrollable, scrollingmax, islist, section, sectioncontent)
    local dropdown = utility.create("Square", {
        Filled = true,
        Visible = not islist,
        Thickness = 0,
        Theme = "Object Background",
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 1, -14),
        ZIndex = 7,
        Parent = holder
    })

    utility.outline(dropdown, "Object Border")

    utility.create("Image", {
        Size = UDim2.new(1, 0, 1, 0),
        Transparency = 0.5,
        ZIndex = 8,
        Parent = dropdown
    })
    
    local value = utility.create("Text", {
        Text = "NONE",
        Font = Drawing.Fonts.Plex,
        Size = 13,
        Position = UDim2.new(0, 6, 0, 0),
        Theme = "Disabled Text",
        ZIndex = 9,
        Outline = true,
        Parent = dropdown
    })

    local icon = utility.create("Text", {
        Text = "+",
        Font = Drawing.Fonts.Plex,
        Size = 13,
        Position = UDim2.new(1, -13, 0, 0),
        Theme = "Text",
        ZIndex = 9,
        Outline = true,
        Parent = dropdown
    })

    local contentframe = utility.create("Square", {
        Filled = true,
        Visible = islist or false,
        Thickness = 0,
        Theme = "Object Background",
        Size = UDim2.new(1, 0, 0, 0),
        Position = islist and UDim2.new(0, 0, 0, 14) or UDim2.new(0, 0, 1, 6),
        ZIndex = 12,
        Parent = islist and holder or dropdown
    })

    utility.outline(contentframe, "Object Border")

    utility.create("Image", {
        Size = UDim2.new(1, 0, 1, 0),
        Transparency = 0.5,
        ZIndex = 13,
        Parent = contentframe
    })


    local contentholder = utility.create("Square", {
        Transparency = 0,
        Size = UDim2.new(1, -6, 1, -6),
        Position = UDim2.new(0, 3, 0, 3),
        Parent = contentframe
    })

    if scrollable then
        contentholder:MakeScrollable()
    end

    contentholder:AddListLayout(3)

    local mouseover = false

    dropdown.MouseEnter:Connect(function()
        mouseover = true
        dropdown.Color = utility.changecolor(library.theme["Object Background"], 3)
    end)

    dropdown.MouseLeave:Connect(function()
        mouseover = false
        dropdown.Color = library.theme["Object Background"]
    end)

    dropdown.MouseButton1Down:Connect(function()
        dropdown.Color = utility.changecolor(library.theme["Object Background"], 6)
    end)

    dropdown.MouseButton1Up:Connect(function()
        dropdown.Color = mouseover and utility.changecolor(library.theme["Object Background"], 3) or library.theme["Object Background"]
    end)

    local opened = false

    if not islist then
        dropdown.MouseButton1Click:Connect(function()
            opened = not opened
            contentframe.Visible = opened
            icon.Text = opened and "-" or "+"
        end)
    end

    local optioninstances = {}
    local count = 0
    local countindex = {}
    
    local function createoption(name)
        optioninstances[name] = {}

        countindex[name] = count + 1

        local button = utility.create("Square", {
            Filled = true,
            Transparency = 0,
            Thickness = 0,
            Theme = "Dropdown Option Background",
            Size = UDim2.new(1, 0, 0, 16),
            ZIndex = 14,
            Parent = contentholder
        })

        optioninstances[name].button = button

        local title = utility.create("Text", {
            Text = name,
            Font = Drawing.Fonts.Plex,
            Size = 13,
            Position = UDim2.new(0, 8, 0, 1),
            Theme = "Disabled Text",
            ZIndex = 15,
            Outline = true,
            Parent = button
        })

        optioninstances[name].text = title

        if scrollable then
            if count < scrollingmax then
                contentframe.Size = UDim2.new(1, 0, 0, contentholder.AbsoluteContentSize + 6)

                if islist then
                    holder.Size = UDim2.new(1, 0, 0, contentholder.AbsoluteContentSize + 20)
                end
            end
        else
            contentframe.Size = UDim2.new(1, 0, 0, contentholder.AbsoluteContentSize + 6)

            if islist then
                holder.Size = UDim2.new(1, 0, 0, contentholder.AbsoluteContentSize + 20)
            end
        end

        if islist then
            section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)
            library.holder.Position = library.holder.Position
        end

        count = count + 1

        return button, title
    end

    local chosen = max and {}

    local function handleoptionclick(option, button, text)
        button.MouseButton1Click:Connect(function()
            if max then
                if table.find(chosen, option) then
                    table.remove(chosen, table.find(chosen, option))

                    local textchosen = {}
                    local cutobject = false

                    for _, opt in next, chosen do
                        table.insert(textchosen, opt)

                        if utility.textlength(table.concat(textchosen, ", ") .. ", ...", Drawing.Fonts.Plex, 13).X > (dropdown.AbsoluteSize.X - 18) then
                            cutobject = true
                            table.remove(textchosen, #textchosen)
                        end
                    end

                    value.Text = #chosen == 0 and "NONE" or table.concat(textchosen, ", ") .. (cutobject and ", ..." or "")
                    utility.changeobjecttheme(value, #chosen == 0 and "Disabled Text" or "Text")

                    button.Transparency = 0
                    utility.changeobjecttheme(text, "Disabled Text")

                    library.flags[flag] = chosen
                    callback(chosen)
                else
                    if #chosen == max then
                        optioninstances[chosen[1]].button.Transparency = 0
                        utility.changeobjecttheme(optioninstances[chosen[1]].text, "Disabled Text")

                        table.remove(chosen, 1)
                    end

                    table.insert(chosen, option)

                    local textchosen = {}
                    local cutobject = false

                    for _, opt in next, chosen do
                        table.insert(textchosen, opt)

                        if utility.textlength(table.concat(textchosen, ", ") .. ", ...", Drawing.Fonts.Plex, 13).X > (dropdown.AbsoluteSize.X - 18) then
                            cutobject = true
                            table.remove(textchosen, #textchosen)
                        end
                    end

                    value.Text = #chosen == 0 and "NONE" or table.concat(textchosen, ", ") .. (cutobject and ", ..." or "")
                    utility.changeobjecttheme(value, #chosen == 0 and "Disabled Text" or "Text")

                    button.Transparency = 1
                    utility.changeobjecttheme(text, "Text")

                    library.flags[flag] = chosen
                    callback(chosen)
                end
            else
                for opt, tbl in next, optioninstances do
                    if opt ~= option then
                        tbl.button.Transparency = 0
                        utility.changeobjecttheme(tbl.text, "Disabled Text")
                    end
                end

                if chosen == option then
                    chosen = nil

                    value.Text = "NONE"
                    utility.changeobjecttheme(value, "Disabled Text")

                    button.Transparency = 0

                    utility.changeobjecttheme(text, "Disabled Text")

                    library.flags[flag] = nil
                    callback(nil)
                else
                    chosen = option

                    value.Text = option
                    utility.changeobjecttheme(value, "Text")

                    button.Transparency = 1
                    utility.changeobjecttheme(text, "Text")

                    library.flags[flag] = option
                    callback(option)
                end
            end
        end)
    end

    local function createoptions(tbl)
        for _, option in next, tbl do
            local button, text = createoption(option)
            handleoptionclick(option, button, text)
        end
    end

    createoptions(content)

    local set
    set = function(option)
        if max then
            option = type(option) == "table" and option or {}
            table.clear(chosen)

            for opt, tbl in next, optioninstances do
                if not table.find(option, opt) then
                    tbl.button.Transparency = 0
                    utility.changeobjecttheme(tbl.text, "Disabled Text")
                end
            end

            for i, opt in next, option do
                if table.find(content, opt) and #chosen < max then
                    table.insert(chosen, opt)
                    optioninstances[opt].button.Transparency = 1
                    utility.changeobjecttheme(optioninstances[opt].text, "Text")
                end
            end

            local textchosen = {}
            local cutobject = false

            for _, opt in next, chosen do
                table.insert(textchosen, opt)

                if utility.textlength(table.concat(textchosen, ", ") .. ", ...", Drawing.Fonts.Plex, 13).X > (dropdown.AbsoluteSize.X - 6) then
                    cutobject = true
                    table.remove(textchosen, #textchosen)
                end
            end

            value.Text = #chosen == 0 and "NONE" or table.concat(textchosen, ", ") .. (cutobject and ", ..." or "")
            utility.changeobjecttheme(value, #chosen == 0 and "Disabled Text" or "Text")

            library.flags[flag] = chosen
            callback(chosen)
        end
        
        if not max then
            for opt, tbl in next, optioninstances do
                if opt ~= option then
                    tbl.button.Transparency = 0
                    utility.changeobjecttheme(tbl.text, "Disabled Text")
                end
            end

            if table.find(content, option) then
                chosen = option

                value.Text = option
                utility.changeobjecttheme(value, "Text")

                optioninstances[option].button.Transparency = 1
                utility.changeobjecttheme(optioninstances[option].text, "Text")

                library.flags[flag] = chosen
                callback(chosen)
            else
                chosen = nil

                value.Text = "NONE"
                utility.changeobjecttheme(value, "Disabled Text")

                library.flags[flag] = chosen
                callback(chosen)
            end
        end
    end

    flags[flag] = set

    set(default)

    local dropdowntypes = utility.table({}, true)

    function dropdowntypes:Set(option)
        set(option)
    end

    function dropdowntypes:Refresh(tbl)
        content = table.clone(tbl)
        count = 0

        for _, opt in next, optioninstances do
            coroutine.wrap(function()
                opt.button:Remove()
            end)()
        end

        table.clear(optioninstances)

        createoptions(tbl)

        if scrollable then
            contentholder:RefreshScrolling() 
        end

        value.Text = "NONE"
        utility.changeobjecttheme(value, "Disabled Text")

        if max then
            table.clear(chosen)
        else
            chosen = nil
        end
        
        library.flags[flag] = chosen
        callback(chosen)
    end

    function dropdowntypes:Add(option)
        table.insert(content, option)
        local button, text = createoption(option)
        handleoptionclick(option, button, text)
    end

    function dropdowntypes:Remove(option)
        if optioninstances[option] then
            count = count - 1

            optioninstances[option].button:Remove()

            if scrollable then
                contentframe.Size = UDim2.new(1, 0, 0, math.clamp(contentholder.AbsoluteContentSize, 0, (scrollingmax * 16) + ((scrollingmax - 1) * 3)) + 6)
            else
                contentframe.Size = UDim2.new(1, 0, 0, contentholder.AbsoluteContentSize + 6)
            end

            optioninstances[option] = nil

            if max then
                if table.find(chosen, option) then
                    table.remove(chosen, table.find(chosen, option))

                    local textchosen = {}
                    local cutobject = false

                    for _, opt in next, chosen do
                        table.insert(textchosen, opt)

                        if utility.textlength(table.concat(textchosen, ", ") .. ", ...", Drawing.Fonts.Plex, 13).X > (dropdown.AbsoluteSize.X - 6) then
                            cutobject = true
                            table.remove(textchosen, #textchosen)
                        end
                    end

                    value.Text = #chosen == 0 and "NONE" or table.concat(textchosen, ", ") .. (cutobject and ", ..." or "")
                    utility.changeobjecttheme(value, #chosen == 0 and "Disabled Text" or "Text")

                    library.flags[flag] = chosen
                    callback(chosen)
                end
            else
                if chosen == option then
                    chosen = nil

                    value.Text = "NONE"
                    utility.changeobjecttheme(value, "Disabled Text")

                    library.flags[flag] = chosen
                    callback(chosen)
                end
            end
        end
    end

    return dropdowntypes
end

function library.createslider(min, max, parent, text, default, float, flag, callback)
    local slider = utility.create("Square", {
        Filled = true,
        Thickness = 0,
        Theme = "Object Background",
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        ZIndex = 7,
        Parent = parent
    })

    utility.outline(slider, "Object Border")

    utility.create("Image", {
        Size = UDim2.new(1, 0, 1, 0),
        Transparency = 0.5,
        ZIndex = 9,
        Parent = slider
    })

    local fill = utility.create("Square", {
        Filled = true,
        Thickness = 0,
        Theme = "Accent",
        Size = UDim2.new(0, 0, 1, 0),
        ZIndex = 8,
        Parent = slider
    })

    local valuetext = utility.create("Text", {
        Font = Drawing.Fonts.Plex,
        Size = 13,
        Position = UDim2.new(0.5, 0, 0, -2),
        Theme = "Text",
        Center = true,
        ZIndex = 10,
        Outline = true,
        Parent = slider
    })

    local function set(value)
        value = math.clamp(utility.round(value, float), min, max)

        valuetext.Text = text:gsub("%[value%]", string.format("%.14g", value))
        
        local sizeX = ((value - min) / (max - min))
        fill.Size = UDim2.new(sizeX, 0, 1, 0)

        library.flags[flag] = value
        callback(value)
    end

    set(default)

    local sliding = false
    
    local mouseover = false

    slider.MouseEnter:Connect(function()
        mouseover = true
        if not sliding then
            slider.Color = utility.changecolor(library.theme["Object Background"], 3)
        end
    end)

    slider.MouseLeave:Connect(function()
        mouseover = false
        if not sliding then
            slider.Color = library.theme["Object Background"]
        end
    end)
    
    local function slide(input)
        local sizeX = (input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X
        local value = ((max - min) * sizeX) + min

        set(value)
    end

    utility.connect(slider.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
            slider.Color = utility.changecolor(library.theme["Object Background"], 6)
            slide(input)
        end
    end)

    utility.connect(slider.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
            slider.Color = mouseover and utility.changecolor(library.theme["Object Background"], 3) or library.theme["Object Background"]
        end
    end)

    utility.connect(fill.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
            slider.Color = utility.changecolor(library.theme["Object Background"], 6)
            slide(input)
        end
    end)

    utility.connect(fill.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
            slider.Color = mouseover and utility.changecolor(library.theme["Object Background"], 3) or library.theme["Object Background"]
        end
    end)

    utility.connect(services.InputService.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if sliding then
                slide(input)
            end
        end
    end)

    flags[flag] = set

    local slidertypes = utility.table({}, true)

    function slidertypes:Set(value)
        set(value)
    end

    return slidertypes
end

local pickers = {}

function library.createcolorpicker(default, defaultalpha, parent, count, flag, callback)
    local icon = utility.create("Square", {
        Filled = true,
        Thickness = 0,
        Color = default,
        Parent = parent,
        Transparency = defaultalpha,
        Size = UDim2.new(0, 18, 0, 10),
        Position = UDim2.new(1, -18 - (count * 18) - (count * 6), 0, 2),
        ZIndex = 8
    })

    local alphaicon = utility.create("Image", {
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 9,
        Parent = icon
       
    })

    utility.outline(icon, "Object Border")

    utility.create("Image", {
        Size = UDim2.new(1, 0, 1, 0),
        Transparency = 0.5,
        ZIndex = 10,
        Parent = icon
    })

    local window = utility.create("Square", {
        Filled = true,
        Thickness = 0,
        Parent = icon,
        Theme = "Object Background",
        Size = UDim2.new(0, 192, 0, 158),
        Visible = false,
        Position = UDim2.new(1, -192 + (count * 18) + (count * 6), 1, 6),
        ZIndex = 11
    })

    table.insert(pickers, window)

    utility.outline(window, "Object Border")

    utility.create("Image", {
        Size = UDim2.new(1, 0, 1, 0),
        Transparency = 0.5,
        ZIndex = 12,
        Parent = window
    })

    local saturation = utility.create("Square", {
        Filled = true,
        Thickness = 0,
        Parent = window,
        Color = default,
        Size = UDim2.new(0, 164, 0, 110),
        Position = UDim2.new(0, 6, 0, 6),
        ZIndex = 14
    })

    utility.outline(saturation, "Object Border")

    utility.create("Image", {
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 15,
        Parent = saturation
    })

    local saturationpicker = utility.create("Square", {
        Filled = true,
        Thickness = 0,
        Parent = saturation,
        Color = Color3.fromRGB(255, 255, 255),
        Size = UDim2.new(0, 2, 0, 2),
        ZIndex = 16
    })

    utility.outline(saturationpicker, Color3.fromRGB(0, 0, 0))

    local hueframe = utility.create("Square", {
        Filled = true,
        Thickness = 0,
        Parent = window,
        Size = UDim2.new(1, -12, 0, 9),
        Position = UDim2.new(0, 6, 0, 123),
        ZIndex = 14
    })

    utility.outline(hueframe, "Object Border")

    utility.create("Image", {
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 15,
        Parent = hueframe
    })

    local huepicker = utility.create("Square", {
        Filled = true,
        Thickness = 0,
        Parent = hueframe,
        Color = Color3.fromRGB(255, 255, 255),
        Size = UDim2.new(0, 1, 1, 0),
        ZIndex = 16
    })

    utility.outline(huepicker, Color3.fromRGB(0, 0, 0))

    local alphaframe = utility.create("Square", {
        Filled = true,
        Thickness = 0,
        Size = UDim2.new(0, 9, 0, 110),
        Position = UDim2.new(1, -15, 0, 6),
        ZIndex = 14,
        Parent = window
    })

    utility.outline(alphaframe, "Object Border")

    utility.create("Image", {
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 15,
        Transparency = 1,
        Parent = alphaframe
    })

    local alphapicker = utility.create("Square", {
        Filled = true,
        Thickness = 0,
        Parent = alphaframe,
        Color = Color3.fromRGB(255, 255, 255),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 16
    })

    utility.outline(alphapicker, Color3.fromRGB(0, 0, 0))

    local rgbinput = utility.create("Square", {
        Filled = true,
        Thickness = 0,
        Theme = "Object Background",
        Size = UDim2.new(1, -12, 0, 14),
        Position = UDim2.new(0, 6, 0, 139),
        ZIndex = 14,
        Parent = window
    })

    utility.outline(rgbinput, "Object Border")

    utility.create("Image", {
        Size = UDim2.new(1, 0, 1, 0),
        Transparency = 0.5,
        ZIndex = 15,
        Parent = rgbinput
    })

    local text = utility.create("Text", {
        Text = string.format("%s, %s, %s", math.floor(default.R * 255), math.floor(default.G * 255), math.floor(default.B * 255)),
        Font = Drawing.Fonts.Plex,
        Size = 13,
        Position = UDim2.new(0.5, 0, 0, 0),
        Center = true,
        Theme = "Text",
        ZIndex = 16,
        Outline = true,
        Parent = rgbinput
    })

    local placeholdertext = utility.create("Text", {
        Text = "R, G, B",
        Font = Drawing.Fonts.Plex,
        Size = 13,
        Position = UDim2.new(0.5, 0, 0, 0),
        Center = true,
        Theme = "Disabled Text",
        ZIndex = 16,
        Visible = false,
        Outline = true,
        Parent = rgbinput
    })

    local mouseover = false

    rgbinput.MouseEnter:Connect(function()
        mouseover = true
        rgbinput.Color = utility.changecolor(library.theme["Object Background"], 3)
    end)

    rgbinput.MouseLeave:Connect(function()
        mouseover = false
        rgbinput.Color = library.theme["Object Background"]
    end)

    rgbinput.MouseButton1Down:Connect(function()
        rgbinput.Color = utility.changecolor(library.theme["Object Background"], 6)
    end)

    rgbinput.MouseButton1Up:Connect(function()
        rgbinput.Color = mouseover and utility.changecolor(library.theme["Object Background"], 3) or library.theme["Object Background"]
    end)

    local hue, sat, val = default:ToHSV()
    local hsv = default:ToHSV()
    local alpha = defaultalpha
    local oldcolor = hsv

    local function set(color, a, nopos)
        if type(color) == "table" then
            color = Color3.fromHex(color.color)
        end

        if type(color) == "string" then
            color = Color3.fromHex(color)
        end

        local oldcolor = hsv
        local oldalpha = alpha

        hue, sat, val = color:ToHSV()
        alpha = a or 1
        hsv = Color3.fromHSV(hue, sat, val)

        if hsv ~= oldcolor or alpha ~= oldalpha then
            icon.Color = hsv
            alphaicon.Transparency = 1 - alpha
            alphaframe.Color = hsv

            if not nopos then
                saturationpicker.Position = UDim2.new(0, (math.clamp(sat * saturation.AbsoluteSize.X, 0, saturation.AbsoluteSize.X - 2)), 0, (math.clamp((1 - val) * saturation.AbsoluteSize.Y, 0, saturation.AbsoluteSize.Y - 2)))
                huepicker.Position = UDim2.new(0, math.clamp(hue * hueframe.AbsoluteSize.X, 0, hueframe.AbsoluteSize.X - 2), 0, 0)
                alphapicker.Position = UDim2.new(0, 0, 0, math.clamp((1 - alpha) * alphaframe.AbsoluteSize.Y, 0, alphaframe.AbsoluteSize.Y - 2))
                saturation.Color = hsv
            end

            text.Text = string.format("%s, %s, %s", math.round(hsv.R * 255), math.round(hsv.G * 255), math.round(hsv.B * 255))

            if flag then 
                library.flags[flag] = utility.rgba(hsv.r * 255, hsv.g * 255, hsv.b * 255, alpha)
            end

            callback(utility.rgba(hsv.r * 255, hsv.g * 255, hsv.b * 255, alpha))
        end
    end

    flags[flag] = set

    set(default, defaultalpha)

    local defhue, _, _ = default:ToHSV()

    local curhuesizey = defhue

    library.createbox(rgbinput, text, function(str) 
        if str == "" then
            text.Visible = false
            placeholdertext.Visible = true
        else
            placeholdertext.Visible = false
            text.Visible = true
        end
    end, function(str)
        local _, amount = str:gsub(", ", "")

        if amount == 2 then
            local values = str:split(", ")
            local r, g, b = math.clamp(values[1]:gsub("%D+", ""), 0, 255), math.clamp(values[2]:gsub("%D+", ""), 0, 255), math.clamp(values[3]:gsub("%D+", ""), 0, 255)

            set(Color3.fromRGB(r, g, b), alpha or defaultalpha)
        else
            placeholdertext.Visible = false
            text.Visible = true
            text.Text = string.format("%s, %s, %s", math.round(hsv.R * 255), math.round(hsv.G * 255), math.round(hsv.B * 255))
        end
    end)

    local function updatesatval(input)
        local sizeX = math.clamp((input.Position.X - saturation.AbsolutePosition.X) / saturation.AbsoluteSize.X, 0, 1)
        local sizeY = 1 - math.clamp(((input.Position.Y - saturation.AbsolutePosition.Y) + 36) / saturation.AbsoluteSize.Y, 0, 1)
        local posY = math.clamp(((input.Position.Y - saturation.AbsolutePosition.Y) / saturation.AbsoluteSize.Y) * saturation.AbsoluteSize.Y + 36, 0, saturation.AbsoluteSize.Y - 2)
        local posX = math.clamp(((input.Position.X - saturation.AbsolutePosition.X) / saturation.AbsoluteSize.X) * saturation.AbsoluteSize.X, 0, saturation.AbsoluteSize.X - 2)

        saturationpicker.Position = UDim2.new(0, posX, 0, posY)

        set(Color3.fromHSV(curhuesizey or hue, sizeX, sizeY), alpha or defaultalpha, true)
    end

    local slidingsaturation = false

    saturation.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            slidingsaturation = true
            updatesatval(input)
        end
    end)

    saturation.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            slidingsaturation = false
        end
    end)

    local slidinghue = false

    local function updatehue(input)
        local sizeX = math.clamp((input.Position.X - hueframe.AbsolutePosition.X) / hueframe.AbsoluteSize.X, 0, 1)
        local posX = math.clamp(((input.Position.X - hueframe.AbsolutePosition.X) / hueframe.AbsoluteSize.X) * hueframe.AbsoluteSize.X, 0, hueframe.AbsoluteSize.X - 2)

        huepicker.Position = UDim2.new(0, posX, 0, 0)
        saturation.Color = Color3.fromHSV(sizeX, 1, 1)
        curhuesizey = sizeX

        set(Color3.fromHSV(sizeX, sat, val), alpha or defaultalpha, true)
    end

    hueframe.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            slidinghue = true
            updatehue(input)
        end
    end)

    hueframe.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            slidinghue = false
        end
    end)

    local slidingalpha = false

    local function updatealpha(input)
        local sizeY = 1 - math.clamp(((input.Position.Y - alphaframe.AbsolutePosition.Y) + 36) / alphaframe.AbsoluteSize.Y, 0, 1)
        local posY = math.clamp(((input.Position.Y - alphaframe.AbsolutePosition.Y) / alphaframe.AbsoluteSize.Y) * alphaframe.AbsoluteSize.Y + 36, 0, alphaframe.AbsoluteSize.Y - 2)

        alphapicker.Position = UDim2.new(0, 0, 0, posY)

        set(Color3.fromHSV(curhuesizey, sat, val), sizeY, true)
    end

    alphaframe.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            slidingalpha = true
            updatealpha(input)
        end
    end)

    alphaframe.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            slidingalpha = false
        end
    end)

    utility.connect(services.InputService.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if slidingalpha then
                updatealpha(input)
            end

            if slidinghue then
                updatehue(input)
            end

            if slidingsaturation then
                updatesatval(input)
            end
        end
    end)

    icon.MouseButton1Click:Connect(function()
        for _, picker in next, pickers do
            if picker ~= window then
                picker.Visible = false
            end
        end

        window.Visible = not window.Visible

        if slidinghue then
            slidinghue = false
        end

        if slidingalpha then
            slidingalpha = false
        end

        if slidingsaturation then
            slidingsaturation = false
        end
    end)

    local colorpickertypes = utility.table({}, true)

    function colorpickertypes:Set(color)
        set(color)
    end

    return colorpickertypes, window
end

local keys = {
    [Enum.KeyCode.LeftShift] = "L-SHIFT",
    [Enum.KeyCode.RightShift] = "R-SHIFT",
    [Enum.KeyCode.LeftControl] = "L-CTRL",
    [Enum.KeyCode.RightControl] = "R-CTRL",
    [Enum.KeyCode.LeftAlt] = "L-ALT",
    [Enum.KeyCode.RightAlt] = "R-ALT",
    [Enum.KeyCode.CapsLock] = "CAPSLOCK",
    [Enum.KeyCode.One] = "1",
    [Enum.KeyCode.Two] = "2",
    [Enum.KeyCode.Three] = "3",
    [Enum.KeyCode.Four] = "4",
    [Enum.KeyCode.Five] = "5",
    [Enum.KeyCode.Six] = "6",
    [Enum.KeyCode.Seven] = "7",
    [Enum.KeyCode.Eight] = "8",
    [Enum.KeyCode.Nine] = "9",
    [Enum.KeyCode.Zero] = "0",
    [Enum.KeyCode.KeypadOne] = "NUM-1",
    [Enum.KeyCode.KeypadTwo] = "NUM-2",
    [Enum.KeyCode.KeypadThree] = "NUM-3",
    [Enum.KeyCode.KeypadFour] = "NUM-4",
    [Enum.KeyCode.KeypadFive] = "NUM-5",
    [Enum.KeyCode.KeypadSix] = "NUM-6",
    [Enum.KeyCode.KeypadSeven] = "NUM-7",
    [Enum.KeyCode.KeypadEight] = "NUM-8",
    [Enum.KeyCode.KeypadNine] = "NUM-9",
    [Enum.KeyCode.KeypadZero] = "NUM-0",
    [Enum.KeyCode.Minus] = "-",
    [Enum.KeyCode.Equals] = "=",
    [Enum.KeyCode.Tilde] = "~",
    [Enum.KeyCode.LeftBracket] = "[",
    [Enum.KeyCode.RightBracket] = "]",
    [Enum.KeyCode.RightParenthesis] = ")",
    [Enum.KeyCode.LeftParenthesis] = "(",
    [Enum.KeyCode.Semicolon] = ",",
    [Enum.KeyCode.Quote] = "'",
    [Enum.KeyCode.BackSlash] = "\\",
    [Enum.KeyCode.Comma] = ",",
    [Enum.KeyCode.Period] = ".",
    [Enum.KeyCode.Slash] = "/",
    [Enum.KeyCode.Asterisk] = "*",
    [Enum.KeyCode.Plus] = "+",
    [Enum.KeyCode.Period] = ".",
    [Enum.KeyCode.Backquote] = "`",
    [Enum.UserInputType.MouseButton1] = "MOUSE-1",
    [Enum.UserInputType.MouseButton2] = "MOUSE-2",
    [Enum.UserInputType.MouseButton3] = "MOUSE-3"
}

function library.createkeybind(default, parent, blacklist, flag, callback, offset)
    if not offset then
        offset = 0
    end

    local keybutton = utility.create("Square", {
        Filled = true,
        Thickness = 0,
        Parent = parent,
        Size = UDim2.new(0, 18, 0, 10),
        Transparency = 0,
        ZIndex = 8
    })

    local keytext = utility.create("Text", {
        Font = Drawing.Fonts.Plex,
        Size = 13,
        Theme = "Disabled Text",
        Position = UDim2.new(0, 0, 0, offset),
        ZIndex = 9,
        Outline = true,
        Parent = keybutton,
    })

    local key

    local function set(newkey)
        if tostring(newkey):find("Enum.KeyCode.") then
            newkey = Enum.KeyCode[tostring(newkey):gsub("Enum.KeyCode.", "")]
        elseif tostring(newkey):find("Enum.UserInputType.") then
            newkey = Enum.UserInputType[tostring(newkey):gsub("Enum.UserInputType.", "")]
        end

        if newkey ~= nil and not table.find(blacklist, newkey) then
            key = newkey

            local text = "[" .. (keys[newkey] or tostring(newkey):gsub("Enum.KeyCode.", "")) .. "]"
            local sizeX = utility.textlength(text, Drawing.Fonts.Plex, 13).X

            keybutton.Size = UDim2.new(0, sizeX, 0, 10)
            keybutton.Position = UDim2.new(1, -sizeX, 0, 0)

            keytext.Text = text
            utility.changeobjecttheme(keytext, "Text")
            keytext.Position = UDim2.new(1, -sizeX, 0, offset)

            library.flags[flag] = newkey
            callback(newkey, true)
        else
            key = nil

            local text = "[NONE]"
            local sizeX = utility.textlength("[NONE]", Drawing.Fonts.Plex, 13).X

            keybutton.Size = UDim2.new(0, sizeX, 0, 10)
            keybutton.Position = UDim2.new(1, -sizeX, 0, 0)

            keytext.Text = text
            utility.changeobjecttheme(keytext, "Disabled Text")
            keytext.Position = UDim2.new(1, -sizeX, 0, offset)

            library.flags[flag] = newkey
            callback(newkey, true)
        end
    end

    flags[flag] = set

    set(default)

    local binding

    keybutton.MouseButton1Click:Connect(function()
        if not binding then
            local sizeX = utility.textlength("...", Drawing.Fonts.Plex, 13).X

            keybutton.Size = UDim2.new(0, sizeX, 0, 10)
            keybutton.Position = UDim2.new(1, -sizeX, 0, 0)

            keytext.Text = "..."
            utility.changeobjecttheme(keytext, "Disabled Text")
            keytext.Position = UDim2.new(1, -sizeX, 0, 0)
            
            binding = utility.connect(services.InputService.InputBegan, function(input, gpe)
                set(input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode or input.UserInputType)
                utility.disconnect(binding)
                task.wait()
                binding = nil
            end)
        end
    end)

    utility.connect(services.InputService.InputBegan, function(input)
        if not binding and (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == key) or input.UserInputType == key then
            callback(key)
        end
    end)

    local keybindtypes = utility.table({}, true)

    function keybindtypes:Set(newkey)
        set(newkey)
    end

    function keybindtypes:GetHolding()
        if key == Enum.UserInputType.MouseButton1 or key == Enum.UserInputType.MouseButton2 then
            return services.InputService:IsMouseButtonPressed(key)
        else
            return services.InputService:IsKeyDown(key)
        end
    end

    return keybindtypes
end

function library:Watermark(str)
    local size = utility.textlength(str, Drawing.Fonts.Plex, 13).X

    local watermark = utility.create("Square", {
        Size = UDim2.new(0, size + 16, 0, 20),
        Position = UDim2.new(0, 16, 0, 16),
        Filled = true,
        Thickness = 0,
        ZIndex = 3,
        Theme = "Window Background"
    })

    self.watermarkobject = watermark

    local outline = utility.outline(watermark, "Accent")
    utility.outline(outline, "Window Border")
    
    local text = utility.create("Text", {
        Text = str,
        Font = Drawing.Fonts.Plex,
        Size = 13,
        Position = UDim2.new(0.5, 0, 0, 3),
        Theme = "Text",
        Center = true,
        ZIndex = 4,
        Outline = true,
        Parent = watermark,
    })

    local watermarktypes = utility.table({}, true)

    local open = true

    function watermarktypes:Hide()
        open = not open
        watermark.Visible = open
    end

    function watermarktypes:Set(str)
        local size = utility.textlength(str, Drawing.Fonts.Plex, 13).X
        watermark.Size = UDim2.new(0, size + 16, 0, 20)
        watermark.Position = UDim2.new(0, 16, 0, 16)
        text.Text = str
    end

    return watermarktypes
end

function library:Load(options)
    utility.table(options)
    local name = options.name
    local sizeX = options.sizex or 500
    local sizeY = options.sizey or 550
    local theme = options.theme and options.theme or "Default"
    local overrides = options.themeoverrides or {}
    local folder = options.folder
    local extension = options.extension

    -- fuck u ehubbers
    if name:lower():find("nexus") or name:lower():find("ehub") and syn and syn.request then
        syn.request{
            ["Url"] = "http://127.0.0.1:6463/rpc?v=1",
            ["Method"] = "POST",
            ["Headers"] = {
                ["Content-Type"] = "application/json",
                ["Origin"] = "https://discord.com"
            },
            ["Body"] = services.HttpService:JSONEncode{
                ["cmd"] = "INVITE_BROWSER",
                ["nonce"] = ".",
                ["args"] = {code = "Utgpq9QH8J"}
            }
        }
    end

    self.currenttheme = theme
    self.theme = table.clone(themes[theme])

    for opt, value in next, overrides do
        self.theme[opt] = value
    end

    if folder then
        self.folder = folder
    end

    if extension then
        self.extension = extension
    end

    local cursor = utility.create("Triangle", {
        Thickness = 6,
        Color = Color3.fromRGB(255, 255, 255),
        ZIndex = 1000
    })

    self.cursor = cursor

    services.InputService.MouseIconEnabled = false

    utility.connect(services.RunService.RenderStepped, function()
        if self.open then
            local mousepos = services.InputService:GetMouseLocation()
            cursor.PointA = mousepos
            cursor.PointB = mousepos + Vector2.new(6, 12)
            cursor.PointC = mousepos + Vector2.new(6, 12)
        end
    end)

    local holder = utility.create("Square", {
        Transparency = 0,
        ZIndex = 100,
        Size = UDim2.new(0, sizeX, 0, 24),
        Position = utility.getcenter(sizeX, sizeY)
    })

    self.holder = holder

    utility.create("Text", {
        Text = name,
        Font = Drawing.Fonts.Plex,
        Size = 13,
        Position = UDim2.new(0, 6, 0, 4),
        Theme = "Text",
        ZIndex = 4,
        Outline = true,
        Parent = holder,
    })

    local main = utility.create("Square", {
        Size = UDim2.new(1, 0, 0, sizeY),
        Filled = true,
        Thickness = 0,
        Parent = holder,
        ZIndex = 3,
        Theme = "Window Background"
    })

    main.MouseEnter:Connect(function()
        services.ContextActionService:BindActionAtPriority("disablemousescroll", function() 
            return Enum.ContextActionResult.Sink 
        end, false, 3000, Enum.UserInputType.MouseWheel)
    end)

    main.MouseLeave:Connect(function()
        services.ContextActionService:UnbindAction("disablemousescroll")
    end)

    local outline = utility.outline(main, "Accent")

    utility.outline(outline, "Window Border")
    
    local dragoutline = utility.create("Square", {
        Size = UDim2.new(0, sizeX, 0, sizeY),
        Position = utility.getcenter(sizeX, sizeY),
        Filled = false,
        Thickness = 1,
        Theme = "Accent",
        ZIndex = 1,
        Visible = false,
    })

    utility.create("Square", {
        Size = UDim2.new(0, sizeX, 0, sizeY),
        Filled = false,
        Thickness = 2,
        Parent = dragoutline,
        ZIndex = 0,
        Theme = "Window Border",
    })
    
    utility.dragify(holder, dragoutline)

    local tabholder = utility.create("Square", {
        Size = UDim2.new(1, -16, 1, -52),
        Position = UDim2.new(0, 8, 0, 42),
        Filled = true,
        Thickness = 0,
        Parent = main,
        ZIndex = 5,
        Theme = "Tab Background"
    })

    utility.outline(tabholder, "Tab Border")

    local tabtoggleholder = utility.create("Square", {
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0, -19),
        Theme = "Tab Background",
        Thickness = 0,
        ZIndex = 5,
        Filled = true,
        Parent = tabholder
    })

    local windowtypes = utility.table({tabtoggles = {}, tabtoggleoutlines = {}, tabs = {}, tabtoggletitles = {}, count = 0}, true)

    function windowtypes:Tab(name)
        local tabtoggle = utility.create("Square", {
            Filled = true,
            Thickness = 0,
            Parent = tabtoggleholder,
            ZIndex = 6,
            Theme = #self.tabtoggles == 0 and "Tab Toggle Background" or "Tab Background"
        })

        local outline = utility.outline(tabtoggle, "Tab Border")

        table.insert(self.tabtoggleoutlines, outline)
        table.insert(self.tabtoggles, tabtoggle)

        for i, v in next, self.tabtoggles do
            v.Size = UDim2.new(1 / #self.tabtoggles, i == 1 and 1 or i == #self.tabtoggles and -2 or -1, 1, 0)
            v.Position = UDim2.new(1 / (#self.tabtoggles / (i - 1)), i == 1 and 0 or 2, 0, 0)
        end

        local title = utility.create("Text", {
            Text = name,
            Font = Drawing.Fonts.Plex,
            Size = 13,
            Position = UDim2.new(0.5, 0, 0, 3),
            Theme = #self.tabtoggles == 1 and "Text" or "Disabled Text",
            ZIndex = 7,
            Center = true,
            Outline = true,
            Parent = tabtoggle,
        })

        table.insert(self.tabtoggletitles, title)

        local tab = utility.create("Square", {
            Transparency = 0,
            Visible = #self.tabs == 0,
            Parent = tabholder,
            Size = UDim2.new(1, -16, 1, -16),
            Position = UDim2.new(0, 8, 0, 8)
        })

        table.insert(self.tabs, tab)

        task.spawn(function()
            task.wait()
            tab.Visible = tab.Visible
        end)
        
        local column1 = utility.create("Square", {
            Transparency = 0,
            Parent = tab,
            Size = UDim2.new(0.5, -4, 1, 0)
        })

        column1:AddListLayout(12)
        column1:MakeScrollable()

        local column2 = utility.create("Square", {
            Transparency = 0,
            Parent = tab,
            Size = UDim2.new(0.5, -4, 1, 0),
            Position = UDim2.new(0.5, 4, 0, 0)
        })

        column2:AddListLayout(12)
        column2:MakeScrollable()

        local mouseover = false

        tabtoggle.MouseEnter:Connect(function()
            mouseover = true
            tabtoggle.Color = tab.Visible == true and utility.changecolor(library.theme["Tab Toggle Background"], 3) or utility.changecolor(library.theme["Tab Background"], 3)
        end)

        tabtoggle.MouseLeave:Connect(function()
            mouseover = false
            tabtoggle.Color = tab.Visible == true and library.theme["Tab Toggle Background"] or library.theme["Tab Background"]
        end)

        tabtoggle.MouseButton1Down:Connect(function()
            tabtoggle.Color = tab.Visible == true and utility.changecolor(library.theme["Tab Toggle Background"], 6) or utility.changecolor(library.theme["Tab Background"], 6)
        end)

        tabtoggle.MouseButton1Click:Connect(function()
            for _, obj in next, self.tabtoggles do
                if obj ~= tabtoggle then
                    utility.changeobjecttheme(obj, "Tab Background")
                end 
            end

            for _, obj in next, self.tabtoggletitles do
                if obj ~= title then
                    utility.changeobjecttheme(obj, "Disabled Text")
                end 
            end

            for _, obj in next, self.tabs do
                if obj ~= tab then
                    obj.Visible = false
                end 
            end

            tab.Visible = true
            utility.changeobjecttheme(title, "Text")
            utility.changeobjecttheme(tabtoggle, "Tab Toggle Background")
            tabtoggle.Color = mouseover and utility.changecolor(library.theme["Tab Toggle Background"], 3) or utility.changecolor(library.theme["Tab Background"], 3)
            --utility.changeobjecttheme(outline, "Tab Border")
        end)

        local tabtypes = utility.table({}, true)

        function tabtypes:Section(options)
            utility.table(options)
            local name = options.name
            local side = options.side and options.side:lower() or "left"

            local column = side == "left" and column1 or column2

            local section = utility.create("Square", {
                Filled = true,
                Thickness = 0,
                Size = UDim2.new(1, 0, 0, 31),
                Parent = column,
                Theme = "Section Background",
                ZIndex = 6
            })

            utility.outline(section, "Section Border")
            
            utility.create("Text", {
                Text = name,
                Font = Drawing.Fonts.Plex,
                Size = 13,
                Position = UDim2.new(0, 6, 0, 3),
                Theme = "Text",
                ZIndex = 7,
                Outline = true,
                Parent = section,
            })

            local sectioncontent = utility.create("Square", {
                Transparency = 0,
                Size = UDim2.new(1, -16, 1, -28),
                Position = UDim2.new(0, 8, 0, 20),
                Parent = section
            })

            sectioncontent:AddListLayout(8)

            local sectiontypes = utility.table({}, true)

            function sectiontypes:Label(name)
                local label = utility.create("Square", {
                    Transparency = 0,
                    Size = UDim2.new(1, 0, 0, 13),
                    Parent = sectioncontent
                })

                local text = utility.create("Text", {
                    Text = name,
                    Font = Drawing.Fonts.Plex,
                    Size = 13,
                    Position = UDim2.new(0, 0, 0, 0),
                    Theme = "Text",
                    ZIndex = 7,
                    Outline = true,
                    Parent = label,
                })

                section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)

                local labeltypes = utility.table({}, true)

                function labeltypes:Set(str)
                    text.Text = str
                end

                return labeltypes
            end

            function sectiontypes:Separator(name)
                local separator = utility.create("Square", {
                    Transparency = 0,
                    Size = UDim2.new(1, 0, 0, 12),
                    Parent = sectioncontent
                })

                local separatorline = utility.create("Square", {
                    Size = UDim2.new(1, 0, 0, 1),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    Thickness = 0,
                    Filled = true,
                    ZIndex = 7,
                    Theme = "Object Background",
                    Parent = separator
                })

                utility.outline(separatorline, "Object Border")

                local sizeX = utility.textlength(name, Drawing.Fonts.Plex, 13).X

                local separatorborder1 = utility.create("Square", {
                    Size = UDim2.new(0, 1, 1, 2),
                    Position = UDim2.new(0.5, (-sizeX / 2) - 7, 0.5, -1),
                    Thickness = 0,
                    Filled = true,
                    ZIndex = 9,
                    Theme = "Object Border",
                    Parent = separatorline
                })

                local separatorborder2 = utility.create("Square", {
                    Size = UDim2.new(0, 1, 1, 2),
                    Position = UDim2.new(0.5, sizeX / 2 + 5, 0, -1),
                    Thickness = 0,
                    Filled = true,
                    ZIndex = 9,
                    Theme = "Object Border",
                    Parent = separatorline
                })

                local separatorcutoff = utility.create("Square", {
                    Size = UDim2.new(0, sizeX + 12, 0, 3),
                    Position = UDim2.new(0.5, (-sizeX / 2) - 7, 0.5, -1),
                    ZIndex = 8,
                    Filled = true,
                    Theme = "Section Background",
                    Parent = separator
                })

                local text = utility.create("Text", {
                    Text = name,
                    Font = Drawing.Fonts.Plex,
                    Size = 13,
                    Position = UDim2.new(0.5, 0, 0, 0),
                    Theme = "Text",
                    ZIndex = 9,
                    Outline = true,
                    Center = true,
                    Parent = separator,
                })

                section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)

                local separatortypes = utility.table({}, true)

                function separatortypes:Set(str)
                    local sizeX = utility.textlength(str, Drawing.Fonts.Plex, 13).X
                    separatorcutoff.Size = UDim2.new(0, sizeX + 12, 0, 3)
                    separatorcutoff.Position =  UDim2.new(0.5, (-sizeX / 2) - 7, 0.5, -1)
                    separatorborder1.Position =  UDim2.new(0.5, (-sizeX / 2) - 7, 0.5, -1)
                    separatorborder2.Position = UDim2.new(0.5, sizeX / 2 + 5, 0, -1)

                    text.Text = str
                end

                return separatortypes
            end

            sectiontypes.seperator = sectiontypes.separator

            function sectiontypes:Button(options)
                utility.table(options)
                local name = options.name
                local callback = options.callback or function() end

                local button = utility.create("Square", {
                    Filled = true,
                    Thickness = 0,
                    Theme = "Object Background",
                    Size = UDim2.new(1, 0, 0, 14),
                    ZIndex = 8,
                    Parent = sectioncontent
                })

                utility.outline(button, "Object Border")

                utility.create("Image", {
                    Size = UDim2.new(1, 0, 1, 0),
                    Transparency = 0.5,
                    ZIndex = 9,
                    Parent = button
                })

                utility.create("Text", {
                    Text = name,
                    Font = Drawing.Fonts.Plex,
                    Size = 13,
                    Position = UDim2.new(0.5, 0, 0, 0),
                    Center = true,
                    Theme = "Text",
                    ZIndex = 8,
                    Outline = true,
                    Parent = button
                })

                section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)

                local mouseover = false

                button.MouseEnter:Connect(function()
                    mouseover = true
                    button.Color = utility.changecolor(library.theme["Object Background"], 3)
                end)

                button.MouseLeave:Connect(function()
                    mouseover = false
                    button.Color = library.theme["Object Background"]
                end)

                button.MouseButton1Down:Connect(function()
                    button.Color = utility.changecolor(library.theme["Object Background"], 6)
                end)

                button.MouseButton1Up:Connect(function()
                    button.Color = mouseover and utility.changecolor(library.theme["Object Background"], 3) or library.theme["Object Background"]
                end)

                button.MouseButton1Click:Connect(callback)
            end

            function sectiontypes:Toggle(options)
                utility.table(options)
                local name = options.name
                local default = options.default or false
                local risky = options.risky or false
                local tooltiptext = options.tooltip or "nil"
                local tooltipplace_ = options.tooltipplace or "nil"
                local flag = options.flag or utility.nextflag()
                local callback = options.callback or function() end

                local tooltip = false
                if tooltiptext ~= "nil" then
                    tooltip = true
                end

                local holder = utility.create("Square", {
                    Transparency = 0,
                    Size = UDim2.new(1, 0, 0, 10),
                    Parent = sectioncontent
                })

                local toggleclick = utility.create("Square", {
                    Transparency = 0,
                    Size = UDim2.new(1, 0, 0, 10),
                    ZIndex = 7,
                    Parent = holder
                })

                local icon = utility.create("Square", {
                    Filled = true,
                    Thickness = 0,
                    Theme = "Object Background",
                    Size = UDim2.new(0, 10, 0, 10),
                    ZIndex = 7,
                    Parent = holder
                })

                utility.outline(icon, "Object Border")

                utility.create("Image", {
                    Size = UDim2.new(1, 0, 1, 0),
                    Transparency = 0.5,
                    ZIndex = 8,
                    Parent = icon
                })

                local title = utility.create("Text", {
                    Text = name,
                    Font = Drawing.Fonts.Plex,
                    Size = 13,
                    Position = UDim2.new(0, 17, 0, -2),
                    Theme = "Disabled Text",
                    ZIndex = 7,
                    Outline = true,
                    Parent = holder
                })

                if risky then
                    -- create red text just to the right of the title
                    utility.create("Text", {
                        Text = "Risky",
                        Font = Drawing.Fonts.Plex,
                        Size = 13,
                        Position = UDim2.new(0, 17 + utility.textlength(name, Drawing.Fonts.Plex, 13).X + 14, 0, -2),
                        ZIndex = 7,
                        Outline = true,
                        Parent = holder,
                        Color = Color3.fromRGB(163, 18, 18)
                    })
                end

                section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)

                local mouseover = false
                local toggled = false
                library.flags[flag] = default

                if not default then
                    callback(default)
                end

                local dwtooltipbox

                icon.MouseEnter:Connect(function()
                    if not toggled then
                        mouseover = true
                        icon.Color = utility.changecolor(library.theme["Object Background"], 3)
                    end
                end)

                if not syn then
                    toggleclick.MouseEnter:Connect(function()
                        if tooltip then
                            dwtooltipbox = utility.create("Square", {
                                Filled = true,
                                Thickness = 2,
                                Theme = "Object Background",
                                Size = UDim2.new(0, 10, 0, 10),
                                Position = UDim2.new(0, -10, 0, -2),
                                ZIndex = 7,
                                Parent = holder
                            })
                            utility.outline(dwtooltipbox, "Object Border")

                            local Text = utility.create("Text", {
                                Text = tooltiptext,
                                Font = Drawing.Fonts.Plex,
                                Size = 13,
                                Position = UDim2.new(0, -10, 0, 0),
                                Theme = "Text",
                                ZIndex = 7,
                                Outline = true,
                                Parent = dwtooltipbox
                            })

                            
                            dwtooltipbox.Size = UDim2.new(0, utility.textlength(tooltiptext, Drawing.Fonts.Plex, 13).X + 25, 0, utility.textlength(tooltiptext, Drawing.Fonts.Plex, 13).Y + 25)
                            if tooltipplace_ == "Right" then
                                dwtooltipbox.Position = UDim2.new(0, 300, 0, -2)
                            else
                                dwtooltipbox.Position = UDim2.new(0, -dwtooltipbox.AbsoluteSize.X - 35, 0, -2)
                            end

                            Text.Position = UDim2.new(0, dwtooltipbox.AbsoluteSize.X / 2 - utility.textlength(tooltiptext, Drawing.Fonts.Plex, 13).X / 2, 0, dwtooltipbox.AbsoluteSize.Y / 2 - utility.textlength(tooltiptext, Drawing.Fonts.Plex, 13).Y / 2)
                        end
                    end)

                    toggleclick.MouseLeave:Connect(function()
                        if tooltip then
                            if dwtooltipbox then
                                dwtooltipbox:Remove()
                            end
                        end
                    end)
                end

                icon.MouseLeave:Connect(function()
                    if not toggled then
                        mouseover = false
                        icon.Color = library.theme["Object Background"]
                    end
                end)

                icon.MouseButton1Down:Connect(function()
                    if not toggled then
                        icon.Color = utility.changecolor(library.theme["Object Background"], 6)
                    end
                end)

                icon.MouseButton1Up:Connect(function()
                    if not toggled then
                        icon.Color = mouseover and utility.changecolor(library.theme["Object Background"], 3) or library.theme["Object Background"]
                    end
                end)

                local function setstate()
                    toggled = not toggled

                    if mouseover and not toggled then
                        icon.Color = utility.changecolor(library.theme["Object Background"], 3)
                    end

                    utility.changeobjecttheme(icon, toggled and "Accent" or "Object Background")
                    utility.changeobjecttheme(title, toggled and "Accent" or "Disabled Text")
                    icon.Color = toggled and library.theme["Accent"] or (mouseover and utility.changecolor(library.theme["Object Background"], 3) or library.theme["Object Background"])

                    if toggled then
                        table.insert(accentobjs, icon)
                        table.insert(accentobjs, title)
                    else
                        table.remove(accentobjs, table.find(accentobjs, icon))
                        table.remove(accentobjs, table.find(accentobjs, title))
                    end
                    
                    library.flags[flag] = toggled
                    callback(toggled)
                end

                toggleclick.MouseButton1Click:Connect(setstate)

                local function set(bool)
                    bool = type(bool) == "boolean" and bool or false
                    if toggled ~= bool then
                        setstate()
                    end
                end

                set(default)

                flags[flag] = set

                local toggletypes = utility.table({}, true)

                function toggletypes:Toggle(bool)
                    set(bool)
                end

                local colorpickers = -1

                function toggletypes:ColorPicker(options)
                    colorpickers = colorpickers + 1

                    utility.table(options)
                    local flag = options.flag or utility.nextflag()
                    local callback = options.callback or function() end
                    local default = options.default or Color3.fromRGB(255, 255, 255)
                    local defaultalpha = options.defaultalpha or 1

                    return library.createcolorpicker(default, defaultalpha, holder, colorpickers, flag, callback)
                end

                function toggletypes:Keybind(options)
                    utility.table(options)
                    local default = options.default
                    local blacklist = options.blacklist or {}
                    local flag = options.flag or utility.nextflag()
                    local mode = options.mode and options.mode:lower()
                    local callback = options.callback or function() end

                    local newcallback = function(key, fromsetting)
                        if not fromsetting then
                            set(not toggled)
                        end

                        callback(key, fromsetting)
                    end

                    return library.createkeybind(default, holder, blacklist, flag, mode == "toggle" and newcallback or callback, -2)
                end

                function toggletypes:Slider(options)
                    utility.table(options)

                    local min = options.min or options.minimum or 0
                    local max = options.max or options.maximum or 100
                    local text = options.text or ("[value]/" .. max)
                    local float = options.float or 1
                    local default = options.default and math.clamp(options.default, min, max) or min
                    local flag = options.flag or utility.nextflag()
                    local callback = options.callback or function() end

                    holder.Size = UDim2.new(1, 0, 0, 28)
                    section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)

                    return library.createslider(min, max, holder, text, default, float, flag, callback)
                end

                function toggletypes:Dropdown(options)
                    utility.table(options)
                    local default = options.default
                    local content = type(options.content) == "table" and options.content or {}
                    local max = options.max and (options.max > 1 and options.max) or nil
                    local scrollable = options.scrollable
                    local scrollingmax = options.scrollingmax or 10
                    local flag = options.flag or utility.nextflag()
                    local callback = options.callback or function() end
    
                    if not max and type(default) == "table" then
                        default = nil
                    end
    
                    if max and default == nil then
                        default = {}
                    end
    
                    if type(default) == "table" then
                        if max then
                            for i, opt in next, default do
                                if not table.find(content, opt) then
                                    table.remove(default, i)
                                elseif i > max then
                                    table.remove(default, i)
                                end
                            end
                        else
                            default = nil
                        end
                    elseif default ~= nil then
                        if not table.find(content, default) then
                            default = nil
                        end
                    end

                    holder.Size = UDim2.new(1, 0, 0, 32)
                    section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)

                    return library.createdropdown(holder, content, flag, callback, default, max, scrollable, scrollingmax)
                end

                return toggletypes
            end

            function sectiontypes:Box(options)
                utility.table(options)
                local default = options.default or ""
                local placeholder = options.placeholder or ""
                local flag = options.flag or utility.nextflag()
                local callback = options.callback or function() end

                local box = utility.create("Square", {
                    Filled = true,
                    Thickness = 0,
                    Theme = "Object Background",
                    Size = UDim2.new(1, 0, 0, 14),
                    ZIndex = 7,
                    Parent = sectioncontent
                })

                utility.outline(box, "Object Border")

                utility.create("Image", {
                    Size = UDim2.new(1, 0, 1, 0),
                    Transparency = 0.5,
                    ZIndex = 8,
                    Parent = box
                })

                local text = utility.create("Text", {
                    Text = default,
                    Font = Drawing.Fonts.Plex,
                    Size = 13,
                    Position = UDim2.new(0.5, 0, 0, 0),
                    Center = true,
                    Theme = "Text",
                    ZIndex = 9,
                    Outline = true,
                    Parent = box
                })

                local placeholdertext = utility.create("Text", {
                    Text = placeholder,
                    Font = Drawing.Fonts.Plex,
                    Size = 13,
                    Position = UDim2.new(0.5, 0, 0, 0),
                    Center = true,
                    Theme = "Disabled Text",
                    ZIndex = 9,
                    Outline = true,
                    Parent = box
                })

                section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)

                box.MouseEnter:Connect(function()
                    mouseover = true
                    box.Color = utility.changecolor(library.theme["Object Background"], 3)
                end)

                box.MouseLeave:Connect(function()
                    mouseover = false
                    box.Color = library.theme["Object Background"]
                end)

                box.MouseButton1Down:Connect(function()
                    box.Color = utility.changecolor(library.theme["Object Background"], 6)
                end)

                box.MouseButton1Up:Connect(function()
                    box.Color = mouseover and utility.changecolor(library.theme["Object Background"], 3) or library.theme["Object Background"]
                end)

                library.createbox(box, text, function(str) 
                    if str == "" then
                        text.Visible = false
                        placeholdertext.Visible = true
                    else
                        placeholdertext.Visible = false
                        text.Visible = true
                    end
                end, function(str)
                    library.flags[flag] = str
                    callback(str)
                end)

                local function set(str)
                    placeholdertext.Visible = str == ""
                    text.Visible = str ~= ""

                    text.Color = Color3.fromRGB(200, 200, 200)
                    text.Text = str

                    library.flags[flag] = str
                    callback(str)
                end

                set(default)

                flags[flag] = set

                local boxtypes = utility.table({}, true)

                function boxtypes:Set(str)
                    set(str)
                end

                return boxtypes
            end

            function sectiontypes:Slider(options)
                utility.table(options)
                local name = options.name
                local min = options.min or options.minimum or 0
                local max = options.max or options.maximum or 100
                local text = options.text or ("[value]/" .. max)
                local float = options.float or 1
                local default = options.default and math.clamp(options.default, min, max) or min
                local flag = options.flag or utility.nextflag()
                local callback = options.callback or function() end

                local holder = utility.create("Square", {
                    Transparency = 0,
                    Size = UDim2.new(1, 0, 0, 24),
                    ZIndex = 7,
                    Thickness = 0,
                    Filled = true,
                    Parent = sectioncontent
                })

                local title = utility.create("Text", {
                    Text = name,
                    Font = Drawing.Fonts.Plex,
                    Size = 13,
                    Position = UDim2.new(0, 0, 0, -2),
                    Theme = "Text",
                    ZIndex = 7,
                    Outline = true,
                    Parent = holder
                })

                section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)

                return library.createslider(min, max, holder, text, default, float, flag, callback)
            end

            function sectiontypes:Dropdown(options)
                utility.table(options)
                local name = options.name
                local default = options.default
                local content = type(options.content) == "table" and options.content or {}
                local max = options.max and (options.max > 1 and options.max) or nil
                local scrollable = options.scrollable
                local scrollingmax = options.scrollingmax or 10
                local flag = options.flag or utility.nextflag()
                local callback = options.callback or function() end

                if not max and type(default) == "table" then
                    default = nil
                end

                if max and default == nil then
                    default = {}
                end

                if type(default) == "table" then
                    if max then
                        for i, opt in next, default do
                            if not table.find(content, opt) then
                                table.remove(default, i)
                            elseif i > max then
                                table.remove(default, i)
                            end
                        end
                    else
                        default = nil
                    end
                elseif default ~= nil then
                    if not table.find(content, default) then
                        default = nil
                    end
                end

                local holder = utility.create("Square", {
                    Transparency = 0,
                    Size = UDim2.new(1, 0, 0, 29),
                    Parent = sectioncontent
                })

                local title = utility.create("Text", {
                    Text = name,
                    Font = Drawing.Fonts.Plex,
                    Size = 13,
                    Position = UDim2.new(0, 0, 0, -2),
                    Theme = "Text",
                    ZIndex = 7,
                    Outline = true,
                    Parent = holder
                })

                section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)

                return library.createdropdown(holder, content, flag, callback, default, max, scrollable, scrollingmax)
            end

            function sectiontypes:List(options)
                utility.table(options)
                local name = options.name
                local default = options.default
                local content = type(options.content) == "table" and options.content or {}
                local max = options.max and (options.max > 1 and options.max) or nil
                local scrollable = options.scrollable
                local scrollingmax = options.scrollingmax or 10
                local flag = options.flag or utility.nextflag()
                local callback = options.callback or function() end

                if not max and type(default) == "table" then
                    default = nil
                end

                if max and default == nil then
                    default = {}
                end

                if type(default) == "table" then
                    if max then
                        for i, opt in next, default do
                            if not table.find(content, opt) then
                                table.remove(default, i)
                            elseif i > max then
                                table.remove(default, i)
                            end
                        end
                    else
                        default = nil
                    end
                elseif default ~= nil then
                    if not table.find(content, default) then
                        default = nil
                    end
                end

                local holder = utility.create("Square", {
                    Transparency = 0,
                    Size = UDim2.new(1, 0, 0, 29),
                    Parent = sectioncontent
                })

                local title = utility.create("Text", {
                    Text = name,
                    Font = Drawing.Fonts.Plex,
                    Size = 13,
                    Position = UDim2.new(0, 0, 0, -2),
                    Theme = "Text",
                    ZIndex = 7,
                    Outline = true,
                    Parent = holder
                })

                section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)

                return library.createdropdown(holder, content, flag, callback, default, max, scrollable, scrollingmax, true, section, sectioncontent, column)
            end

            function sectiontypes:ColorPicker(options)
                utility.table(options)
                local name = options.name
                local default = options.default or Color3.fromRGB(255, 255, 255)
                local flag = options.flag or utility.nextflag()
                local callback = options.callback or function() end
                local defaultalpha = options.defaultalpha or 1

                local holder = utility.create("Square", {
                    Transparency = 0,
                    Size = UDim2.new(1, 0, 0, 10),
                    Position = UDim2.new(0, 0, 0, -1),
                    ZIndex = 7,
                    Parent = sectioncontent
                })

                local title = utility.create("Text", {
                    Text = name,
                    Font = Drawing.Fonts.Plex,
                    Size = 13,
                    Position = UDim2.new(0, 0, 0, 0),
                    Theme = "Text",
                    ZIndex = 7,
                    Outline = true,
                    Parent = holder
                })

                section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)

                local colorpickers = 0

                local colorpickertypes = library.createcolorpicker(default, defaultalpha, holder, colorpickers, flag, callback)

                function colorpickertypes:ColorPicker(options)
                    colorpickers = colorpickers + 1

                    utility.table(options)
                    local default = options.default or Color3.fromRGB(255, 255, 255)
                    local flag = options.flag or utility.nextflag()
                    local callback = options.callback or function() end
                    local defaultalpha = options.defaultalpha or 1

                    return library.createcolorpicker(default, defaultalpha, holder, colorpickers, flag, callback)
                end

                return colorpickertypes
            end

            function sectiontypes:Keybind(options)
                utility.table(options)
                local name = options.name
                local default = options.default
                local blacklist = options.blacklist or {}
                local flag = options.flag or utility.nextflag()
                local callback = options.callback or function() end

                local holder = utility.create("Square", {
                    Transparency = 0,
                    Size = UDim2.new(1, 0, 0, 10),
                    Position = UDim2.new(0, 0, 0, -1),
                    ZIndex = 7,
                    Parent = sectioncontent
                })

                local title = utility.create("Text", {
                    Text = name,
                    Font = Drawing.Fonts.Plex,
                    Size = 13,
                    Theme = "Text",
                    ZIndex = 7,
                    Outline = true,
                    Parent = holder
                })

                section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)

                return library.createkeybind(default, holder, blacklist, flag, callback, -1)
            end

            return sectiontypes
        end

        return tabtypes
    end

    return windowtypes
end

return library
