# xvlog -> xelab -> xsim; merge tool logs into SIM_OUT_DIR/compile_run.log
# Env: REPO_ROOT SIM_OUT_DIR SIM_BUILD_DIR SIM_TOP SIM_FILELIST SIM_INCDIR SIM_PLUSARGS

proc win_path {path} {
  set p [file normalize $path]
  if {[regexp {^/([a-zA-Z])/(.*)$} $p -> d rest]} {
    return "[string toupper $d]:/$rest"
  }
  return $p
}

proc resolve_path {repo path} {
  if {[string index $path 0] eq "/" || [regexp {^[A-Za-z]:} $path]} {
    return [win_path $path]
  }
  return [win_path [file join $repo $path]]
}

proc parse_flist {repo flist_path srcs incs} {
  upvar $srcs s
  upvar $incs i
  set fp [open $flist_path r]
  while {[gets $fp line] >= 0} {
    set line [string trim $line]
    set line [string map {"\r" ""} $line]
    if {$line eq "" || [string match "#*" $line]} continue
    if {[string match "+incdir+*" $line]} {
      lappend i [resolve_path $repo [string range $line 8 end]]
    } elseif {[string match "-f *" $line]} {
      parse_flist $repo [resolve_path $repo [string range $line 3 end]] srcs incs
    } else {
      lappend s [resolve_path $repo $line]
    }
  }
  close $fp
}

set repo  [win_path $env(REPO_ROOT)]
set out   [win_path $env(SIM_OUT_DIR)]
set build [win_path $env(SIM_BUILD_DIR)]
set top   $env(SIM_TOP)
set pargs $env(SIM_PLUSARGS)
set flist [win_path $env(SIM_FILELIST)]
set log   [file join $out compile_run.log]
set scratch [file join $build .scratch]

set srcs {}
set incs {}
parse_flist $repo $flist srcs incs
if {[info exists env(SIM_INCDIR)] && $env(SIM_INCDIR) ne ""} {
  lappend incs [win_path $env(SIM_INCDIR)]
}

file mkdir $out $build $scratch
file delete -force $log

proc append_log {tag toollog merged} {
  set fh [open $merged a]
  puts $fh "\n=== $tag ==="
  if {[file exists $toollog]} {
    set t [open $toollog r]
    puts $fh [read $t]
    close $t
  }
  close $fh
}

proc run_stage {tag cmd toollog merged} {
  if {[catch {eval exec $cmd} err]} {
    append_log $tag $toollog $merged
    puts stderr $err
    exit 1
  }
  append_log $tag $toollog $merged
}

cd $build

set xvl [file join $scratch xvlog.log]
set xv [list xvlog -sv --incr --relax -work work]
foreach idir $incs { lappend xv -i $idir }
foreach s $srcs { lappend xv $s }
lappend xv --log $xvl
run_stage xvlog $xv $xvl $log

set xel [file join $scratch xelab.log]
set xe [list xelab work.${top} -s ${top}_sim --log $xel]
run_stage xelab $xe $xel $log

set xsl [file join $scratch xsim.log]
set xs [list xsim ${top}_sim -runall --log $xsl]
foreach a [split $pargs "|"] { if {$a ne ""} { lappend xs -testplusarg $a } }
run_stage xsim $xs $xsl $log

file delete -force $scratch
