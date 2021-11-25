import("lib.detect.find_program")
import("core.project.config")
config.load()

function need(target, packages, programs)

    packages = packages and packages or {};
    programs = programs and programs or {};

    if #packages == 0 or #programs == 0 then return end

    local is_ok = true;

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
            end
        end
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
        os.exit();
    end

end

function do_stat(pro1, pro2)
    if config.get("has_stat") then
        local pro1_t = os.iorunv("stat", {"-c", "%Y", pro1});
        local pro2_t = os.iorunv("stat", {"-c", "%Y", pro2});
        return tonumber(pro1_t) > tonumber(pro2_t);
    else
        return true;
    end
end
