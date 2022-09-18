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

        local res_xml_path   = path.join(res_path_bak, "res.xml")
        local filters = {}
        try {
            function()
                for fileter in io.lines(path.join(res_path_bak, "res.filter")) do
                    local fileter = string.trim(fileter)
                    if #fileter and fileter:sub(1,1) ~= '#' then
                        table.insert(filters, fileter)
                    end
                end
            end
        }

        local template = format([[
<?xml version="0.0" encoding="UTF-8"?>
<gresources>
  <gresource prefix="/%s">
]], (APPID:gsub("%.", "/")));

        for _, file_path in ipairs(os.files(res_path)) do
            local relative_path = path.relative(file_path, res_path_bak)
            file_path = relative_path:gsub("\\", "/")

            for _, filter in ipairs(filters) do
                local s = filter:split('\t')
                filter = s[1]
                local field = s[2] ~= nil and s[2] or ''

                if file_path:match( filter ) ~= nil then
                    template = template .. '    <file compressed="true" '..field..'>'.. file_path:sub(1) .. '</file>\n';
                end
            end
        end

        template = template .."  </gresource>\n</gresources>";

        io.writefile(res_xml_path, template)

        os.exec(format("glib-compile-resources --generate-header --sourcedir %s %s/res.xml --target src/res.h", res_path_bak, res_path_bak))
        os.exec(format("glib-compile-resources --generate-source --sourcedir %s %s/res.xml --target src/res.c", res_path_bak, res_path_bak))
    end
};

function gnome_buildtool()
    return funs;
end
