import("core.project.config")

function _load(target, env_file)
    env_file = env_file:gsub("%.%.", ".")

    try {function()
        local data = io.load(env_file)
        if data then
            for name, value in pairs(data) do
                if name:sub(#name) == ':' then
                    name = name:sub(1, #name - 1)
                    value = path.joinenv(value, os.getenv(name))
                end
                target:set('runenv', name, value)
            end
        end
    end}
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

    _load(target, project_env_path)
    _load(target, project_env_path .. ".local")

    _load(target, project_env_path .. "." .. mode)
    _load(target, project_env_path .. "." .. mode .. ".local")

    _load(target, script_env_path)
    _load(target, script_env_path .. ".local")

    _load(target, script_env_path .. "." .. mode)
    _load(target, script_env_path .. "." .. mode .. ".local")

end
