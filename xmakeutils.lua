import("net.http")
import("lib.detect.find_program")
import("core.project.config")
config.load()

--[[!
  编译需要的依赖库和工具
  如果以 '*' 开头，则表示必须，找不到报错，停止编译。
]]
function need(self, target, packages, programs)

    packages = packages and packages or {};
    programs = programs and programs or {};

    if #packages == 0 or #programs == 0 then return end

    local is_ok = true;
    local libpaths = {}
    local libpath_count = 0

    for _, v in ipairs(packages) do
        local is_optional = v:sub(1,1) == "+";

        if is_optional then
            v = v:sub(2);
        end

        local package = find_packages(v);

        if #package == 0 then
            cprint("${red} Fail: " .. v);

            if not is_optional then
                is_ok = false;
            end
        else
            if not is_optional then
                target:add(package);
                local linkdirs = package[1].linkdirs
                for linkdir_index, linkdir in ipairs(linkdirs) do
                    if libpaths[libdir] == nil then
                        libpaths[linkdir] = libpath_count
                        libpath_count = libpath_count + 1
                    end
                end
            end
        end
    end

    local libpathlist = {}
    for libpath, index in pairs(libpaths) do
        libpathlist[index+1] = libpath
    end
    if #libpathlist ~= 0 then
        table.insert(libpathlist, '$ORIGIN/../lib')
        table.insert(libpathlist, '$ORIGIN/../lib/x86_64-linux-gnu')
        target:add('rpathdirs',table.concat(libpathlist, ':'))
    end

    for _, v in ipairs(programs) do
        local is_must = v:sub(1,1) == "*";

        if is_must then
            v = v:sub(2);
        end

        if not find_program( v ) then
            if is_must then
                is_ok = false;
                cprint("${red}[必须] 缺少 " .. v);
            else
                cprint("[非必须] 缺少 " .. v);
            end
        else
            config.set("has_" .. v, true);
            config.save();
        end
    end

    if not is_ok then
        os.exit(false);
    end

end

function check_programs( programs)
    if not programs then return end

    local is_ok = true;

    for _, v in ipairs(programs) do
        local is_must = v:sub(1,1) == "*";

        if is_must then
            v = v:sub(2);
        end

        if not find_program( v ) then
            if is_must then
                is_ok = false;
                cprint("${red}[必须] 缺少 " .. v);
            else
                cprint("[非必须] 缺少 " .. v);
            end
        else
            config.set("has_" .. v, true);
            config.save();
        end
    end

    if not is_ok then
        os.exit();
    end
end

--[[!
  对比两个文件的更新时间
  \retval true  如果没有 stat 命令
  \retval true  pro1 修改日期大于 pro2
  \retval false 否则反之
]]
function do_stat(self, pro1, pro2)
    if config.get("has_stat") then
        local pro1_t = os.iorunv("stat", {"-c", "%Y", pro1});
        local pro2_t = os.iorunv("stat", {"-c", "%Y", pro2});
        return tonumber(pro1_t) > tonumber(pro2_t);
    else
        return true;
    end
end

--[[!
  下载文件，到项目目录下的 .xmake 文件夹中。

  如果不是 http  开头则解释为下载本项目下的同名模块
]]
function downfile(self, url, out_name)
    local my_repo = "https://cdn.jsdelivr.net/gh/q962/xmake_funs/"

    if not url:startswith("http") then
        out_name = url .. ".lua"
        url = my_repo .. out_name;
    end

    if not os.isfile("./.xmake.modules/" .. out_name) then
        http.download(url, ".xmake.modules/" .. out_name);
        if not os.isfile("./.xmake.modules/" .. out_name) then
            print("download fail: " .. url ..out_name);
            os.exit();
        end
    end
end

--[[!
  加载模块

  会自动下载库中的模块
]]
function loadmodule(self, module_name)

    downfile(self, module_name)

    table.join2(self, import(module_name, {anonymous=true, rootdir= ".xmake.modules"}))
end

function main()
    config.load(".xmake.config")
    local PKG_CONFIG_PATH = config.get("PKG_CONFIG_PATH");
    if  PKG_CONFIG_PATH and #PKG_CONFIG_PATH > 0 then
        for i=1, #PKG_CONFIG_PATH do
            os.addenv("PKG_CONFIG_PATH", PKG_CONFIG_PATH[i])
        end
    end
end

main()
