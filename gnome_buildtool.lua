import("core.project.config")
config.load()

local funs = {
    genResources = function(res_path)
        local res_path_bak = res_path;
        res_path = res_path .. "/**"

        local APPID = config.get("APPID")
        if  not #APPID then
            cprint("lost APPID")
            os.exit(1);
        end

        local res_xml_path = path.join(res_path_bak, "res.xml")

        if not os.isfile(res_xml_path) then
            local template = format([[
            <?xml version="1.0" encoding="UTF-8"?>
            <gresources>
            <gresource prefix="/%s">
            ]], (APPID:gsub("%.", "/")));

            for _, file_path in ipairs(os.files(res_path)) do
                file_path = path.relative(file_path, res_path_bak):gsub("\\", "/")

                if file_path:find("res.xml") then goto continue; end

                template = template .. '    <file compressed="true">'.. file_path:sub(1) .. '</file>\n';

                ::continue::
            end

            template = template ..[[  </gresource>
            </gresources>]];

            io.writefile(res_xml_path, template)
        end

        os.exec(format("glib-compile-resources --generate-header --sourcedir %s %s/res.xml --target src/res.h", res_path_bak, res_path_bak))
        os.exec(format("glib-compile-resources --generate-source --sourcedir %s %s/res.xml --target src/res.c", res_path_bak, res_path_bak))
    end
};

function gnome_buildtool()
    return funs;
end
