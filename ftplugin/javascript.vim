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





fun! RJS_OpenFile()

    " get the urlstring under the curser
    let file = s:RJS_GetFileNameFromString()

    "if empty(file)
        "let file = s:RJS_GetFileNameFromVariable()
    "endif

    if empty(file)
        echom "No matching file found ..."
    else
        echom "Opening file:  " . file

        call s:RJS_GetConfig()
        " replace text! or async!
        let file = substitute(file, '^\w*!', "", "")
        call s:RJS_OpenJSFile(file)
    endif
endf


fun! s:RJS_GetFileNameFromString()
    try
        " backup reg a, for refine it later
        let a_save = @a

        " copy string in \' to reg a
        let @a = ''
        normal! "ayi'

        if !empty(@a)
            return @a
        endif

        " copy string in \" to reg a
        normal! "ayi"

        if !empty(@a)
            return @a
        else 
            return ''
        endif
    finally
        " recover reg a
        let @a = a_save
    endtry
endf

fun! s:RJS_GetFileNameFromVariable()
    try
        " backup reg a, for refine it later
        let a_save = @a

        " copy word use yiw to reg a
        let @a = ''
        normal! "ayiw

        if !empty(@a)
            let var = @a
            let map = s:RJS_LoadRequireList()

            if has_key(map, var) 
                return map[var]
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

fun! s:RJS_LoadRequireList() 
    try
        " copy all content to reg a
        let a_save = @a
        " save cursor position
        let save_cursor = getpos(".")
        normal! ggVG"ay
        " reset cursor position
        call setpos('.', save_cursor)

        let map = {}
        let file_contents = @a
        " TODO match content in define, like: define([], function() {}); but if
        " module has name may error 
        let define = matchstr(file_contents, 'define\s*(\s*\[\_.\{-}\]\s*,\s*function\s*(\_.\{-})')
        " get paths in define
        let files = s:RJS_Trim(split(matchstr(define, 'define\s*(\s*\[\zs\_.\{-}\ze\]'), ','))
        " get variable in define
        let vars = s:RJS_Trim(split(matchstr(define, 'function\s*(\zs\_.\{-}\ze)'), ','))
        let i = 0

        for file in files
            let var_name = get(vars, i)

            if  !empty(var_name)
                let map[var_name] = file
            endif

            let i += 1
        endfor

        return map
    catch
        return {}
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
    " find the config file each time, not on startup
    " find parents dir config.js
    let g:require_js_config_file = findfile("config.js", ".;")

    " must have config.js
    if empty(g:require_js_config_file)
        throw "requirejs config.js file not found ..."
    endif

    let g:require_js_config_file = s:RJS_TrimString(g:require_js_config_file)

    " find baseUrl in config.js, not tested
    let config = system("cat " . g:require_js_config_file)
    let g:require_js_base_url = matchstr(config, 'baseUrl[''"]\?\s*:\s*\([''"]\)\zs.\{-}\ze\1')

    " if baseUrl is undefined, set it the dirname of config.js
    if empty(g:require_js_base_url)
        let g:require_js_base_url = fnamemodify(g:require_js_config_file, ":h")
    endif

    " read the paths to a hash
    let paths_str = split(matchstr(config, 'paths[''"]\?\s*:\s*{\n\zs\_.\{-}\ze}'), '\n')
    let g:require_js_paths = {}

    for i in paths_str
        let res = s:RJS_ReadHash(i)

        if !empty(res[0]) && !empty(res[1])
            let g:require_js_paths[res[0]] = res[1] 
        endif
    endfor
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

    " check if file is readable and try to open it
    if (filereadable(js_file))
        exec ':e ' . js_file
    else
        echom "No such file: " . js_file
    endif
endf


nmap <silent> gt :call RJS_OpenFile()<CR> 
