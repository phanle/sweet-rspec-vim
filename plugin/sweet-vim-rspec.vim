" Find the path to this script so that the links
" to formatter don't need to be hard coded.
if !exists('g:SweetVimRspecPlugin')
  let g:SweetVimRspecPlugin = fnamemodify(expand("<sfile>"), ":p:h") 
endif

function! SweetVimRspecRun(kind)
  echomsg "Running Specs: "
  sleep 10m " Sleep long enough so MacVim redraws the screen so you can see the above message

  if !exists('g:SweetVimRspecUseBundler')
    let g:SweetVimRspecUseBundler = 1
  endif

  if !exists('t:SweetVimRspecVersion')
    let l:cmd = ""
    if g:SweetVimRspecUseBundler == 1
      let l:cmd .= "bundle exec "
    endif
    let l:cmd .=  "spec --version 2>/dev/null"
    " Execute the spec --version command which, if returns without error
    " means that the version of rspec is ONE otherwise assume rspec2
    cgete system( l:cmd ) 
    let t:SweetVimRspecVersion = v:shell_error == 0 ? 1 : 2
  endif

  if !exists('t:SweetVimRspecExecutable') || empty(t:SweetVimRspecExecutable)
    let t:SweetVimRspecExecutable =  g:SweetVimRspecUseBundler == 0 ? "" : "bundle exec " 
    if  t:SweetVimRspecVersion  > 1
      let t:SweetVimRspecExecutable .= "rspec -r " . g:SweetVimRspecPlugin . "/sweet_vim_rspec2_formatter.rb" . " -f RSpec::Core::Formatters::SweetVimRspecFormatter "
    else
      let t:SweetVimRspecExecutable .= "spec -br " . g:SweetVimRspecPlugin . "/sweet_vim_rspec1_formatter.rb" . " -f Spec::Runner::Formatter::SweetVimRspecFormatter "
    endif
  endif
  
  if a:kind !=  "Previous" 
    let t:SweetVimRspecTarget = expand("%:p") . " " 
    if a:kind == "Focused"
      let t:SweetVimRspecTarget .=  "-l " . line(".") . " " 
    endif
  endif

  if !exists('t:SweetVimRspecTarget')
    echo "Run a Spec first"
    return
  endif

  cclose

  if exists('g:SweetVimRspecErrorFile') 
    execute 'silent! bdelete ' .  g:SweetVimRspecErrorFile
  endif

  let g:SweetVimRspecErrorFile = tempname()
  execute 'silent! wall'
  cgete s:PollingSystemCall(t:SweetVimRspecExecutable . t:SweetVimRspecTarget . " 2>" . g:SweetVimRspecErrorFile)
  sleep 400m " Opening the cwindow clears the output in the message buffer, delay it a bit so you can actually read it
  botright cwindow
  cw
  setlocal foldmethod=marker
  setlocal foldmarker=+-+,-+-

  if getfsize(g:SweetVimRspecErrorFile) > 0 
    execute 'silent! split ' . g:SweetVimRspecErrorFile
    setlocal buftype=nofile
  endif

  call delete(g:SweetVimRspecErrorFile)

  let l:oldCmdHeight = &cmdheight
  let &cmdheight = 2
  let &cmdheight = l:oldCmdHeight
endfunction

function! s:PollingSystemCall(systemcall)
  " TODO: Prints that are embedded in tests are making trouble, somehow redirect them?
  let progress_length = 0
  let output_file = tempname()
  let pid = system(a:systemcall . " > " . output_file . " & echo $!") " the echo $! returns the process id
  let running = 1
  while running 
    let progress =  system("cat " . output_file . " | head -1")
    let old_length = progress_length
    let progress_length = strlen(progress)
    let new_output = strpart(progress, old_length, progress_length - old_length)
    call s:ColoredOutput(substitute(new_output, "\n", "", "")) " remove line breaks before coloring
    let running = len(split(system("ps -p ".pid),"\n")) > 1 " the ps command displays column headings and below the info about the process, if it only returns one line the process does not exist
    sleep 100m
  endwhile
  echohl Special | echon " √Done" | echohl Normal
  let result = readfile(output_file)[1:] " Omitting the first line, since it contains the progress indicators
  call delete(output_file)
  return result
endfunction

function! s:ColoredOutput(string)
  let i = 0
  while i < len(a:string)
    let char = strpart(a:string, i, 1)
    if(char == "F")
      echohl WarningMsg
    elseif (char == "*")
      echohl Todo
    elseif (char == ".")
      echohl Special
    end
    echon char
    let i += 1
    echohl Normal
  endwhile
endfunction

command! SweetVimRspecRunFile call SweetVimRspecRun("File")
command! SweetVimRspecRunFocused call SweetVimRspecRun("Focused")
command! SweetVimRspecRunPrevious call SweetVimRspecRun("Previous")
