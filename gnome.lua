import("lib.detect.find_program")
import("core.project.config")
config.load()

function genResources(res_path)
    local res_path_bak = res_path;
    res_path = res_path .. "/**"

    local APPID = config.get("APPID")
    if not APPID or not #APPID then
        cprint("lost APPID")
        os.exit(1);
    end

    local res_xml_path = path.join(res_path_bak, "res.xml")
    local filters = {}
    try {function()
        for fileter in io.lines(path.join(res_path_bak, "res.filter")) do
            local fileter = string.trim(fileter)
            if #fileter and fileter:sub(1, 1) ~= '#' then
                table.insert(filters, fileter)
            end
        end
    end}

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

            if file_path:match(filter) ~= nil then
                template = template .. '    <file compressed="true" ' .. field .. '>' .. file_path:sub(1) .. '</file>\n';
            end
        end
    end

    template = template .. "  </gresource>\n</gresources>";

    io.writefile(res_xml_path, template)

    os.exec(format("glib-compile-resources --generate-header --sourcedir %s %s/res.xml --target src/res.h",
        res_path_bak, res_path_bak))
    os.exec(format("glib-compile-resources --generate-source --sourcedir %s %s/res.xml --target src/res.c",
        res_path_bak, res_path_bak))
end

local dep_cache = {};
local function find_deps(target, outpath)
    if not is_host("windows") then
        return;
    end

    local dep_dlls = {};
    local function get_dll_deps(dllname)
        local deps_str = os.iorunv("ldd", {dllname});
        for _, v in ipairs(deps_str:split("\n")) do
            local dll = v:split(" ")[3];
            if dll and not dep_cache[dll] and dll:match("^/[^c]") then
                dep_cache[dll] = true;
                dep_dlls[dll] = true;
                get_dll_deps(dll)
            end
        end
    end

    get_dll_deps(target);

    for v, _ in pairs(dep_dlls) do
        if not os.isfile(path.join(outpath, path.filename(v))) then
            if is_plat("mingw") then
                v = config.get("mingw") .. "/../" .. v
            end

            os.cp(v, outpath);
        end
    end

end

-- ! \brief 打包gtk4 程序
-- ! \see https://gitlab.gnome.org/GNOME/gtk/-/blob/main/docs/reference/gtk/running.md
function pack_gtk4(target, bin_outpath, lib_outpath, share_outpath)
    local dllsuffix = is_host("windows") and ".dll" or ".so";
    local exesuffix = is_host("windows") and ".exe" or "";

    local _prefix; -- 数据来源的路径前缀
    local installdir = path.absolute(target:installdir())
    bin_outpath = bin_outpath or (installdir .. "/bin/")
    lib_outpath = lib_outpath or (installdir .. "/lib/")
    share_outpath = share_outpath or (installdir .. "/share/")

    import("lib.detect.pkgconfig")

    local pkg_vars = {};
    for packagename, vars in pairs({
        ["gio-2.0"] = {"prefix", "gdbus", "schemasdir", "giomoduledir"},
        ["gtk4"] = {"prefix"},
        ["glib-2.0"] = {"prefix"},
        ["gdk-pixbuf-2.0"] = {"prefix", "gdk_pixbuf_moduledir", "gdk_pixbuf_cache_file", "gdk_pixbuf_binarydir"}
    }) do
        pkg_vars[packagename] = pkgconfig.variables(packagename, vars)
    end

    find_deps(target:targetfile(), bin_outpath);
    find_deps(pkg_vars["gio-2.0"].gdbus .. exesuffix, bin_outpath);

    local function cp(a, b, opt)
        a = a:gsub("\\", "/");

        if (b:endswith("/")) then
            os.mkdir(b)
        end

        b = path.relative(b, vformat("$(projectdir)"))

        os.cp(a, b, opt);
    end

    -- gdbus
    cp(pkg_vars["gio-2.0"].gdbus .. exesuffix, bin_outpath);
    find_deps(pkg_vars["gio-2.0"].gdbus .. exesuffix, bin_outpath)
    -- gtk dep file
    cp(path.join(pkg_vars.gtk4.prefix, "share", "gtk-4.0"), share_outpath);

    -- gdk-pixbuf dep file
    local gdk_pixbuf_moduledir_relative = path.relative(pkg_vars["gdk-pixbuf-2.0"].gdk_pixbuf_moduledir,
        pkg_vars["gdk-pixbuf-2.0"].prefix)
    local gdk_pixbuf_moduledir = path.join(installdir, gdk_pixbuf_moduledir_relative) .. "/"

    cp(path.join(pkg_vars["gdk-pixbuf-2.0"].gdk_pixbuf_moduledir, "*" .. dllsuffix), gdk_pixbuf_moduledir);
    for _, v in ipairs(os.files(pkg_vars["gdk-pixbuf-2.0"].gdk_pixbuf_moduledir, "*" .. dllsuffix)) do
        find_deps(v, bin_outpath);
    end
    os.execv("gdk-pixbuf-query-loaders", {}, {
        stdout = gdk_pixbuf_moduledir .. "/../loaders.cache",
        curdir = installdir,
        envs = {
            GDK_PIXBUF_MODULEDIR = gdk_pixbuf_moduledir_relative
        }
    })
    -- cp gio dep file
    local schemas_path =
        path.join(installdir, path.relative(pkg_vars["gio-2.0"].schemasdir, pkg_vars["gio-2.0"].prefix))
    cp(path.join(pkg_vars["gio-2.0"].schemasdir, "org.gtk.gtk4.*"), schemas_path);
    compile_schemas(schemas_path);
    os.rm(schemas_path .. "/*.gschema")
    -- cp gio dep file
    local giomoduledir = pkg_vars["gio-2.0"].giomoduledir
    local out_giomoduledir = path.join(installdir, path.relative(giomoduledir, pkg_vars["gio-2.0"].prefix))
    cp(giomoduledir, out_giomoduledir);
    for _, v in ipairs(os.files(path.join(giomoduledir, "*" .. dllsuffix))) do
        find_deps(v, bin_outpath);
    end
end

function compile_schemas(schema_path, out_path)
    out_path = out_path or schema_path
    os.execv("glib-compile-schemas", {"--targetdir=" .. out_path, schema_path})
end

function compile_resources(target, name, resources_path, opt)
    local buildir = vformat("$(builddir)/")

    import("utils")

    local resources_c_path = buildir .. "/gresources/" .. name .. ".c"
    os.mkdir(buildir .. "/gresources/")

    utils.mtimedo(resources_path, resources_c_path, function()
        os.execv("glib-compile-resources",
            table.join(
                {"--generate-source", "--sourcedir=" .. path.directory(resources_path), "--target=" .. resources_c_path,
                 resources_path}, opt))
    end)

    target:add("files", resources_c_path)
end
