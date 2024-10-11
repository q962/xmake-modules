function mtimedo(source, target, cb, is_le)
    is_le = is_le or false

    if type(source) ~= "string" or type(source) ~= "string" then
        return
    end

    if type(cb) ~= "function" then
        return
    end

    if is_le then
        if os.mtime(source) < os.mtime(target) then
            cb(source, target)
        end
    else
        if os.mtime(source) > os.mtime(target) then
            cb(source, target)
        end
    end
end
