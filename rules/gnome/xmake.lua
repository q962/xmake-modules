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

        if not is_mode("debug") then
            for _, filepath in ipairs(os.files(target:scriptdir() .. "/res/*.gres.xml")) do
                local basename = path.basename(path.basename(filepath))

                gnome.compile_resources(target, basename, filepath, {"--manual-register"})
            end
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

        import("core.base.xml")

        if is_mode("debug") then
            local sep = is_host("windows") and ";" or ":"
            local G_RESOURCE_OVERLAYS = {}

            for _, filepath in ipairs(os.files(target:scriptdir() .. "/res/*.gres.xml")) do
                local gresource = xml.loadfile(filepath)

                for gresource_index in ipairs(gresource.children) do
                    local gresource_value = gresource.children[gresource_index]
                    if (gresource_value.name == "gresource") then

                        local prefix = gresource_value.attrs.prefix;

                        for file_index in ipairs(gresource_value.children) do
                            local file_value = gresource_value.children[file_index]
                            if (file_value.name == "file") then
                                local file_path = file_value.children[1].text;

                                local alias = file_value.attrs and file_value.attrs.alias or nil;

                                local res_path = prefix .. "/" .. (alias and alias or file_path)

                                table.insert(G_RESOURCE_OVERLAYS,
                                    res_path .. "=" .. path.absolute(file_path, target:scriptdir() .. "/res/"))
                            end
                        end
                    end
                end
            end

            if #G_RESOURCE_OVERLAYS > 0 then
                target:add("runenvs", "G_RESOURCE_OVERLAYS", G_RESOURCE_OVERLAYS)
            end
        end

        if not os.isfile(target:scriptdir() .. "/res/glib-2.0/schemas/gschemas.compiled") then
            gnome.compile_schemas(target:scriptdir() .. "/res/glib-2.0/schemas")
        end

        target:add("runenvs", "GSETTINGS_SCHEMA_DIR", target:scriptdir() .. "/res/glib-2.0/schemas")

    end)

    after_install(function(target)

        local installdir = path.absolute(target:installdir()) .. '/'
        local installdir_share = path.join(installdir, "share") .. '/'

        gnome.compile_schemas(installdir_share .. "/glib-2.0/schemas")

        if is_subhost("msys") then
            gnome.pack_gtk4(target);
        end
    end)
end
