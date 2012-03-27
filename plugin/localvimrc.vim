" vam#DefineAndBind('s:c','g:local_vimrc','{}')
if !exists('g:local_vimrc') | let g:local_vimrc = {} | endif | let s:c = g:local_vimrc

" using .vimrc because most systems support local and user global
" configuration files. They rarely differ in name.
" Users will instantly understand what it does.
let s:c.names = get(s:c,'names',['.vimrc'])

let s:c.hash_fun = get(s:c,'hash_fun','LVRHashOfFile')
let s:c.cache_file = get(s:c,'cache_file', $HOME.'/.vim_local_rc_cache')

" very simple hash function using md5 falling back to VimL implementation
fun! LVRHashOfFile(file, seed)
  if executable('md5sum')
    return system('md5sum '.shellescape(a:file))
  else
    let s = join(readfile(a:file,"\n"))
    " poor mans hash function. I don't expect it to be very secure.
    let sum = a:seed
    for i in range(0,len(s)-1)
      let sum = ((sum + char2nr(s[i]) * i) - i) / 2
    endfor
    return sum.''
  endif
endfun

" source local vimrc, ask user for confirmation if file contents change
fun! LVRSource(file, cache)
  " always ignore user global .vimrc which Vim sources on startup:
  if expand(a:file) == expand("~/.vimrc") | return | endif

  let p = expand(a:file)
  let h = call(function(s:c.hash_fun), [a:file, a:cache.seed])
  " if hash doesn't match or no hash exists ask user to confirm sourcing this file
  if get(a:cache, p, 'no-hash') == h || 1 == confirm('source '.p,"&Y\n&n",2)
    let a:cache[p] = h
    exec 'source '.fnameescape(p)
  endif
endf

fun! LVRWithCache(F, args)
  " for each computer use different unique seed based on time so that its
  " horder to find collisions
  let cache = filereadable(s:c.cache_file)
        \ ? eval(readfile(s:c.cache_file)[0])
        \ : {'seed':localtime()}
  let c = copy(cache)
  let r = call(a:F, [cache]+a:args)
  if c != cache | call writefile([string(cache)], s:c.cache_file) | endif
  return r
endf

" find all local .vimrc in parent directories
fun! LVRRecurseUp(cache, dir, names)
  let files = []
  for n in a:names
    let nr = 1
    while 1
      let f = findfile(n, ".;", nr)
      if f == '' | break | endif
      call add(files, fnamemodify(f,':p'))
      let nr += 1
    endwhile
  endfor
  call map(reverse(files), 'LVRSource(v:val, a:cache)')
endf

" find and source files on vim startup:
call LVRWithCache('LVRRecurseUp', [getcwd(), s:c.names] )

" if its you writing a file update hash automatically
fun! LVRUpdateCache(cache)
  let f = expand('%:p')
  let a:cache[f] = call(function(s:c.hash_fun), [f, a:cache.seed])
endf

augroup LOCAL_VIMRC
  autocmd BufWritePost * if index(s:c.names, expand('%:t')) >= 0 | call LVRWithCache('LVRUpdateCache', [] ) | endif
augroup end
