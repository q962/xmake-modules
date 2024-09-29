import("core.project.config")

function _get_at(name, default)
    default = default or "normal"

    local value_at = ""

    if name:sub(#name) == ':' then
        name = name:sub(1, #name - 1)
        value_at = "pre"
    elseif name:sub(1, 1) == ':' then
        name = name:sub(2)
        value_at = "post"
    else
        value_at = default
    end
    return value_at, name
end

function _load(target, env_file)
    env_file = env_file:gsub("%.%.", ".")
    local envs = {
        normal = {},
        pre = {},
        post = {}
    }

    local data
    try {function()
        data = io.load(env_file)
    end}

    if data then
        for name, value in pairs(data) do
            local new_env_value = "";
            local value_at;
            value_at, name = _get_at(name)

            if type(value) == "string" or type(value) == "table" then
                for _, v in ipairs(value) do
                    local _value_at;
                    _value_at, v = _get_at(v, value_at)

                    envs[_value_at][name] = envs[_value_at][name] or {}

                    table.insert(envs[_value_at][name], v);
                end
            end
        end
    end

    return envs
end

function main(target, env_file_basename)
    env_file_basename = env_file_basename or ".env"

    local host = config.get("host")
    local arch = config.get("arch")
    local plat = config.get("plat")
    local mode = config.get("mode")

    host = host and host .. "." or ""
    arch = arch and arch .. "." or ""
    plat = plat and plat .. "." or ""
    mode = mode and mode or ""

    local project_path = vformat("$(projectdir)")
    local scriptdir = target:scriptdir()

    local project_env_path = path.join(project_path, env_file_basename)
    local script_env_path = path.join(scriptdir, env_file_basename)

    local envs = {
        normal = {},
        pre = {},
        post = {}
    }

    function _join(e)
        table.join2(envs.pre, e.pre)
        table.join2(envs.normal, e.normal)
        table.join2(envs.post, e.post)
    end

    _join(_load(target, project_env_path))
    _join(_load(target, project_env_path .. ".local"))
    _join(_load(target, project_env_path .. "." .. mode))
    _join(_load(target, project_env_path .. "." .. mode .. ".local"))

    _join(_load(target, script_env_path))
    _join(_load(target, script_env_path .. ".local"))
    _join(_load(target, script_env_path .. "." .. mode))
    _join(_load(target, script_env_path .. "." .. mode .. ".local"))

    local setenvs = {};
    for name, value in pairs(envs.pre) do
        local old_value = os.getenv(name);

        local v = table.concat(value, path.envsep())
        if v then
            old_value = old_value and v .. path.envsep() .. old_value or v
        end

        setenvs[name] = old_value;
    end
    for name, value in pairs(envs.normal) do
        local old_value = envs.pre[name] or os.getenv(name);

        local v = table.concat(value, path.envsep())
        if v then
            old_value = (old_value and old_value .. path.envsep() or "") .. v
        end

        setenvs[name] = old_value;
    end
    for name, value in pairs(envs.post) do
        local old_value = envs.pre[name] or os.getenv(name);

        local v = table.concat(value, path.envsep())
        if v then
            old_value = (old_value and old_value .. path.envsep() or "") .. v
        end

        setenvs[name] = old_value;
    end

    for name, value in pairs(setenvs) do
        os.setenv(name, value)
    end

    return envs;
end
