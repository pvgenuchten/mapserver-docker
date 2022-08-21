uri = lighty.r.req_attr["uri.query"]
path = lighty.r.req_attr["uri.path-raw"]

-- path_templates = '/opt/lighttpd'
-- document_root = '/srv/data'
path_templates = os.getenv("LIGHT_CONF_DIR")
document_root = os.getenv("LIGHT_ROOT_DIR")

if (path == '/favicon.ico') then
    lighty.r.resp_header["Location"] = 'https://files.isric.org/favicon.ico'
    return 301   
else 
    if (path == '/robots.txt') then
        lighty.r.resp_body.set({ "User-agent: *\nAllow: /" })
        lighty.r.resp_header["Content-Type"] = "text/html"
        return 200
    else
        -- the root path, we could take a default map here 
        if (path == '/' or path == '/index.html') then
            lighty.r.resp_body:add({ { filename =  path_templates .. '/top.inc' }, { filename =  path_templates .. '/home.inc' }, "<h2  class='is-size-3'>Maps</h2><ul>" })
            for name in lighty.c.readdir( document_root )  do 
                if (name:sub(#name-3) == '.map') then
                    lighty.r.resp_body:add({"<li><a href='", name:sub(1,#name-4) ,"'>", name:sub(1,#name-4), "</a></li>" }) 
                end
            end
            lighty.r.resp_body:add({ "</ul>" }, { filename =  path_templates .. '/bottom.inc' })
            lighty.r.resp_header["Content-Type"] = "text/html"
            return 200
        else
                -- check if mapfile exists
                local st = lighty.c.stat(document_root .. path .. ".map")
                if (st and st.is_file) then  
                    -- check if request has query parameters
                    if uri then
                        params = ''
                        for k, v in uri:gmatch("\\?([^?&=]+)=([^&]+)") do
                            if k:lower() ~= 'map' then
                                params = params .. k .. '=' .. v .. '&'
                            end
                        end
                        -- this puts the remote-addr on a get param %ows_url%, to be picked up by mapfile (for ows_onlineresource)
                        params = params .. 'map=' .. document_root .. path .. '.map&ows_url=' .. lighty.r.req_attr["uri.scheme"] .. '://' .. lighty.r.req_attr["uri.authority"] .. path .. '&'
                        lighty.r.req_attr["uri.path"] = '/'
                        lighty.r.req_attr["uri.query"] = params:sub(1, -2)
                        print(lighty.r.req_attr["uri.scheme"] .. '://' .. lighty.r.req_attr["uri.authority"] .. path .. '?' .. params)
                        print(params)
                        print(lighty.r.req_header["Forwarded"])
                    else
                        -- no query parameters, show a default page (with a listing of layers for example)
                        lighty.r.resp_body.set({ { filename = path_templates .. '/top.inc' },{ filename = path_templates .. '/map.inc' },"<script>setTimeout(printMaps('".. path .."'),500)</script>", { filename = path_templates .. '/bottom.inc' } })
                        lighty.r.resp_header["Content-Type"] = "text/html"
                        return 200
                    end
                else    
                    -- mapfile does not exist (or some other irrelevant request)
                    lighty.r.resp_body.set({ { filename = path_templates .. '/top.inc' }, {"<h1 class='is-size-2'>404 Page not found</h1><p><a href='/'>Open index</a></p>"},{ filename = path_templates .. '/bottom.inc' } })
                    lighty.r.resp_header["Content-Type"] = "text/html" 
                    print("404 " .. path .. ".map")
                    return 404
                end
        end
    end
end
