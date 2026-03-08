rule("gnome")
do
    on_load(function(target)
        local gnome = import("../../gnome")

        target:add("installfiles", --
        target:scriptdir() .. "/res/(glib-2.0/**)", --
        target:scriptdir() .. "/res/(applications/**)", --
        target:scriptdir() .. "/res/(locale/**)", --
        target:scriptdir() .. "/res/(icons/**)", --
        target:scriptdir() .. "/res/(metainfo/**)", {
            prefixdir = "share"
        })

        if is_mode("debug") then
            target:add("defines", "DEBUG");
        end

        if get_config("APPID") then
            target:add("installfiles", "res/(" .. get_config("APPID") .. "/**)", {
                prefixdir = "share"
            })
        end

        for _, filepath in ipairs(os.files(target:scriptdir() .. "/res/*.gres.xml")) do
            local basename = path.basename(path.basename(filepath))

            gnome.compile_resources(target, basename, filepath, {})
        end

    end)

    before_build(function(target)
        local gnome = import("../../gnome")
        local utils = import("../../utils")

        if get_config("APPID") then
            for _, filepath in ipairs(os.files(target:scriptdir() .. "/po/*.po")) do
                local basename = path.basename(filepath)
                local out_dir = target:scriptdir() .. "/res/locale/" .. basename .. "/LC_MESSAGES/"
                local out_path = out_dir .. get_config("APPID") .. ".mo"
                os.mkdir(out_dir)
                utils.mtimedo(filepath, out_path, function()
                    os.execv("msgfmt", {filepath, "-o", out_path})
                end)
            end
        end
    end)

    before_run(function(target)
        local utils = import("../../utils")
        local gnome = import("../../gnome")

        if not os.isfile(target:scriptdir() .. "/res/glib-2.0/schemas/gschemas.compiled") then
            gnome.compile_schemas(target:scriptdir() .. "/res/glib-2.0/schemas")
        end

        target:add("runenvs", "GSETTINGS_SCHEMA_DIR", target:scriptdir() .. "/res/glib-2.0/schemas")

    end)

    after_install(function(target)
        local gnome = import("../../gnome")

        local installdir = path.absolute(target:installdir()) .. '/'
        local installdir_share = path.join(installdir, "share") .. '/'

        gnome.compile_schemas(installdir_share .. "/glib-2.0/schemas")

        if is_subhost("msys") then
            gnome.pack_gtk4(target);
        end
    end)
end
