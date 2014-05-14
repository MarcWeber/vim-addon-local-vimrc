" vam#DefineAndBind('s:c','g:local_vimrc','{}')
if !exists('g:local_vimrc') | let g:local_vimrc = {} | endif | let s:c = g:local_vimrc

" using .vimrc because most systems support local and user global
" configuration files. They rarely differ in name.
" Users will instantly understand what it does.
let s:c.names = get(s:c,'names',['.vimrc'])

let s:c.hash_fun = get(s:c,'hash_fun','LVRHashOfFile')
let s:c.cache_file = get(s:c,'cache_file', $HOME.'/.vim_local_rc_cache')
let s:c.resource_on_cwd_change = get(s:c, 'resource_on_cwd_change', 1)
let s:last_cwd = ''
let s:cache_format_version=2            " Increment this on any format change

" Map return values from confirm() into our answer codes.
" If confirm() can't provide a good answer, it returns 0; hence we set
" [0] to a safe default.
"
" Besides these, there's also ANS_ASK, which is only used internally;
" it's written to the cache if the user gives a non-sticky answer.
let s:answer_map = ['ANS_NO', 'ANS_YES', 'ANS_ONCE', 'ANS_NO', 'ANS_NEVER']

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

" Ask the user; return one of the ANS_* strings.
" If they don't provide a useful answer, return dflt.
fun! LVRAsk(prompt, dflt)
    let ans = confirm(a:prompt,"&Yes\n&Once\n&No\nne&Ver", a:dflt)
    if 0 < ans
      return s:answer_map[ans]
    else
      return dflt
    endif
endfun

fun! LVRSaveAnswer(cache, key, hash, ans)
  if 'ANS_YES' == a:ans || 'ANS_NEVER' == a:ans
    let l:ans = a:ans
  else
    let l:ans = 'ANS_ASK'
  endif
  let ce = {'hash': a:hash, 'ans': l:ans}
  let a:cache[a:key] = ce
endf

" source local vimrc, ask user for confirmation if file contents change
fun! LVRSource(file, cache)
  " always ignore user global .vimrc which Vim sources on startup:
  if expand(a:file) == expand("~/.vimrc") | return | endif

  let p = expand(a:file)
  let h = call(function(s:c.hash_fun), [a:file, a:cache.seed])
  " if hash doesn't match or no hash exists ask user to confirm sourcing this file
  let ce = get(a:cache, p, {'hash':'no-hash', 'ans':'ANS_NO'})
  if ce['hash'] == h && ce['ans'] != 'ANS_ASK'
    let ans = ce['ans']
  else
    let ans = LVRAsk('source '.p,'ANS_NO')
  endif
  " source the file if so requested
  if 'ANS_YES' == ans || 'ANS_ONCE' == ans
    exec 'source '.fnameescape(p)
  endif
  call LVRSaveAnswer(a:cache, p, h, ans)
endf

fun! LVRWithCache(F, args)
  " for each computer use different unique seed based on time so that its
  " harder to find collisions
  let cache = filereadable(s:c.cache_file)
        \ ? eval(readfile(s:c.cache_file)[0])
        \ : {}
  let c = copy(cache)
  " if the cache isn't in the format we understand, just blow it away;
  " it's not valuable enough to be worth converting.
  " note that we do this whether the file's version is too low *or* too high;
  " in either case, we assume that we don't know how to interpret the contents.
  let ver = get(cache, 'format_version', -1)    " default should never match any real version number
  if ver != s:cache_format_version
    let cache = {'seed' : localtime(), 'format_version' : s:cache_format_version}
  endif
  let r = call(a:F, [cache]+a:args)
  if c != cache | call writefile([string(cache)], s:c.cache_file) | endif
  return r
endf

" find all local .vimrc in parent directories
fun! LVRRecurseUp(cache, dir, names)
  let s:last_cwd = a:dir
  let files = []
  for n in a:names
    let nr = 1
    while 1
      " ".;" does not work in the "vim ." case - why?
      " Thanks to github.com/jdonaldson (Justin Donaldso) for finding this issue
      " The alternative fix would be calling SourceLocalVimrcOnce
      " at VimEnter, however I feel that you cannot setup additional VimEnter
      " commands then - thus preferring getcwd()
      let f = findfile(n, escape(getcwd(), "\ ").";", nr)
      if f == '' | break | endif
      call add(files, fnamemodify(f,':p'))
      let nr += 1
    endwhile
  endfor
  call map(reverse(files), 'LVRSource(v:val, a:cache)')
endf

" find and source files on vim startup:
command! SourceLocalVimrc call LVRWithCache('LVRRecurseUp', [getcwd(), s:c.names] )
command! SourceLocalVimrcOnce
    \ if s:c.resource_on_cwd_change && s:last_cwd != getcwd()
    \ | call LVRWithCache('LVRRecurseUp', [getcwd(), s:c.names] )
    \ | endif

SourceLocalVimrcOnce

" if its you writing a file update hash automatically
fun! LVRUpdateCache(cache)
  let f = expand('%:p')
  call LVRSaveAnswer(a:cache, f, call(function(s:c.hash_fun), [f, a:cache.seed]),
    \ 'ANS_ALWAYS')
endf

augroup LOCAL_VIMRC
  " If the current file is a local .vimrc file and you're writing it
  " automatically update the cache
  autocmd BufWritePost * if index(s:c.names, expand('%:t')) >= 0 | call LVRWithCache('LVRUpdateCache', [] ) | endif

  " If autochdir is not set, then resource local vimrc files if current
  " directory has changed. There is no event for signaling change of current
  " directory - so this is only an approximation to what people might expect.
  " Idle events and the like would be an alternative
  if ! &autochdir
    autocmd BufNewFile,BufRead * SourceLocalVimrcOnce
  endif
augroup end
