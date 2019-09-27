function build_wcp() {
  prep_build wcp ${1} ${2}:${build_type} || return 0
  ./build_wcp.sh ${product_topdir} ${2} ${build_type} ${maketar} >& "${logfile}"
}

# Local Variables:
# mode: sh
# eval: (sh-set-shell "bash")
# End:
