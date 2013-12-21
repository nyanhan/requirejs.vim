if exists('rjs_loaded')
    finish
endif
let rjs_loaded = 1


if !exists("g:require_js_config_file")
    let g:require_js_config_file = ''
endif

if !exists("g:require_base_url")
    let g:require_js_base_url = ''
endif

if !exists("g:require_js_paths")
    let g:require_js_paths = {}
endif





fun! RJS_OpenFile(file)
    let map = {}
    let file = ''

    " get the urlstring under the curser
    if empty(a:file)
        let file = s:RJS_GetFileNameFromString()
        if empty(file)
            let file = s:RJS_GetFileNameFromVariable(map)
            if empty(file)
                echom "No matching file found ..."
            endif
        endif
    else
        let file = a:file
    endif

    echo "Opening file:  " . file

    if !empty(file)
        call s:RJS_GetConfig()
        let file = substitute(file, '^\w*!', "", "")
        call s:RJS_OpenJSFile(file)
    endif
endf


fun! s:RJS_GetFileNameFromString()
    try
        let a_save = @a
        let @a = ''
        normal! "ayi'
        if !empty(@a)
            return @a
        else
            normal! "ayi"
            if !empty(@a)
                return @a
            else 
                return ''
            endif
        endif
    finally
        let @a = a_save
    endtry
endf

fun! s:RJS_GetFileNameFromVariable(map)
    try
        let a_save = @a
        let @a = ''
        normal! "ayiw
        if !empty(@a)
            let var = @a
            if empty(a:map) 
                call s:RJS_LoadRequireList(a:map)
            endif
            if has_key(a:map, var) 
                return a:map[var]
            else
                echom "No file for " . var
            endif
        else
            return ''
        endif
    finally
        let @a = a_save
    endtry
endf

fun! s:RJS_LoadRequireList(map) 
    try
        let a_save = @a
        normal! ggVG"ay
        let file_contents = @a
        let define = matchstr(file_contents, 'define\s*(\s*\[\_.\{-}\]\s*,\s*function\s*(\_.\{-})')
        let files = s:RJS_Trim(split(matchstr(define, 'define\s*(\s*\[\zs\_.\{-}\ze\]'), ','))
        let vars = s:RJS_Trim(split(matchstr(define, 'function\s*(\zs\_.\{-}\ze)'), ','))
        let i = 0

        for file in files
            let var_name = get(vars, i)
            if  !empty(var_name)
                let a:map[var_name] = file
            endif
            let i += 1
        endfor
    finally
        let @a = a_save
    endtry
endf

fun! s:RJS_Trim(arr)
    let i = 0
    let arr = a:arr
    for entry in arr
        let arr[i] = s:RJS_TrimString(entry)
        let i += 1
    endfor
    return arr
endf

fun! s:RJS_TrimString(str)
    let str = a:str
    return substitute(substitute(str, '^\_\s*[''"]*', '', ''), '[''"]*\_\s*$', '', '')
endf

fun! s:RJS_ReadHash(str)
    let str = a:str

    if empty(str)
        return ["", ""]
    endif

    " remove ending ,
    let str = split(str, ",")[0]
    " spliting with : and remove \"
    let a = split(str, ":")
    let key = s:RJS_TrimString(a[0])
    let val = s:RJS_TrimString(join(a[1:], ":"))

    return [key, val]
endf

fun! s:RJS_GetConfig() 
    " find the config file
    if empty(g:require_js_config_file) || empty(g:require_js_base_url) || empty(g:require_js_paths)

        let g:require_js_config_file = findfile("config.js", ".;")

        if empty(g:require_js_config_file)
            throw "requirejs config.js file not found ..."
        endif
        
        let g:require_js_config_file = s:RJS_TrimString(g:require_js_config_file)
        let config = system("cat " . g:require_js_config_file)
        let g:require_js_base_url = matchstr(config, 'baseUrl[''"]\?\s*:\s*\([''"]\)\zs.\{-}\ze\1')

        if empty(g:require_js_base_url)
            let g:require_js_base_url = fnamemodify(g:require_js_config_file, ":h")
        endif

        let paths_str = split(matchstr(config, 'paths[''"]\?\s*:\s*{\n\zs\_.\{-}\ze}'), '\n')

        " read and use the paths
        let g:require_js_paths = {}
        for i in paths_str
            let res = s:RJS_ReadHash(i)

            if !empty(res[0]) && !empty(res[1])
                let g:require_js_paths[res[0]] = res[1] 
            endif
        endfor
    endif
endf



fun! s:RJS_OpenJSFile(file) 
    " add a / to know the name end
    let js_file = a:file . "/"
    let path_keys = keys(g:require_js_paths)

    for k in path_keys 
        if match(js_file, '^' . k . "/") != -1
            let js_file = substitute(js_file, k, g:require_js_paths[k], "")
        endif
    endfor
    
    " remove the added \/
    let js_file = substitute(js_file, '\/$', "", "")

    " append prepend baseUrl and append .js to the file
    if match(js_file, '\.js$') == -1 && match(js_file, '\.hbs$') == -1 && match(js_file, '\.html$') == -1 && match(js_file, '\.htm$') == -1
        let js_file = js_file . '.js'
    endif

    let js_file = g:require_js_base_url . '/' . js_file

    " check if file is readable and try to open it in new tab
    if (filereadable(js_file))
        exec ':e ' . js_file
    else
        echom "No such file: " . js_file
    endif
endf


nmap <silent> gt :call RJS_OpenFile('')<CR> 
