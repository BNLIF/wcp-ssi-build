function build_wirecell() {
  prep_build wirecell ${1} ${2}:${build_type} || return 0
  ./build_wirecell.sh ${product_topdir} ${2} ${build_type} ${maketar} >& "${logfile}"
}

# Local Variables:
# mode: sh
# eval: (sh-set-shell "bash")
# End:
