" Vim completion script
" Language:	pug (formerly jade) template engine
" Maintainer: dNitro ( ali.zarifkar AT gmail DOT com )
" Credits: Mikolaj Machowski ( mikmach AT wp DOT pl )
"          Wei-Ko Kao (othree) ( othree AT gmail DOT com )
" Last modified: 2019 Aug 05 at 16:40:35

if !exists('g:aria_attributes_complete')
  let g:aria_attributes_complete = 1
endif

" Main completion function {{{
function! pugcomplete#CompletePug(findstart, base)
  if a:findstart
    " locate the start of the word
    let line = getline('.')
    let start = col('.') - 1
    let curline = line('.')
    let compl_begin = col('.') - 2
    while start >= 0 && line[start - 1] =~ '\(\k\|[!-]\)'
      let start -= 1
    endwhile
    " Handling of entities {{{
    if start >= 0 && line[start - 1] =~ '&'
      let b:entitiescompl = 1
      let b:compl_context = ''
      return start
    endif
    " }}}
    " Handling of <style> tag {{{
    let stylestart = search('\<style\.\s*$', 'bnW')
    if stylestart != 0
      let styleend = stylestart + 1
      while indent(styleend) > indent(stylestart) || (getline(styleend) =~ '^\s*$' && styleend < line('$'))
        let styleend = styleend + 1
      endwhile
      if stylestart <= curline && styleend >= curline && indent(curline) > indent(stylestart)
        let b:csscompl = 1
        let b:cssrange = [stylestart + 1, styleend - 1]
        while start >= 0 && line[start - 1] =~ '\(\k\|-\)'
          let start -= 1
        endwhile
      endif
    endif
    " }}}
    " Handling of <script> and - tag {{{
    let scriptstart = search('\%(\<script.*\.\|-\)\s*$', 'bnW')
    if scriptstart != 0
      let scriptend = scriptstart + 1
      while indent(scriptend) > indent(scriptstart) || (getline(scriptend) =~ '^\s*$' && scriptend < line('$'))
        let scriptend = scriptend + 1
      endwhile
      if scriptstart <= curline && scriptend >= curline && indent(curline) > indent(scriptstart)
        let b:jscompl = 1
        let b:jsrange = [scriptstart + 1, scriptend - 1]
        while start >= 0 && line[start - 1] =~ '\k'
          let start -= 1
        endwhile
      endif
    endif
    " }}}
    " Handling of contexts {{{
    if !exists("b:csscompl") && !exists("b:jscompl")
      let b:compl_cont = getline('.')[0:(compl_begin)]
      let b:after = line[compl_begin+1:]
      let b:pug_stopper = 0
      let b:compl_context = substitute(b:compl_cont, '^\s*', '', '')
      let compl = b:compl_context
      let b:tag = pugcomplete#GetTag(b:compl_context)
      let b:parentTag = pugcomplete#GetParentTag()
      if b:compl_context =~ '[^ ]:\s\+[.#]\?[a-zA-Z0-9-_.#:]\{-}$'
        let b:parentTag = pugcomplete#GetParentTagShort(b:compl_cont, 2)
        let b:compl_context = matchstr(b:compl_context, '[^ ]:\s\+[.#]\?\zs[a-zA-Z0-9-_.#:]\{-}$')
      endif
      " lets Check that are we in a multiline state?
      let c = col('.')
      let save_cursor = getpos('.')
      " search backward for last paren that is not preceded with ' or \" or space
      let lastParenLine = searchpos('[''" ]\@<!(', 'bW')
      exe "norm! %"
      let curpos = line('.')
      let ccol = col('.')
      if lastParenLine[0] != 0
        if lastParenLine[0] != curpos && ( curline > lastParenLine[0] && curline < curpos )
          exe "norm! %"
          let b:tag = matchstr(getline(lastParenLine[0]), '[.#]\?[0-9A-Za-z_-]\+\ze[^ ]*\%' . col('.') . 'c')
          if b:tag =~ '^\s*[.#]'
            let b:tag = 'div'
          endif
          " we are inside a multiline situation
          let context_lines = getline(lastParenLine[0], curline-1) + [compl]
          let b:compl_context = join(context_lines, ' ')
          let b:compl_context = matchstr(b:compl_context, '.*[''" ]\@<!(\zs.*')
          call pugcomplete#OnEventsStart(b:compl_context)
          let b:attrcompl = 1
        elseif lastParenLine[0] == curpos && ( ccol == lastParenLine[1] || ( ccol >= c && curpos >= curline ))
          exe "norm! %"
          let b:tag = matchstr(getline(lastParenLine[0]), '[.#]\?[0-9A-Za-z_-]\+\ze[^ ]*\%' . col('.') . 'c')
          if b:tag =~ '^\s*[.#]'
            let b:tag = 'div'
          endif
          let b:compl_context = matchstr(compl, '.*[''" ]\@<!(\zs.*')
          call pugcomplete#OnEventsStart(b:compl_context)
          let b:attrcompl = 1
        endif
      endif
      call setpos('.', save_cursor)
    else
      let b:compl_context = getline('.')[0:compl_begin]
      let b:after = line[compl_begin+1:]
    endif
    " }}}
    return start
  else
    " Initialize base return lists
    let res = []
    let res2 = []
    " a:base is very short - we need context
    let context = b:compl_context
    let after = b:after
    " Check if we should do CSS completion inside of <style> tag
    " or JS completion inside of <script> tag
    if exists("b:csscompl")
      unlet! b:csscompl
      return csscomplete#CompleteCSS(0, a:base)
    elseif exists("b:jscompl")
      unlet! b:jscompl
      return javascriptcomplete#CompleteJS(0, a:base)
    endif
    unlet! b:compl_context
    " Entities completion {{{
    if exists("b:entitiescompl")
      unlet! b:entitiescompl

      if !exists("b:html_doctype")
        call pugcomplete#CheckDoctype()
      endif
      if !exists("b:html_omni")
        call pugcomplete#LoadData()
      endif
      if g:aria_attributes_complete == 1 && !exists("b:aria_omni")
        call pugcomplete#LoadAria()
      endif

      let entities =  b:html_omni['vimxmlentities'] + ['attributes']

      if len(a:base) == 1
        for m in entities
          if m =~ '^'.a:base
            call add(res, m.';')
          endif
        endfor
        return res
      else
        for m in entities
          if m =~? '^'.a:base
            call add(res, m.';')
          elseif m =~? a:base
            call add(res2, m.';')
          endif
        endfor

        return res + res2
      endif

    endif
    " }}}
    let parentTag = b:parentTag
    let stopper = b:pug_stopper
    if context == '' && !exists('b:attrcompl')
      let tag = ''
    else
      let tag = b:tag
      if tag =~# '^[A-Z]*$'
        let uppercase_tag = 1
        let tag = tolower(tag)
      else
        let uppercase_tag = 0
      endif
    endif
    " Attribute context {{{
    if exists("b:attrcompl")
      unlet! b:attrcompl
      " Get last word, it should be attr name
      let attr = matchstr(context, '[^ ]\+\s*=\s*\(''[^'']*\|"[^"]*\)$')
      if attr == ''
          let attr = matchstr(context, '[^ ]*$')
      endif
      " Sort out style, class, and on* cases
      if context =~? "\\(on[a-z]\+\\|id\\|style\\|class\\)\\s*=\\s*[\"'{]$"
        " Id, class completion {{{
        if context =~? "\\(id\\|class\\)\\s*=\\s*[\"'][a-zA-Z0-9_ -]*$"
          if context =~? "class\\s*=\\s*[\"'][a-zA-Z0-9_ -]*$"
            let search_for = "class"
          elseif context =~? "id\\s*=\\s*[\"'][a-zA-Z0-9_ -]*$"
            let search_for = "id"
          endif
          let values = pugcomplete#CollectIdorClass(search_for, tag, context, after)

          " We need special version of sbase
          let classbase = matchstr(context, ".*[\"']")
          let classquote = matchstr(classbase, '.$')
          if search_for == 'class'
            let classquote = ''
          endif

          let entered_class = matchstr(attr, ".*=\\s*[\"']\\zs.*")

          for m in sort(values)
            if m =~? '^'.entered_class
              call add(res, m . classquote)
            elseif m =~? entered_class
              call add(res2, m . classquote)
            endif
          endfor

          return res + res2
        endif
        " }}}
        " Complete Inline styles " {{{
        if context =~? 'style\s*=\s*\%(["''][^"'']*\|{[^\}]*\)$'
          return csscomplete#CompleteCSS(0, context)
        endif
        " }}}
        " Complete on-events {{{
        if context =~? 'on[a-z]\+\s*=\s*\(''[^'']*\|"[^"]*\)$'
          " We have to:
          " 1. Find external files
          let b:js_extfiles = []
          let l = line('.')
          let c = col('.')
          call cursor(1,1)
          while search('\<script(', 'W') && line('.') <= l
            if synIDattr(synID(line('.'),col('.')-1,0),"name") !~? 'comment'
              let sname = matchstr(getline('.'), '\<script([^)]*src\s*=\s*\([''"]\)\zs.\{-}\ze\1')
              if filereadable(sname)
                let b:js_extfiles += readfile(sname)
              endif
            endif
          endwhile
          " 2. Find at least one <script> tag
          call cursor(1,1)
          let js_scripttags = []
          while search('\%(\<script.*\.\|-\)\s*$', 'W') != 0 && line('.') < l
            if matchstr(getline('.'), '\<script.*src') == ''
              let scriptend = line('.') + 1
              while ( indent(scriptend) > indent(line('.')) )
                let scriptend = scriptend + 1
              endwhile
              let js_scripttag = getline(line('.') + 1, scriptend - 1)
              let js_scripttags += js_scripttag
            endif
          endwhile
          let b:js_extfiles += js_scripttags

          " 3. Proper call for javascriptcomplete#CompleteJS
          call cursor(l,c)
          let js_context = matchstr(a:base, '\k\+$')
          let js_shortcontext = substitute(a:base, js_context.'$', '', '')
          let b:compl_context = context
          let b:jsrange = [l, l]
          unlet! l c
          return javascriptcomplete#CompleteJS(0, js_context)

        endif

        " }}}
        let stripbase = matchstr(context, ".*\\(on[a-zA-Z]*\\|style\\|class\\)\\s*=\\s*[\"']\\zs.*")
        " Now we have context stripped from all chars up to style/class.
        " It may fail with some strange style value combinations.
        if stripbase !~ "[\"']"
          return []
        endif
      endif
      " Value of attribute completion {{{
      " If attr contains =\s*[\"'] we catched value of attribute
      if attr =~ "=\s*[\"']" || attr =~ "=\s*$"
        " Let do attribute specific completion
        let attrname = matchstr(attr, '.*\ze\s*=')
        let entered_value = matchstr(attr, ".*=\\s*[\"']\\?\\zs.*")
        let values = []
        " Load data {{{
        if !exists("b:html_doctype")
          call pugcomplete#CheckDoctype()
        endif
        if !exists("b:html_omni")
          "runtime! autoload/xml/xhtml10s.vim
          call pugcomplete#LoadData()
        endif
        if g:aria_attributes_complete == 1 && !exists("b:aria_omni")
          call pugcomplete#LoadAria()
        endif
        " }}}
        if attrname == 'href'
          " Now we are looking for local anchors defined by name or id
          if entered_value =~ '^#'
            let file = join(getline(1, line('$')), ' ')
            " Split it be sure there will be one id/name element in
            " item, it will be also first word [a-zA-Z0-9_-] in element
            let oneelement = split(file, "\\(meta \\)\\@<!\\(name\\|id\\)\\s*=\\s*[\"']")
            for i in oneelement
              let values += ['#'.matchstr(i, "^[a-zA-Z][a-zA-Z0-9%_-]*")]
            endfor
          endif
        elseif attrname == 'class'
          let values = pugcomplete#CollectIdorClass('class', tag, context, after)
        else
          if has_key(b:html_omni, tag) && has_key(b:html_omni[tag][1], attrname)
            let values = b:html_omni[tag][1][attrname]
          elseif attrname =~ '^aria-' && exists("b:aria_omni") && has_key(b:aria_omni['aria_attributes'], attrname)
            let values = b:aria_omni['aria_attributes'][attrname]
          else
            return []
          endif
        endif
        if len(values) == 0
          return []
        endif

        " We need special version of sbase
        let attrbase = matchstr(context, ".*[\"']")
        let attrquote = matchstr(attrbase, '.$')
        if attrquote !~ "['\"]"
          let attrquoteopen = '"'
          let attrquote = '"'
        else
          let attrquoteopen = ''
        endif
        " Multi value attributes don't need ending quote
        let info = ''
        if has_key(b:html_omni['vimxmlattrinfo'], attrname)
          let info = b:html_omni['vimxmlattrinfo'][attrname][0]
        elseif exists("b:aria_omni") && has_key(b:aria_omni['vimariaattrinfo'], attrname)
          let info = b:aria_omni['vimariaattrinfo'][attrname][0]
        endif
        if info =~ "^\\*"
          let attrquote = ''
        endif
        if len(entered_value) > 0
          if entered_value =~ "\\s$"
            let entered_value = ''
          else
            let entered_value = split(entered_value)[-1]
          endif
        endif
        for m in sort(values)
          " This if is needed to not offer all completions as-is
          " alphabetically but sort them. Those beginning with entered
          " part will be as first choices
          if m =~ '^'.entered_value
            call add(res, attrquoteopen . m . attrquote)
          elseif m =~ entered_value
            call add(res2, attrquoteopen . m . attrquote)
          endif
        endfor

        return res + res2

      endif
      " }}}
      " Attribute completion {{{
      " Shorten context to not include last word
      let sbase = matchstr(context, '.*\ze\s.*')

      " Load data {{{
      if !exists("b:html_doctype")
        call pugcomplete#CheckDoctype()
      endif
      if !exists("b:html_omni")
        call pugcomplete#LoadData()
      endif
      if g:aria_attributes_complete == 1 && !exists("b:aria_omni")
        call pugcomplete#LoadAria()
      endif
      " }}}

      if has_key(b:html_omni, tag)
        let attrs = keys(b:html_omni[tag][1])
      else
        return []
      endif
      if exists("b:aria_omni")
        let roles = []
        if has_key(b:aria_omni['default_role'], tag)
          let roles = [b:aria_omni['default_role'][tag]]
        endif
        if context =~ 'role='
          let start = matchend(context, "role=['\"]")
          let end   = matchend(context, "[a-z ]\\+['\"]", start)
          if start != -1 && end != -1
            let roles = split(strpart(context, start, end-start-1), " ")
          endif
        endif
        for i in range(len(roles))
          let role = roles[i]
          if has_key(b:aria_omni['role_attributes'], role)
            let attrs = extend(attrs, b:aria_omni['role_attributes'][role])
          endif
        endfor
      endif

      for m in sort(attrs)
        if m =~ '^'.attr
          call add(res, m)
        elseif m =~ attr
          call add(res2, m)
        endif
      endfor
      let menu = res + res2
      if has_key(b:html_omni, 'vimxmlattrinfo') || (exists("b:aria_omni") && has_key(b:aria_omni, 'vimariaattrinfo'))
        let final_menu = []
        for i in range(len(menu))
          let item = menu[i]
          if has_key(b:html_omni['vimxmlattrinfo'], item)
            let m_menu = b:html_omni['vimxmlattrinfo'][item][0]
            let m_info = b:html_omni['vimxmlattrinfo'][item][1]
          elseif exists("b:aria_omni") && has_key(b:aria_omni['vimariaattrinfo'], item)
            let m_menu = b:aria_omni['vimariaattrinfo'][item][0]
            let m_info = b:aria_omni['vimariaattrinfo'][item][1]
          else
            let m_menu = ''
            let m_info = ''
          endif
          if item =~ '^aria-' && exists("b:aria_omni")
            if len(b:aria_omni['aria_attributes'][item]) > 0 && b:aria_omni['aria_attributes'][item][0] =~ '^\(BOOL\|'.item.'\)$'
              let item = item
              let m_menu = 'Bool'
            else
              let item .= '="'
            endif
          else
            if len(b:html_omni[tag][1][item]) > 0 && b:html_omni[tag][1][item][0] =~ '^\(BOOL\|'.item.'\)$'
              let item = item
              let m_menu = 'Bool'
            else
              let item .= '="'
            endif
          endif
          let final_menu += [{'word':item, 'menu':m_menu, 'info':m_info}]
        endfor
      else
        let final_menu = []
        for i in range(len(menu))
          let item = menu[i]
          if len(b:html_omni[tag][1][item]) > 0 && b:html_omni[tag][1][item][0] =~ '^\(BOOL\|'.item.'\)$'
            let item = item
          else
            let item .= '="'
          endif
          let final_menu += [item]
        endfor
        return final_menu
      endif
      return final_menu
      " }}}
    endif
    " }}}
    " Load data {{{
    if !exists("b:html_doctype")
      call pugcomplete#CheckDoctype()
    endif
    if !exists("b:html_omni")
      "runtime! autoload/xml/xhtml10s.vim
      call pugcomplete#LoadData()
    endif
    if g:aria_attributes_complete == 1 && !exists("b:aria_omni")
      call pugcomplete#LoadAria()
    endif
    " }}}
    " Custom Doctypes {{{
    if context =~ '^doctype\s\+html\s\+'
      let doctypes = [
          \ 'PUBLIC "-//W3C//DTD HTML 3.2 Final//EN"',
          \ 'PUBLIC "-//W3C//DTD HTML 4.0//EN" "http://www.w3.org/TR/REC-html40/strict.dtd"',
          \ 'PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd"',
          \ 'PUBLIC "-//W3C//DTD HTML 4.0 Frameset//EN" "http://www.w3.org/TR/REC-html40/frameset.dtd"',
          \ 'PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd"',
          \ 'PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd"',
          \ 'PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd"',
          \ 'PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"',
          \ 'PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"',
          \ 'PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd"',
          \ 'PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/1999/xhtml"'
          \ ]
      let entered_value = matchstr(context, '^doctype\s\+html\s\+\zs.*')
      for m in doctypes
        if m =~ '^'.entered_value
          call add(res, m)
        elseif m =~ entered_value
          call add(res2, m)
        endif
      endfor
      let menu = res + res2
      let final_menu = []
      for i in range(len(menu))
        let item = menu[i]
        let abbr = 'DOCTYPE '.matchstr(item, 'DTD \zsX\?HTML .\{-}\ze\/\/')
        let final_menu += [{'abbr':abbr, 'word':item}]
      endfor
      return final_menu
    endif
    " }}}
    " Doctype completion {{{
    if context =~ '^doctype\s\+'
      let doctypes = split('html xml transitional strict frameset 1.1 basic mobile plist')
      let entered_value = matchstr(context, '^doctype\s\+\zs')
      for m in doctypes
        if m =~ '^'.entered_value
          call add(res, m)
        elseif m =~ entered_value
          call add(res2, m)
        endif
      endfor
      return res + res2
    endif
    " }}}
    " Style tag {{{
    if context =~ '^style\s\+'
      return csscomplete#CompleteCSS(0, context)
    endif
    " }}}
    "Script tag {{{
    if context =~ '^\%(script\%((.*)\)\?\|-\)\s\+'
      return javascriptcomplete#CompleteJS(0, context)
    endif
    " }}}
    " block completion {{{
    if context =~ '\<\%(block\%( append\| prepend\)\?\|append\|prepend\)\>\s\+'
      let b:extfiles = []
      let l = line('.')
      let c = col('.')
      while search('\<extends\>\s\+', 'bW') && line('.') <= l
        if synIDattr(synID(line('.'),col('.')-1,0),"name") !~? 'comment'
          let b:extfiles += [matchstr(getline('.'), '\<extends\>\s\+\zs\f\+')]
        endif
      endwhile
      call cursor(l, c)
      let block = pugcomplete#CollectBlocks(b:extfiles)
      let entered_value = matchstr(context, '\<\%(block\%( append\| prepend\)\?\|append\|prepend\)\>\s\+\zs.*')
      for m in keys(block)
        if m =~ '^'.entered_value
          call add(res, m)
        elseif m =~ entered_value
          call add(res2, m)
        endif
      endfor
      let menu = res + res2
      let final_menu = []
      for i in range(len(menu))
        let item = menu[i]
        if has_key(block, item)
          let m_info = block[item]
        else
          let m_info = ''
        endif
        let final_menu += [{'word':item, 'menu':m_info}]
      endfor
      return final_menu
    endif
    " }}}
    " Id, class completion {{{
    if context =~? "[.#][a-zA-Z0-9_-]*$"
      if context =~? "#[a-zA-Z0-9_-]*$"
        let search_for = "id"
      elseif context =~? "\.[a-zA-Z0-9_-]*$"
        let search_for = "class"
      endif
      let values = pugcomplete#CollectIdorClass(search_for, tag, context, after)
      let entered_class = matchstr(context, '.*[.#]\zs.*')

      for m in sort(values)
        if m =~? '^'.entered_class
          call add(res, m)
        elseif m =~? entered_class
          call add(res2, m)
        endif
      endfor

      return res + res2
    endif
    " }}}
    " mixin completion {{{
    if context =~? '^+[a-zA-Z0-9_]*'
      let mixin = pugcomplete#CollectMixins(expand('%:t'))
      let entered_value = matchstr(context, '\s\++\zs')
      for m in mixin['names']
        if m =~ '^'.entered_value
          call add(res, m)
        elseif m =~ entered_value
          call add(res2, m)
        endif
      endfor
      let menu = res + res2
      let final_menu = []
      for i in range(len(menu))
        let item = menu[i]
        if has_key(mixin['infos'], item)
          let m_info = '('.mixin['infos'][item].')'
          let abbr = item
          let item = item . '('
        else
          let m_info = '()'
          let abbr = ''
        endif
        let final_menu += [{'word':item, 'menu':m_info, 'abbr':abbr}]
      endfor
      return final_menu
    endif
    " }}}
    " Filters completion {{{
    if context =~ '^\s*:.*'
      let filters = ['babel', 'less', 'uglify-js', 'scss', 'markdown-it', 'coffee-script']
      let entered_value = matchstr(context, ':\zs')
      for m in sort(filters)
        if m =~ '^'.entered_value
          call add(res, m)
        elseif m =~ entered_value
          call add(res2, m)
        endif
      endfor
      return res + res2
    endif
    " }}}
    " Tag completion {{{
    if parentTag == '' && !has_key(b:html_omni, parentTag)
      " Hack for sometimes failing GetLastparentTag.
      " As far as I tested fail isn't GLOT fault but problem
      " of invalid document - not properly closed tags and other mish-mash.
      " Also when document is empty. Return list of *all* tags.
      let tags = keys(b:html_omni)
      call filter(tags, 'v:val !~ "^vimxml"')
    else
      if has_key(b:html_omni, parentTag)
        let tags = b:html_omni[parentTag][0]
      else
        return []
      endif
    endif
    if stopper == 1
      return []
    endif

    if exists("uppercase_tag") && uppercase_tag == 1
      let context = tolower(context)
    endif

    if parentTag == ''
      let tags += ['doctype', 'extends']
    endif

    let entered_value = matchstr(context, '^\s*\zs.*')
    for m in tags
      if m =~ '^'. entered_value
        call add(res, m)
      elseif m =~ entered_value
        call add(res2, m)
      endif
    endfor
    let menu = res + res2
    if has_key(b:html_omni, 'vimxmltaginfo')
      let final_menu = []
      for i in range(len(menu))
        let item = menu[i]
        if has_key(b:html_omni['vimxmltaginfo'], item)
          let m_menu = b:html_omni['vimxmltaginfo'][item][0]
          let m_info = b:html_omni['vimxmltaginfo'][item][1]
        else
          let m_menu = ''
          let m_info = ''
        endif
        if exists("uppercase_tag") && uppercase_tag == 1
          let item = toupper(item)
        endif
        let final_menu += [{'word':item, 'menu':m_menu, 'info':m_info}]
      endfor
    else
      let final_menu = menu
    endif
    return final_menu
    " }}}
  endif
endfunction
" }}}

function! pugcomplete#LoadAria() " {{{
  runtime! autoload/xml/aria.vim
  if exists("g:xmldata_aria")
    \ && has_key(g:xmldata_aria, 'default_role')
    \ && has_key(g:xmldata_aria, 'role_attributes')
    \ && has_key(g:xmldata_aria, 'vimariaattrinfo')
    \ && has_key(g:xmldata_aria, 'aria_attributes')
    let b:aria_omni = g:xmldata_aria
  else
    let g:aria_attributes_complete = 0
  endif
endfunction
" }}}
function! pugcomplete#DetectOmniFlavor() " {{{
  let b:html_omni_flavor = 'html5'
  let b:html_doctype = 1
  let i = 1
  let line = ""
  while i < 10 && i < line("$")
    let line = getline(i)
    if line =~ '\s*doctype '
      break
    endif
    let i += 1
  endwhile
  if line =~ '\s*doctype '  " doctype line found above
    if line =~ ' HTML 3\.2'
      let b:html_omni_flavor = 'html32'
    elseif line =~ ' XHTML 1\.1' || line =~ ' 1.1'
      let b:html_omni_flavor = 'xhtml11'
    else    " two-step detection with strict/frameset/transitional
      if line =~ ' XHTML 1\.0'
        let b:html_omni_flavor = 'xhtml10'
      elseif line =~ ' HTML 4\.01'
        let b:html_omni_flavor = 'html401'
      elseif line =~ ' HTML 4.0\>'
        let b:html_omni_flavor = 'html40'
      elseif line =~ ' \<transitional\|frameset\|strict\>'
        let b:html_omni_flavor = 'xhtml10'
      endif
      if line =~ '\<[Tt]ransitional\>'
        let b:html_omni_flavor .= 't'
      elseif line =~ '\<[Ff]rameset\>'
        let b:html_omni_flavor .= 'f'
      elseif line =~ '\<[Ss]trict\>'
        let b:html_omni_flavor .= 's'
      endif
    endif
  endif
endfunction
" }}}
function! pugcomplete#LoadData() " {{{
  if !exists("b:html_omni_flavor")
    let b:html_omni_flavor = 'html5'
  endif
  " With that if we still have bloated memory but create new buffer
  " variables only by linking to existing g:variable, not sourcing whole
  " file.
  if exists('g:xmldata_'.b:html_omni_flavor)
    exe 'let b:html_omni = g:xmldata_'.b:html_omni_flavor
  else
    exe 'runtime! autoload/xml/'.b:html_omni_flavor.'.vim'
    exe 'let b:html_omni = g:xmldata_'.b:html_omni_flavor
  endif
endfunction
" }}}
function! pugcomplete#CheckDoctype() " {{{
  if exists('b:html_omni_flavor')
    let old_flavor = b:html_omni_flavor
  else
    let old_flavor = ''
  endif
  call pugcomplete#DetectOmniFlavor()
  if !exists('b:html_omni_flavor')
    return
  else
    " Tie g:xmldata with b:html_omni this way we need to sourca data file only
    " once, not every time per buffer.
    if old_flavor == b:html_omni_flavor
      return
    else
      if exists('g:xmldata_'.b:html_omni_flavor)
        exe 'let b:html_omni = g:xmldata_'.b:html_omni_flavor
      else
        exe 'runtime! autoload/xml/'.b:html_omni_flavor.'.vim'
        exe 'let b:html_omni = g:xmldata_'.b:html_omni_flavor
      endif
      return
    endif
  endif
endfunction
" }}}
function! pugcomplete#GetTag(context) " {{{
  if a:context =~ '^\s*[.#]'
    return 'div'
  else
    return matchstr(a:context, '^\s*\zs\w\+')
  endif
endfunction
" }}}
function! pugcomplete#GetParentTag() " {{{
  let cline = line('.')
  let tagline = cline - 1
  while ( tagline >= 1
        \ && getline(tagline) =~ '^\s*$'
        \ || getline(tagline) =~ '^\s*\<\%(-\||\|=\|for\|each\|while\|case\|when\|default\|if\|else\|unless\|extends\|block\|append\|prepend\|include\)\>'
        \ || getline(tagline) =~ '^\s*[|=-]'
        \ || getline(tagline) =~ '^\s*[^ (]\+\s*=\s*["'']'
        \ || ( indent(tagline) == indent(cline) && getline(tagline) !~ '^\s*):')
        \ || indent(tagline) > indent(cline))
    let tagline = tagline - 1
  endwhile
  if getline(tagline) =~ ':\s\+.\+$'
    if getline(tagline) =~ '\.\s*$'
      let b:pug_stopper = 1
    endif
    return pugcomplete#GetParentTagShort(getline(tagline), 1)
  else
    " let str = matchstr(getline(tagline), '^\s*\zs[^ (]*')
    " if str =~ '\.$'
    "   let b:pug_stopper = 1
    " endif
    if getline(tagline) =~ '^\s*:'
    \ || getline(tagline) =~ '\%(\.\|\/\/\)\s*$'
    \ || ( getline(prevnonblank(line('.'))) =~ '\.\s*$' && indent(prevnonblank(line('.'))) < indent(line('.')) )
      let b:pug_stopper = 1
    endif
    return pugcomplete#GetTag(getline(tagline))
  endif
endfunction
" }}}
function! pugcomplete#GetParentTagShort(context, item) " {{{
  let save_cursor = getpos('.')
  call cursor(line('.'), 1)
  execute "norm! ])"
  let col = col('.')
  let l = line('.')
  call setpos('.', save_cursor)
  let subcontext = substitute(a:context, '\(^.*\%'.col.'c\)\|(.\{-})', '', 'g')
  let list = split(subcontext, ':\ze ')
  let pTag = matchstr(list[len(list) - a:item], '^\s*\zs[.#]\?[0-9A-Za-z_-]\+')
  if (len(list) - 1 >= a:item && ( list[a:item] =~ '\.\s*$' || list[a:item] =~ '^\s*:' ))
    let b:pug_stopper = 1
    return ''
  endif
  if len(list) == 2 && list[a:item - 1] == ' '
    let pTag = pugcomplete#GetParentTag()
  endif
  if pTag =~ '^\s*[.#]'
    let pTag = 'div'
  endif
  return pTag
endfunction
" }}}
function! pugcomplete#CollectBlocks(extfiles) " {{{
  let blocks = {}
  for file in a:extfiles
    if filereadable(file)
      let filename = fnamemodify(file, ':t')
      let lines = readfile(file)
      let bls = filter(copy(lines), "v:val =~ '\\<block\\>'")
      let blnames = map(bls, "matchstr(v:val, '\\<block\\>\\s\\+\\zs\\w\\+')")
      for name in blnames
        let blocks[name] = filename
      endfor
      let exters = filter(copy(lines), "v:val =~ '\\<extends\\>'")
      let etfiles = map(exters, "matchstr(v:val, '\\<extends\\>\\s\\+\\zs\\f\\+')")
      if len(etfiles) > 0
        call extend(blocks, pugcomplete#CollectBlocks(etfiles))
      endif
    endif
  endfor
  return blocks
endfunction
" }}}
function! pugcomplete#CollectIdorClass(search_for, tag, context, after) " {{{
  " Handle class name completion
  " 1. Find lines of <link stylesheet>
  " 1a. Check file for @import
  " 2. Extract filename(s?) of stylesheet,
  let l = line('.')
  let c = col('.')
  call cursor(1,1)
  let headstart = search('\<head\>')
  if headstart == 0
    return []
  endif
  let headend = headstart + 1
  while indent(headend) > indent(headstart) || (getline(headend) =~ '^$' && headend < line('$') )
    let headend = headend + 1
  endwhile
  call cursor(l, c)
  let head = getline(headstart, headend)
  let headjoined = join(copy(head), ' ')
  if headjoined =~ '\<style\.'
    " Remove possibly confusing CSS operators
    let stylehead = substitute(headjoined, '+>\*[,', ' ', 'g')
    if a:search_for == 'class'
      let styleheadlines = split(stylehead)
      let headclasslines = filter(copy(styleheadlines), "v:val =~ '\\([a-zA-Z0-9:]\\+\\)\\?\\.[a-zA-Z0-9_-]\\+'")
    else
      let stylesheet = split(headjoined, '[{}]')
      " Get all lines which fit id syntax
      let classlines = filter(copy(stylesheet), "v:val =~ '#[a-zA-Z0-9_-]\\+'")
      " Filter out possible color definitions
      call filter(classlines, "v:val !~ ':\\s*#[a-zA-Z0-9_-]\\+'")
      " Filter out complex border definitions
      call filter(classlines, "v:val !~ '\\(none\\|hidden\\|dotted\\|dashed\\|solid\\|double\\|groove\\|ridge\\|inset\\|outset\\)\\s*#[a-zA-Z0-9_-]\\+'")
      let templines = join(classlines, ' ')
      let headclasslines = split(templines)
      call filter(headclasslines, "v:val =~ '#[a-zA-Z0-9_-]\\+'")
    endif
    let internal = 1
  else
    let internal = 0
  endif
  let styletable = []
  let secimportfiles = []
  let filestable = filter(copy(head), "v:val =~ '\\(@import\\|link.*stylesheet\\|include.*css\\)'")
  for line in filestable
    if line =~ "@import"
      let styletable += [matchstr(line, "import\\s\\+\\(url(\\)\\?[\"']\\?\\zs\\f\\+\\ze")]
    elseif line =~ "link("
      let styletable += [matchstr(line, "href\\s*=\\s*[\"']\\zs\\f\\+\\ze")]
    elseif line =~ "include"
      let styletable += [matchstr(line, "include\\s\\+\\zs\\f\\+\\ze")]
    endif
  endfor
  for file in styletable
    if filereadable(file)
      let stylesheet = readfile(file)
      let secimport = filter(copy(stylesheet), "v:val =~ '@import'")
      if len(secimport) > 0
        for line in secimport
          let secfile = matchstr(line, "import\\s\\+\\(url(\\)\\?[\"']\\?\\zs\\f\\+\\ze")
          let secfile = fnamemodify(file, ":p:h").'/'.secfile
          let secimportfiles += [secfile]
        endfor
      endif
    endif
  endfor
  let cssfiles = styletable + secimportfiles
  let classes = []
  for file in cssfiles
      let classlines = []
    if filereadable(file)
      let stylesheet = readfile(file)
      let stylefile = join(stylesheet, ' ')
      let stylefile = substitute(stylefile, '+>\*[,', ' ', 'g')
      if a:search_for == 'class'
        let stylesheet = split(stylefile)
        let classlines = filter(copy(stylesheet), "v:val =~ '\\([a-zA-Z0-9:]\\+\\)\\?\\.[a-zA-Z0-9_-]\\+'")
      else
        let stylesheet = split(stylefile, '[{}]')
        " Get all lines which fit id syntax
        let classlines = filter(copy(stylesheet), "v:val =~ '#[a-zA-Z0-9_-]\\+'")
        " Filter out possible color definitions
        call filter(classlines, "v:val !~ ':\\s*#[a-zA-Z0-9_-]\\+'")
        " Filter out complex border definitions
        call filter(classlines, "v:val !~ '\\(none\\|hidden\\|dotted\\|dashed\\|solid\\|double\\|groove\\|ridge\\|inset\\|outset\\)\\s*#[a-zA-Z0-9_-]\\+'")
        let templines = join(classlines, ' ')
        let stylelines = split(templines)
        let classlines = filter(stylelines, "v:val =~ '#[a-zA-Z0-9_-]\\+'")

      endif
    endif
    " We gathered classes definitions from all external files
    let classes += classlines
  endfor
  if internal == 1
    let classes += headclasslines
  endif

  if a:search_for == 'class'
    let elements = {}
    for element in classes
      if element =~ '^\.'
        let class = matchstr(element, '^\.\zs[a-zA-Z][a-zA-Z0-9_-]*\ze')
        let class = substitute(class, ':.*', '', '')
        if has_key(elements, 'common')
          let elements['common'] .= ' '.class
        else
          let elements['common'] = class
        endif
      else
        let class = matchstr(element, '[a-zA-Z1-6]*\.\zs[a-zA-Z][a-zA-Z0-9_-]*\ze')
        let tagname = tolower(matchstr(element, '[a-zA-Z1-6]*\ze.'))
        if tagname != ''
          if has_key(elements, tagname)
            let elements[tagname] .= ' '.class
          else
            let elements[tagname] = class
          endif
        endif
      endif
    endfor

    if has_key(elements, a:tag) && has_key(elements, 'common')
      let values = split(elements[a:tag]." ".elements['common'])
      " call pugcomplete#FilterClass(a:context, values)
    elseif has_key(elements, a:tag) && !has_key(elements, 'common')
      let values = split(elements[a:tag])
      " call pugcomplete#FilterClass(a:context, values)
    elseif !has_key(elements, a:tag) && has_key(elements, 'common')
      let values = split(elements['common'])
      " call pugcomplete#FilterClass(a:context, values)
    else
      return []
    endif

    call pugcomplete#FilterClass(a:context, a:after, values)

  elseif a:search_for == 'id'
    " Find used IDs
    " 1. Catch whole file
    let filelines = getline(1, line('$'))
    call remove(filelines, headstart-1, headend-1)
    " 2. Find lines with possible id
    let used_id_lines = filter(copy(filelines), 'v:val =~ "id\\s*=\\s*[\"''][a-zA-Z0-9_-]\\+"')
    let used_id_lines += filter(filelines, 'v:val =~ "#[a-zA-Z0-9_-]\\+"')
    " 3a. Join all filtered lines
    let id_string = join(used_id_lines, ' ')
    " 3b. And split them to be sure each id is in separate item
    let id_list = split(copy(id_string), 'id\s*=\s*')
    let id_literal_list = split(id_string, '\ze#')
    " 4. Extract id values
    let used_id = map(id_list, 'matchstr(v:val, "[\"'']\\zs[a-zA-Z0-9_-]\\+\\ze")')
    let used_id += map(id_literal_list, 'matchstr(v:val, "#\\zs[a-zA-Z0-9_-]\\+\\ze")')
    let joined_used_id = ','.join(used_id, ',').','

    let allvalues = map(classes, 'matchstr(v:val, ".*#\\zs[a-zA-Z0-9_-]\\+")')

    let values = []

    for element in classes
      if joined_used_id !~ ','.element.','
        let values += [element]
      endif

    endfor
    if a:context =~ '=[''"]'
      let savec = getpos('.')
      call search('(', 'bW')
      let strf = matchstr(getline('.'), '[0-9A-Za-z_.#-]\+\%' . col('.') . 'c')
      call setpos('.', savec)
      if strf =~ '#[a-zA-Z0-9_-]\+'
        let values = []
      endif
    else
      if a:after =~ 'id\s*=\s*[''"]\zs[a-zA-Z0-9_-]\+'
        let values = []
      endif
    endif
  endif
  return values
endfunction
" }}}
function! pugcomplete#CollectMixins(file) " {{{
  let res = {}
  let res['names'] = []
  let res['infos'] = {}
  let file = readfile(a:file)
  let mixins = filter(copy(file), 'v:val =~ "^\\s*mixin\\s\\+"')
  let arguments = copy(mixins)
  call map(mixins, 'matchstr(v:val, "^\\s*mixin\\s\\+\\zs\\k\\+")')
  let res['names'] += mixins
  for i in arguments
    let f_elements = matchlist(i, 'mixin\s\+\(\k\+\)\s*(\(.\{-}\))')
    if len(f_elements) >= 3
      let res['infos'][f_elements[1]] = f_elements[2]
    endif
  endfor
  let extends = filter(copy(file), 'v:val =~ "\\<extends\\>\\s\\+"')
  call map(extends, "matchstr(v:val, '\\<extends\\>\\s\\+\\zs\\f\\+')")
  if len(extends) > 0
    for f in extends
      let res['names'] += pugcomplete#CollectMixins(f)['names']
      call extend(res['infos'], pugcomplete#CollectMixins(f)['infos'])
    endfor
  endif
  return res
endfunction
" }}}
function! pugcomplete#OnEventsStart(context) " {{{
  let line = getline('.')
  let start = col('.') - 1
  if a:context =~? 'on[a-z]\+\s*=\s*\(''[^'']*\|"[^"]*\)$' || a:context =~? '\([''"]\)\?([a-z]\+)\1\s*=\s*\(''[^'']*\|"[^"]*\)$'
    while start >= 0 && line[start - 1] =~ '\k'
      let start -= 1
    endwhile
  endif
  return start
endfunction
" }}}
function! pugcomplete#FilterClass(context, after, values) " {{{
  if a:context =~ '=[''"]'
    let save_cursor = getpos('.')
    call search('(', 'bW')
    let strf = matchstr(getline('.'), '[0-9A-Za-z_.#-]\+\%' . col('.') . 'c')
    call setpos('.', save_cursor)
    let str = matchstr(a:context, '.*[''"]\zs.*')
    let str2 = matchstr(a:after, '[^''"]*')
    let first = split(strf, '\.')
    let left = split(str)
    let right = split(str2)
    let used_class = left + right + first
  else
    let str = matchstr(a:context, '.\{-}\.\zs.*')
    let str2 = matchstr(a:after, '[^ (:]*')
    let left = split(str, '\.')
    let right = split(str2, '\.')
    let used_class = left + right
  endif
  call map(used_class, "matchstr(v:val, '^[a-zA-Z0-9-_]\\+')")
  for i in used_class
    call filter(a:values, 'v:val != i')
  endfor
  return a:values
endfunction
" }}}

" vim:set foldmethod=marker:
