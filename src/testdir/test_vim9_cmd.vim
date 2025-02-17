" Test commands that are not compiled in a :def function

source check.vim
source vim9.vim
source term_util.vim
source view_util.vim

def Test_vim9cmd()
  var lines =<< trim END
    vim9cmd var x = 123
    let s:y = 'yes'
    vim9c assert_equal(123, x)
    vim9cm assert_equal('yes', y)
  END
  CheckScriptSuccess(lines)

  assert_fails('vim9cmd', 'E1164:')
  assert_fails('legacy', 'E1234:')
  assert_fails('vim9cmd echo "con" . "cat"', 'E15:')

  lines =<< trim END
      let str = 'con'
      vim9cmd str .= 'cat'
  END
  CheckScriptFailure(lines, 'E492:')

  lines =<< trim END
      vim9script
      legacy echo "con" . "cat"
      legacy let str = 'con'
      legacy let str .= 'cat'
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
      vim9script
      def Foo()
        g:found_bar = "bar"
      enddef
      nmap ,; :vim9cmd <SID>Foo()<CR>
  END
  CheckScriptSuccess(lines)

  feedkeys(',;', 'xt')
  assert_equal("bar", g:found_bar)
  nunmap ,;
  unlet g:found_bar

  lines =<< trim END
      vim9script
      legacy echo 1'000
  END
  CheckScriptFailure(lines, 'E115:')

  if has('float')
    lines =<< trim END
        vim9script
        echo .10
    END
    CheckScriptSuccess(lines)
    lines =<< trim END
        vim9cmd echo .10
    END
    CheckScriptSuccess(lines)
    lines =<< trim END
        vim9script
        legacy echo .10
    END
    CheckScriptFailure(lines, 'E15:')
  endif

  echo v:version
  assert_fails('vim9cmd echo version', 'E121:')
  lines =<< trim END
      vim9script
      echo version
  END
  CheckScriptFailure(lines, 'E121:')
  lines =<< trim END
      vim9script
      legacy echo version
  END
  CheckScriptSuccess(lines)
enddef

def Test_edit_wildcards()
  var filename = 'Xtest'
  edit `=filename`
  assert_equal('Xtest', bufname())

  var filenr = 123
  edit Xtest`=filenr`
  assert_equal('Xtest123', bufname())

  filenr = 77
  edit `=filename``=filenr`
  assert_equal('Xtest77', bufname())

  edit X`=filename`xx`=filenr`yy
  assert_equal('XXtestxx77yy', bufname())

  CheckDefFailure(['edit `=xxx`'], 'E1001:')
  CheckDefFailure(['edit `="foo"'], 'E1083:')

  var files = ['file 1', 'file%2', 'file# 3']
  args `=files`
  assert_equal(files, argv())
enddef

def Test_expand_alternate_file()
  var lines =<< trim END
    edit Xfileone
    var bone = bufnr()
    edit Xfiletwo
    var btwo = bufnr()
    edit Xfilethree
    var bthree = bufnr()

    edit #
    assert_equal(bthree, bufnr())
    edit %%
    assert_equal(btwo, bufnr())
    edit %% # comment
    assert_equal(bthree, bufnr())
    edit %%yy
    assert_equal('Xfiletwoyy', bufname())

    exe "edit %%" .. bone
    assert_equal(bone, bufnr())
    exe "edit %%" .. btwo .. "xx"
    assert_equal('Xfiletwoxx', bufname())

    next Xfileone Xfiletwo Xfilethree
    assert_equal('Xfileone', argv(0))
    assert_equal('Xfiletwo', argv(1))
    assert_equal('Xfilethree', argv(2))
    next %%%zz
    assert_equal('Xfileone', argv(0))
    assert_equal('Xfiletwo', argv(1))
    assert_equal('Xfilethreezz', argv(2))

    v:oldfiles = ['Xonefile', 'Xtwofile']
    edit %%<1
    assert_equal('Xonefile', bufname())
    edit %%<2
    assert_equal('Xtwofile', bufname())
    assert_fails('edit %%<3', 'E684:')

    edit Xfileone.vim
    edit Xfiletwo
    edit %%:r
    assert_equal('Xfileone', bufname())

    assert_false(bufexists('altfoo'))
    edit altfoo
    edit bar
    assert_true(bufexists('altfoo'))
    assert_true(buflisted('altfoo'))
    bdel %%
    assert_true(bufexists('altfoo'))
    assert_false(buflisted('altfoo'))
    bwipe! altfoo
    bwipe! bar
  END
  CheckDefAndScriptSuccess(lines)
enddef

def Test_global_backtick_expansion()
  new
  setline(1, 'xx')
  var name = 'foobar'
  g/^xx/s/.*/`=name`
  assert_equal('foobar', getline(1))
  bwipe!
enddef

def Test_folddo_backtick_expansion()
  new
  var name = 'xxx'
  folddoopen edit `=name`
  assert_equal('xxx', bufname())
  bwipe!

  new
  setline(1, ['one', 'two'])
  set nomodified
  :1,2fold
  foldclose
  folddoclose edit `=name`
  assert_equal('xxx', bufname())
  bwipe!
enddef

def Test_hardcopy_wildcards()
  CheckUnix
  CheckFeature postscript

  var outfile = 'print'
  hardcopy > X`=outfile`.ps
  assert_true(filereadable('Xprint.ps'))

  delete('Xprint.ps')
enddef

def Test_syn_include_wildcards()
  writefile(['syn keyword Found found'], 'Xthemine.vim')
  var save_rtp = &rtp
  &rtp = '.'

  var fname = 'mine'
  syn include @Group Xthe`=fname`.vim
  assert_match('Found.* contained found', execute('syn list Found'))

  &rtp = save_rtp
  delete('Xthemine.vim')
enddef

def Test_echo_linebreak()
  var lines =<< trim END
      vim9script
      redir @a
      echo 'one'
            .. 'two'
      redir END
      assert_equal("\nonetwo", @a)
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
      vim9script
      redir @a
      echo 11 +
            77
            - 22
      redir END
      assert_equal("\n66", @a)
  END
  CheckScriptSuccess(lines)
enddef

def Test_condition_types()
  var lines =<< trim END
      if 'text'
      endif
  END
  CheckDefAndScriptFailure(lines, 'E1135:', 1)

  lines =<< trim END
      if [1]
      endif
  END
  CheckDefFailure(lines, 'E1012:', 1)
  CheckScriptFailure(['vim9script'] + lines, 'E745:', 2)

  lines =<< trim END
      g:cond = 'text'
      if g:cond
      endif
  END
  CheckDefExecAndScriptFailure(lines, 'E1135:', 2)

  lines =<< trim END
      g:cond = 0
      if g:cond
      elseif 'text'
      endif
  END
  CheckDefFailure(lines, 'E1012:', 3)
  CheckScriptFailure(['vim9script'] + lines, 'E1135:', 4)

  lines =<< trim END
      if g:cond
      elseif [1]
      endif
  END
  CheckDefFailure(lines, 'E1012:', 2)
  CheckScriptFailure(['vim9script'] + lines, 'E745:', 3)

  lines =<< trim END
      g:cond = 'text'
      if 0
      elseif g:cond
      endif
  END
  CheckDefExecAndScriptFailure(lines, 'E1135:', 3)

  lines =<< trim END
      while 'text'
      endwhile
  END
  CheckDefFailure(lines, 'E1012:', 1)
  CheckScriptFailure(['vim9script'] + lines, 'E1135:', 2)

  lines =<< trim END
      while [1]
      endwhile
  END
  CheckDefFailure(lines, 'E1012:', 1)
  CheckScriptFailure(['vim9script'] + lines, 'E745:', 2)

  lines =<< trim END
      g:cond = 'text'
      while g:cond
      endwhile
  END
  CheckDefExecAndScriptFailure(lines, 'E1135:', 2)
enddef

def Test_if_linebreak()
  var lines =<< trim END
      vim9script
      if 1 &&
            true
            || 1
        g:res = 42
      endif
      assert_equal(42, g:res)
  END
  CheckScriptSuccess(lines)
  unlet g:res

  lines =<< trim END
      vim9script
      if 1 &&
            0
        g:res = 0
      elseif 0 ||
              0
              || 1
        g:res = 12
      endif
      assert_equal(12, g:res)
  END
  CheckScriptSuccess(lines)
  unlet g:res
enddef

def Test_while_linebreak()
  var lines =<< trim END
      vim9script
      var nr = 0
      while nr <
              10 + 3
            nr = nr
                  + 4
      endwhile
      assert_equal(16, nr)
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
      vim9script
      var nr = 0
      while nr
            <
              10
              +
              3
            nr = nr
                  +
                  4
      endwhile
      assert_equal(16, nr)
  END
  CheckScriptSuccess(lines)
enddef

def Test_for_linebreak()
  var lines =<< trim END
      vim9script
      var nr = 0
      for x
            in
              [1, 2, 3, 4]
          nr = nr + x
      endfor
      assert_equal(10, nr)
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
      vim9script
      var nr = 0
      for x
            in
              [1, 2,
                  3, 4
                  ]
          nr = nr
                 +
                  x
      endfor
      assert_equal(10, nr)
  END
  CheckScriptSuccess(lines)
enddef

def MethodAfterLinebreak(arg: string)
  arg
    ->setline(1)
enddef

def Test_method_call_linebreak()
  var lines =<< trim END
      vim9script
      var res = []
      func RetArg(
            arg
            )
            let s:res = a:arg
      endfunc
      [1,
          2,
          3]->RetArg()
      assert_equal([1, 2, 3], res)
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
      new
      var name = [1, 2]
      name
          ->copy()
          ->setline(1)
      assert_equal(['1', '2'], getline(1, 2))
      bwipe!
  END
  CheckDefAndScriptSuccess(lines)

  lines =<< trim END
      new
      def Foo(): string
        return 'the text'
      enddef
      def Bar(F: func): string
        return F()
      enddef
      def Test()
        Foo  ->Bar()
             ->setline(1)
      enddef
      Test()
      assert_equal('the text', getline(1))
      bwipe!
  END
  CheckDefAndScriptSuccess(lines)

  lines =<< trim END
      new
      g:shortlist
          ->copy()
          ->setline(1)
      assert_equal(['1', '2'], getline(1, 2))
      bwipe!
  END
  g:shortlist = [1, 2]
  CheckDefAndScriptSuccess(lines)
  unlet g:shortlist

  new
  MethodAfterLinebreak('foobar')
  assert_equal('foobar', getline(1))
  bwipe!

  lines =<< trim END
      vim9script
      def Foo(): string
          return '# some text'
      enddef

      def Bar(F: func): string
          return F()
      enddef

      Foo->Bar()
         ->setline(1)
  END
  CheckScriptSuccess(lines)
  assert_equal('# some text', getline(1))
  bwipe!
enddef

def Test_method_call_whitespace()
  var lines =<< trim END
    new
    var yank = 'text'
    yank->setline(1)
    yank  ->setline(2)
    yank->  setline(3)
    yank  ->  setline(4)
    assert_equal(['text', 'text', 'text', 'text'], getline(1, 4))
    bwipe!
  END
  CheckDefAndScriptSuccess(lines)
enddef

def Test_method_and_user_command()
  var lines =<< trim END
      vim9script
      def Cmd()
        g:didFunc = 1
      enddef
      command Cmd g:didCmd = 1
      Cmd
      assert_equal(1, g:didCmd)
      Cmd()
      assert_equal(1, g:didFunc)
      unlet g:didFunc
      unlet g:didCmd

      def InDefFunc()
        Cmd
        assert_equal(1, g:didCmd)
        Cmd()
        assert_equal(1, g:didFunc)
        unlet g:didFunc
        unlet g:didCmd
      enddef
      InDefFunc()
  END
  CheckScriptSuccess(lines)
enddef

def Test_option_use_linebreak()
  var lines =<< trim END
      new
      &matchpairs = '(:)'
      &matchpairs->setline(1)
      &matchpairs = '[:]'
      &matchpairs   ->setline(2)
      &matchpairs = '{:}'
      &matchpairs  
          ->setline(3)
      assert_equal(['(:)', '[:]', '{:}'], getline(1, '$'))
      bwipe!
  END
  CheckDefAndScriptSuccess(lines)
enddef

def Test_skipped_expr_linebreak()
  if 0
    var x = []
               ->map(() => 0)
  endif
enddef

def Test_dict_member()
   var test: dict<list<number>> = {data: [3, 1, 2]}
   test.data->sort()
   assert_equal({data: [1, 2, 3]}, test)
   test.data
      ->reverse()
   assert_equal({data: [3, 2, 1]}, test)

  var lines =<< trim END
      vim9script
      var test: dict<list<number>> = {data: [3, 1, 2]}
      test.data->sort()
      assert_equal({data: [1, 2, 3]}, test)
  END
  CheckScriptSuccess(lines)
enddef

def Test_bar_after_command()
  def RedrawAndEcho()
    var x = 'did redraw'
    redraw | echo x
  enddef
  RedrawAndEcho()
  assert_match('did redraw', Screenline(&lines))

  def CallAndEcho()
    var x = 'did redraw'
    reg_executing() | echo x
  enddef
  CallAndEcho()
  assert_match('did redraw', Screenline(&lines))

  if has('unix')
    # bar in filter write command does not start new command
    def WriteToShell()
      new
      setline(1, 'some text')
      w !cat | cat > Xoutfile
      bwipe!
    enddef
    WriteToShell()
    assert_equal(['some text'], readfile('Xoutfile'))
    delete('Xoutfile')

    # bar in filter read command does not start new command
    def ReadFromShell()
      new
      r! echo hello there | cat > Xoutfile
      r !echo again | cat >> Xoutfile
      bwipe!
    enddef
    ReadFromShell()
    assert_equal(['hello there', 'again'], readfile('Xoutfile'))
    delete('Xoutfile')
  endif
enddef

def Test_filter_is_not_modifier()
  var tags = [{a: 1, b: 2}, {x: 3, y: 4}]
  filter(tags, ( _, v) => has_key(v, 'x') ? 1 : 0 )
  assert_equal([{x: 3, y: 4}], tags)
enddef

def Test_command_modifier_filter()
  var lines =<< trim END
    final expected = "\nType Name Content\n  c  \"c   piyo"
    @a = 'hoge'
    @b = 'fuga'
    @c = 'piyo'

    assert_equal(execute('filter /piyo/ registers abc'), expected)
  END
  CheckDefAndScriptSuccess(lines)

  # also do this compiled
  lines =<< trim END
      @a = 'very specific z3d37dh234 string'
      filter z3d37dh234 registers
      assert_match('very specific z3d37dh234 string', Screenline(&lines))
  END
  CheckDefAndScriptSuccess(lines)
enddef

def Test_win_command_modifiers()
  assert_equal(1, winnr('$'))

  set splitright
  vsplit
  assert_equal(2, winnr())
  close
  aboveleft vsplit
  assert_equal(1, winnr())
  close
  set splitright&

  vsplit
  assert_equal(1, winnr())
  close
  belowright vsplit
  assert_equal(2, winnr())
  close
  rightbelow vsplit
  assert_equal(2, winnr())
  close

  if has('browse')
    browse set
    assert_equal('option-window', expand('%'))
    close
  endif

  vsplit
  botright split
  assert_equal(3, winnr())
  assert_equal(&columns, winwidth(0))
  close
  close

  vsplit
  topleft split
  assert_equal(1, winnr())
  assert_equal(&columns, winwidth(0))
  close
  close

  gettabinfo()->len()->assert_equal(1)
  tab split
  gettabinfo()->len()->assert_equal(2)
  tabclose

  vertical new
  assert_inrange(&columns / 2 - 2, &columns / 2 + 1, winwidth(0))
  close
enddef

func Test_command_modifier_confirm()
  CheckNotGui
  CheckRunVimInTerminal

  " Test for saving all the modified buffers
  let lines =<< trim END
    call setline(1, 'changed')
    def Getout()
      confirm write Xfile
    enddef
  END
  call writefile(lines, 'Xconfirmscript')
  call writefile(['empty'], 'Xfile')
  let buf = RunVimInTerminal('-S Xconfirmscript', {'rows': 8})
  call term_sendkeys(buf, ":call Getout()\n")
  call WaitForAssert({-> assert_match('(Y)es, \[N\]o: ', term_getline(buf, 8))}, 1000)
  call term_sendkeys(buf, "y")
  call WaitForAssert({-> assert_match('(Y)es, \[N\]o: ', term_getline(buf, 8))}, 1000)
  call term_sendkeys(buf, "\<CR>")
  call TermWait(buf)
  call StopVimInTerminal(buf)

  call assert_equal(['changed'], readfile('Xfile'))
  call delete('Xfile')
  call delete('.Xfile.swp')  " in case Vim was killed
  call delete('Xconfirmscript')
endfunc

def Test_command_modifiers_keep()
  if has('unix')
    def DoTest(addRflag: bool, keepMarks: bool, hasMarks: bool)
      new
      setline(1, ['one', 'two', 'three'])
      normal 1Gma
      normal 2Gmb
      normal 3Gmc
      if addRflag
        set cpo+=R
      else
        set cpo-=R
      endif
      if keepMarks
        keepmarks :%!cat
      else
        :%!cat
      endif
      if hasMarks
        assert_equal(1, line("'a"))
        assert_equal(2, line("'b"))
        assert_equal(3, line("'c"))
      else
        assert_equal(0, line("'a"))
        assert_equal(0, line("'b"))
        assert_equal(0, line("'c"))
      endif
      quit!
    enddef
    DoTest(false, false, true)
    DoTest(true, false, false)
    DoTest(false, true, true)
    DoTest(true, true, true)
    set cpo&vim

    new
    setline(1, ['one', 'two', 'three', 'four'])
    assert_equal(4, line("$"))
    normal 1Gma
    normal 2Gmb
    normal 3Gmc
    lockmarks :1,2!wc
    # line is deleted, marks don't move
    assert_equal(3, line("$"))
    assert_equal('four', getline(3))
    assert_equal(1, line("'a"))
    assert_equal(2, line("'b"))
    assert_equal(3, line("'c"))
    quit!
  endif

  edit Xone
  edit Xtwo
  assert_equal('Xone', expand('#'))
  keepalt edit Xthree
  assert_equal('Xone', expand('#'))

  normal /a*b*
  assert_equal('a*b*', histget("search"))
  keeppatterns normal /c*d*
  assert_equal('a*b*', histget("search"))

  new
  setline(1, range(10))
  :10
  normal gg
  assert_equal(10, getpos("''")[1])
  keepjumps normal 5G
  assert_equal(10, getpos("''")[1])
  quit!
enddef

def Test_bar_line_continuation()
  var lines =<< trim END
      au BufNewFile Xfile g:readFile = 1
          | g:readExtra = 2
      g:readFile = 0
      g:readExtra = 0
      edit Xfile
      assert_equal(1, g:readFile)
      assert_equal(2, g:readExtra)
      bwipe!
      au! BufNewFile

      au BufNewFile Xfile g:readFile = 1
          | g:readExtra = 2
          | g:readMore = 3
      g:readFile = 0
      g:readExtra = 0
      g:readMore = 0
      edit Xfile
      assert_equal(1, g:readFile)
      assert_equal(2, g:readExtra)
      assert_equal(3, g:readMore)
      bwipe!
      au! BufNewFile
      unlet g:readFile
      unlet g:readExtra
      unlet g:readMore
  END
  CheckDefAndScriptSuccess(lines)
enddef

def Test_command_modifier_other()
  new Xsomefile
  setline(1, 'changed')
  var buf = bufnr()
  hide edit Xotherfile
  var info = getbufinfo(buf)
  assert_equal(1, info[0].hidden)
  assert_equal(1, info[0].changed)
  edit Xsomefile
  bwipe!

  au BufNewFile Xfile g:readFile = 1
  g:readFile = 0
  edit Xfile
  assert_equal(1, g:readFile)
  bwipe!
  g:readFile = 0
  noautocmd edit Xfile
  assert_equal(0, g:readFile)
  au! BufNewFile
  unlet g:readFile

  noswapfile edit XnoSwap
  assert_equal(false, &l:swapfile)
  bwipe!

  var caught = false
  try
    sandbox !ls
  catch /E48:/
    caught = true
  endtry
  assert_true(caught)

  :8verbose g:verbose_now = &verbose
  assert_equal(8, g:verbose_now)
  unlet g:verbose_now
enddef

def EchoHere()
  echomsg 'here'
enddef
def EchoThere()
  unsilent echomsg 'there'
enddef

def Test_modifier_silent_unsilent()
  echomsg 'last one'
  silent echomsg "text"
  assert_equal("\nlast one", execute(':1messages'))

  silent! echoerr "error"

  echomsg 'last one'
  silent EchoHere()
  assert_equal("\nlast one", execute(':1messages'))

  silent EchoThere()
  assert_equal("\nthere", execute(':1messages'))

  try
    silent eval [][0]
  catch
    echomsg "caught"
  endtry
  assert_equal("\ncaught", execute(':1messages'))

  var lines =<< trim END
      vim9script
      set history=11
      silent! while 0
        set history=22
      silent! endwhile
      assert_equal(11, &history)
      set history&
  END
  CheckScriptSuccess(lines)
enddef

def Test_range_after_command_modifier()
  CheckScriptFailure(['vim9script', 'silent keepjump 1d _'], 'E1050: Colon required before a range: 1d _', 2)
  new
  setline(1, 'xxx')
  CheckScriptSuccess(['vim9script', 'silent keepjump :1d _'])
  assert_equal('', getline(1))
  bwipe!
enddef

def Test_silent_pattern()
  new
  silent! :/pat/put _
  bwipe!
enddef

def Test_useless_command_modifier()
  g:maybe = true
  var lines =<< trim END
      if g:maybe
      silent endif
  END
  CheckDefAndScriptFailure(lines, 'E1176:', 2)

  lines =<< trim END
      for i in [0]
      silent endfor
  END
  CheckDefFailure(lines, 'E1176:', 2)
  CheckScriptSuccess(['vim9script'] + lines)

  lines =<< trim END
      while g:maybe
      silent endwhile
  END
  CheckDefFailure(lines, 'E1176:', 2)
  g:maybe = false
  CheckScriptSuccess(['vim9script'] + lines)

  lines =<< trim END
      silent try
      finally
      endtry
  END
  CheckDefAndScriptFailure(lines, 'E1176:', 1)

  lines =<< trim END
      try
      silent catch
      endtry
  END
  CheckDefAndScriptFailure(lines, 'E1176:', 2)

  lines =<< trim END
      try
      silent finally
      endtry
  END
  CheckDefAndScriptFailure(lines, 'E1176:', 2)

  lines =<< trim END
      try
      finally
      silent endtry
  END
  CheckDefAndScriptFailure(lines, 'E1176:', 3)
enddef

def Test_eval_command()
  var from = 3
  var to = 5
  g:val = 111
  def Increment(nrs: list<number>)
    for nr in nrs
      g:val += nr
    endfor
  enddef
  eval range(from, to)
        ->Increment()
  assert_equal(111 + 3 + 4 + 5, g:val)
  unlet g:val

  var lines =<< trim END
    vim9script
    g:caught = 'no'
    try
      eval 123 || 0
    catch
      g:caught = 'yes'
    endtry
    assert_equal('yes', g:caught)
    unlet g:caught
  END
  CheckScriptSuccess(lines)
enddef

def Test_map_command()
  var lines =<< trim END
      nnoremap <F3> :echo 'hit F3 #'<CR>
      assert_equal(":echo 'hit F3 #'<CR>", maparg("<F3>", "n"))
  END
  CheckDefSuccess(lines)
  CheckScriptSuccess(['vim9script'] + lines)
enddef

def Test_normal_command()
  new
  setline(1, 'doesnotexist')
  var caught = 0
  try
    exe "norm! \<C-]>"
  catch /E433/
    caught = 2
  endtry
  assert_equal(2, caught)

  try
    exe "norm! 3\<C-]>"
  catch /E433/
    caught = 3
  endtry
  assert_equal(3, caught)
  bwipe!
enddef

def Test_put_command()
  new
  @p = 'ppp'
  put p
  assert_equal('ppp', getline(2))

  put ='below'
  assert_equal('below', getline(3))
  put! ='above'
  assert_equal('above', getline(3))
  assert_equal('below', getline(4))

  :2put =['a', 'b', 'c']
  assert_equal(['ppp', 'a', 'b', 'c', 'above'], getline(2, 6))

  # compute range at runtime
  setline(1, range(1, 8))
  @a = 'aaa'
  :$-2put a
  assert_equal('aaa', getline(7))

  setline(1, range(1, 8))
  :2
  :+2put! a
  assert_equal('aaa', getline(4))

  []->mapnew(() => 0)
  :$put ='end'
  assert_equal('end', getline('$'))

  bwipe!

  CheckDefFailure(['put =xxx'], 'E1001:')
enddef

def Test_put_with_linebreak()
  new
  var lines =<< trim END
    vim9script
    pu =split('abc', '\zs')
            ->join()
  END
  CheckScriptSuccess(lines)
  getline(2)->assert_equal('a b c')
  bwipe!
enddef

def Test_command_star_range()
  new
  setline(1, ['xxx foo xxx', 'xxx bar xxx', 'xxx foo xx bar'])
  setpos("'<", [0, 1, 0, 0])
  setpos("'>", [0, 3, 0, 0])
  :*s/\(foo\|bar\)/baz/g
  getline(1, 3)->assert_equal(['xxx baz xxx', 'xxx baz xxx', 'xxx baz xx baz'])

  bwipe!
enddef

