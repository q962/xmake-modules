import("lib.detect.find_program")
import("core.project.config")
config.load()

--! \brief 打包gtk4 程序
--! \see https://gitlab.gnome.org/GNOME/gtk/-/blob/main/docs/reference/gtk/running.md
function pack_gtk4(self, target)
    local dllsuffix = is_host("windows") and ".dll" or ".so";
    local exesuffix = is_host("windows") and ".exe" or "";

    local installdir = target:installdir()
    local pkg_vars = config.get("pkg_vars") or {};
    if #pkg_vars == 0 then
        for packagename, vars in pairs({
            ["gio-2.0"] = {
                "prefix",
                "gdbus",
                "schemasdir",
                "giomoduledir"
            },
            gtk4 = {
                "prefix"
            },
            ["gdk-pixbuf-2.0"] = {
                "prefix",
                "gdk_pixbuf_moduledir",
                "gdk_pixbuf_cache_file",
                "gdk_pixbuf_binarydir"
            }
        }) do
            pkg_vars[packagename] = pkg_vars[packagename] or {}
            for _, var in ipairs(vars) do
                local s = try{ function() return os.iorunv("pkg-config", { "--variable", var, packagename }) end }
                if s then
                    pkg_vars[packagename][var] = s:trim();
                end
            end
        end
        config.set("pkg_vars", pkg_vars);
        config.save();
    end

    local outdlls = {};
    local function find_dep(dep_path)
        local dep_dlls = {};
        local function get_dll_deps(dllname)
            local deps_str = os.iorunv("ldd", { dllname });
            for _, v in ipairs(deps_str:split("\n")) do
                local dll = v:split(" ")[3];
                if dll and not outdlls[dll] and dll:match("^/[^c]") then
                    outdlls[dll] = true;
                    dep_dlls[dll] = true;
                    get_dll_deps(dll)
                end
            end
        end

        get_dll_deps(dep_path);

        for v, _ in pairs(dep_dlls) do
            if not os.isfile(path.join(installdir, "bin", path.filename(v))) then
                if is_plat("mingw") then
                    os.cp(path.join(config.get("mingw"), "..", v), path.join(installdir, "bin") .. "/");
                else
                    os.cp(v, path.join(installdir, "bin") .. "/");
                end
            end
        end
        return dep_dlls;
    end

    find_dep(target:targetfile());
    find_dep(pkg_vars["gio-2.0"].gdbus .. exesuffix);

    local function cp(a, b)
        a = a:gsub("\\", "/");
        print("copy", a, "==>", b);
        os.cp(a,b);
    end

    -- gdbus
    cp(pkg_vars["gio-2.0"].gdbus .. exesuffix, path.join(installdir, "bin") .. "/");
    find_dep(pkg_vars["gio-2.0"].gdbus .. exesuffix)
    -- gtk dep file
    cp(path.join(pkg_vars.gtk4.prefix, "share", "gtk-4.0"), path.join(installdir, "share") .. "/");
    -- gstreamer
    local module_gstreamer_path = path.join(pkg_vars.gtk4.prefix, "lib", "gtk-4.0", "4.0.0", "media", "libmedia-gstreamer" .. dllsuffix);
    cp(
        module_gstreamer_path,
        path.join(installdir, "lib", "gtk-4.0", "4.0.0", "media", "libmedia-gstreamer") .. "/"
    );
    find_dep(module_gstreamer_path)
    -- gdk dep file
    cp(
        path.join(pkg_vars["gdk-pixbuf-2.0"].gdk_pixbuf_moduledir, "*" .. dllsuffix),
        path.join(
            installdir,
            path.relative(
                pkg_vars["gdk-pixbuf-2.0"].gdk_pixbuf_moduledir,
                pkg_vars["gdk-pixbuf-2.0"].prefix)
        ) .. "/"
    );
    for _,v in ipairs(os.files(path.join(pkg_vars["gdk-pixbuf-2.0"].gdk_pixbuf_moduledir, "*" .. dllsuffix))) do
        find_dep(v);
    end
    -- gdk dep file
    cp(
        pkg_vars["gdk-pixbuf-2.0"].gdk_pixbuf_cache_file,
        path.join(
            installdir,
            path.relative(
                pkg_vars["gdk-pixbuf-2.0"].gdk_pixbuf_binarydir,
                pkg_vars["gdk-pixbuf-2.0"].prefix)
        ) .. "/"
    );
    -- mo file
    cp(
        path.join(pkg_vars["gdk-pixbuf-2.0"].prefix, "share", "locale", "zh_CN", "LC_MESSAGES", "gtk40.mo"),
        path.join(installdir, "share", "locale", "zh_CN", "LC_MESSAGES") .. "/"
    );
    cp(
        path.join(pkg_vars["gdk-pixbuf-2.0"].prefix, "share", "locale", "zh_CN", "LC_MESSAGES", "gtk40-properties.mo"),
        path.join(installdir, "share", "locale", "zh_CN", "LC_MESSAGES") .. "/"
    );
    -- cp glib dep file
    cp(
        path.join(pkg_vars["gio-2.0"].schemasdir, "gschemas.compiled"),
        path.join(
            installdir,
            path.relative(
                pkg_vars["gio-2.0"].schemasdir,
                pkg_vars["gio-2.0"].prefix)
        ) .. "/"
    );
    -- cp gio dep file
    cp(
        pkg_vars["gio-2.0"].giomoduledir,
        path.join(
            installdir,
            path.relative(
                pkg_vars["gio-2.0"].giomoduledir,
                pkg_vars["gio-2.0"].prefix),
            ".."
        ) .. "/"
    );
    for _,v in ipairs(os.files(path.join(pkg_vars["gio-2.0"].giomoduledir, "*" .. dllsuffix))) do
        find_dep(v);
    end

    -- -- cp icons
    -- if is_plat("mingw") then
    --     cp(
    --         path.join(config.get("mingw"), "share", "icons", "Adwaita"),
    --         path.join(installdir, "share", "icons") .. "/"
    --     );
    --     cp(
    --         path.join(config.get("mingw"), "share", "icons", "hicolor"),
    --         path.join(installdir, "share", "icons") .. "/"
    --     );
    -- else
    --     os.raise("需要手动指定 Adwaita\\hicolor 主题所在目录")
    -- end

    -- 如果是安装程序，最好使用 lnk 文件，隐藏目录结构。
    -- win32 上在 <install> 目录下放置 lnk 文件
end