def Test_f_args()
  var lines =<< trim END
    vim9script

    func SaveCmdArgs(...)
      let g:args = a:000
    endfunc

    command -nargs=* TestFArgs call SaveCmdArgs(<f-args>)

    TestFArgs
    assert_equal([], g:args)

    TestFArgs one two three
    assert_equal(['one', 'two', 'three'], g:args)
  END
  CheckScriptSuccess(lines)
enddef

def Test_user_command_comment()
  command -nargs=1 Comd echom <q-args>

  var lines =<< trim END
      vim9script
      Comd # comment
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
      vim9script
      Comd# comment
  END
  CheckScriptFailure(lines, 'E1144:')
  delcommand Comd

  lines =<< trim END
      vim9script
      command Foo echo 'Foo'
      Foo3Bar
  END
  CheckScriptFailure(lines, 'E1144: Command "Foo" is not followed by white space: Foo3Bar')

  delcommand Foo
enddef

def Test_star_command()
  var lines =<< trim END
    vim9script
    @s = 'g:success = 8'
    set cpo+=*
    exe '*s'
    assert_equal(8, g:success)
    unlet g:success
    set cpo-=*
    assert_fails("exe '*s'", 'E1050:')
  END
  CheckScriptSuccess(lines)
enddef

def Test_cmd_argument_without_colon()
  new Xfile
  setline(1, ['a', 'b', 'c', 'd'])
  write
  edit +3 %
  assert_equal(3, getcurpos()[1])
  edit +/a %
  assert_equal(1, getcurpos()[1])
  bwipe
  delete('Xfile')
enddef

def Test_ambiguous_user_cmd()
  command Cmd1 eval 0
  command Cmd2 eval 0
  var lines =<< trim END
      Cmd
  END
  CheckDefAndScriptFailure(lines, 'E464:', 1)
  delcommand Cmd1
  delcommand Cmd2
enddef

def Test_command_not_recognized()
  var lines =<< trim END
    d.key = 'asdf'
  END
  CheckDefFailure(lines, 'E1146:', 1)

  lines =<< trim END
    d['key'] = 'asdf'
  END
  CheckDefFailure(lines, 'E1146:', 1)
enddef

def Test_magic_not_used()
  new
  for cmd in ['set magic', 'set nomagic']
    exe cmd
    setline(1, 'aaa')
    s/.../bbb/
    assert_equal('bbb', getline(1))
  endfor

  set magic
  setline(1, 'aaa')
  assert_fails('s/.\M../bbb/', 'E486:')
  assert_fails('snomagic/.../bbb/', 'E486:')
  assert_equal('aaa', getline(1))

  bwipe!
enddef

def Test_gdefault_not_used()
  new
  for cmd in ['set gdefault', 'set nogdefault']
    exe cmd
    setline(1, 'aaa')
    s/./b/
    assert_equal('baa', getline(1))
  endfor

  set nogdefault
  bwipe!
enddef

def g:SomeComplFunc(findstart: number, base: string): any
  if findstart
    return 0
  else
    return ['aaa', 'bbb']
  endif
enddef

def Test_insert_complete()
  # this was running into an error with the matchparen hack
  new
  set completefunc=SomeComplFunc
  feedkeys("i\<c-x>\<c-u>\<Esc>", 'ntx')
  assert_equal('aaa', getline(1))

  set completefunc=
  bwipe!
enddef

def Test_wincmd()
  split
  var id1 = win_getid()
  if true
    try | wincmd w | catch | endtry
  endif
  assert_notequal(id1, win_getid())
  close

  split
  var id = win_getid()
  split
  :2wincmd o
  assert_equal(id, win_getid())
  only

  split
  split
  assert_equal(3, winnr('$'))
  :2wincmd c
  assert_equal(2, winnr('$'))
  only

  split
  split
  assert_equal(3, winnr('$'))
  :2wincmd q
  assert_equal(2, winnr('$'))
  only
enddef

def Test_windo_missing_endif()
  var lines =<< trim END
      windo if 1
  END
  CheckDefExecFailure(lines, 'E171:', 1)
enddef

let s:theList = [1, 2, 3]

def Test_lockvar()
  s:theList[1] = 22
  assert_equal([1, 22, 3], s:theList)
  lockvar s:theList
  assert_fails('theList[1] = 77', 'E741:')
  unlockvar s:theList
  s:theList[1] = 44
  assert_equal([1, 44, 3], s:theList)

  var d = {a: 1, b: 2}
  d.a = 3
  d.b = 4
  assert_equal({a: 3, b: 4}, d)
  lockvar d.a
  d.b = 5
  var ex = ''
  try
    d.a = 6
  catch
    ex = v:exception
  endtry
  assert_match('E1121:', ex)
  unlockvar d.a
  d.a = 7
  assert_equal({a: 7, b: 5}, d)

  var lines =<< trim END
      vim9script
      var theList = [1, 2, 3]
      def SetList()
        theList[1] = 22
        assert_equal([1, 22, 3], theList)
        lockvar theList
        theList[1] = 77
      enddef
      SetList()
  END
  CheckScriptFailure(lines, 'E1119', 4)

  lines =<< trim END
      var theList = [1, 2, 3]
      lockvar theList
  END
  CheckDefFailure(lines, 'E1178', 2)

  lines =<< trim END
      var theList = [1, 2, 3]
      unlockvar theList
  END
  CheckDefFailure(lines, 'E1178', 2)
enddef

def Test_substitute_expr()
  var to = 'repl'
  new
  setline(1, 'one from two')
  s/from/\=to
  assert_equal('one repl two', getline(1))

  setline(1, 'one from two')
  s/from/\=to .. '_x'
  assert_equal('one repl_x two', getline(1))

  setline(1, 'one from two from three')
  var also = 'also'
  s/from/\=to .. '_' .. also/g#e
  assert_equal('one repl_also two repl_also three', getline(1))

  setline(1, 'abc abc abc')
  for choice in [true, false]
    :1s/abc/\=choice ? 'yes' : 'no'/
  endfor
  assert_equal('yes no abc', getline(1))

  bwipe!

  CheckDefFailure(['s/from/\="x")/'], 'E488:')
  CheckDefFailure(['s/from/\="x"/9'], 'E488:')

  # When calling a function the right instruction list needs to be restored.
  g:cond = true
  var lines =<< trim END
      vim9script
      def Foo()
          Bar([])
      enddef
      def Bar(l: list<number>)
        if g:cond
          s/^/\=Rep()/
          for n in l[:]
          endfor
        endif
      enddef
      def Rep(): string
          return 'rep'
      enddef
      new
      Foo()
      assert_equal('rep', getline(1))
      bwipe!
  END
  CheckScriptSuccess(lines)
  unlet g:cond

  # List results in multiple lines
  new
  setline(1, 'some text here')
  s/text/\=['aaa', 'bbb', 'ccc']/
  assert_equal(['some aaa', 'bbb', 'ccc', ' here'], getline(1, '$'))
  bwipe!
enddef

def Test_redir_to_var()
  var result: string
  redir => result
    echo 'something'
  redir END
  assert_equal("\nsomething", result)

  redir =>> result
    echo 'more'
  redir END
  assert_equal("\nsomething\nmore", result)

  var d: dict<string>
  redir => d.redir
    echo 'dict'
  redir END
  assert_equal({redir: "\ndict"}, d)

  var l = ['a', 'b', 'c']
  redir => l[1]
    echo 'list'
  redir END
  assert_equal(['a', "\nlist", 'c'], l)

  var dl = {l: ['x']}
  redir => dl.l[0]
    echo 'dict-list'
  redir END
  assert_equal({l: ["\ndict-list"]}, dl)

  redir =>> d.redir
    echo 'more'
  redir END
  assert_equal({redir: "\ndict\nmore"}, d)

  var lines =<< trim END
    redir => notexist
  END
  CheckDefFailure(lines, 'E1089:')

  lines =<< trim END
    var ls = 'asdf'
    redir => ls[1]
    redir END
  END
  CheckDefFailure(lines, 'E1141:')
enddef

def Test_echo_void()
  var lines =<< trim END
      vim9script
      def NoReturn()
        echo 'nothing'
      enddef
      echo NoReturn()
  END
  CheckScriptFailure(lines, 'E1186:', 5)

  lines =<< trim END
      vim9script
      def NoReturn()
        echo 'nothing'
      enddef
      def Try()
        echo NoReturn()
      enddef
      defcompile
  END
  CheckScriptFailure(lines, 'E1186:', 1)
enddef

def Test_cmdwin_block()
  augroup justTesting
    autocmd BufEnter * {
      echomsg 'in block'
    }
  augroup END
  feedkeys('q:', 'xt')
  redraw
  feedkeys("aclose\<CR>", 'xt')

  au! justTesting
enddef


" vim: ts=8 sw=2 sts=2 expandtab tw=80 fdm=marker
