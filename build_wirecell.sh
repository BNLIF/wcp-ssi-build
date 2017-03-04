#!/bin/bash
#

usage()
{
   echo "USAGE: `basename ${0}` <product_dir> <e14|e10> <debug|prof> [tar]"
}

# -------------------------------------------------------------------
# shared boilerplate
# -------------------------------------------------------------------

get_this_dir() 
{
    ( cd / ; /bin/pwd -P ) >/dev/null 2>&1
    if (( $? == 0 )); then
      pwd_P_arg="-P"
    fi
    reldir=`dirname ${0}`
    thisdir=`cd ${reldir} && /bin/pwd ${pwd_P_arg}`
}

get_ssibuildshims()
{
    # make sure we can use the setup alias
    if [ -z ${UPS_DIR} ]
    then
       echo "ERROR: please setup ups"
       exit 1
    fi
    source `${UPS_DIR}/bin/ups setup ${SETUP_UPS}`
    
    setup ssibuildshims ${ssibuildshims_version} -z ${product_dir}
}

# -------------------------------------------------------------------
# start processing
# -------------------------------------------------------------------

product_dir=${1}
basequal=${2}
extraqual=${3}
maketar=${4}

if [ -z ${product_dir} ]
then
   echo "ERROR: please specify the local product directory"
   usage
   exit 1
fi

# -------------------------------------------------------------------
# package name and version
# -------------------------------------------------------------------

package=wirecell
origpkgver=v0_0_3
pkgver=${origpkgver}a
ssibuildshims_version=v0_15_09
pkgdotver=`echo ${origpkgver} | sed -e 's/_/./g' | sed -e 's/^v//'`
pkgtarfile=${package}-${pkgdotver}.tar.bz2

get_this_dir

get_ssibuildshims

source define_basics

if [ "${maketar}" = "tar" ] && [ -d ${pkgdir}/bin ]
then
   ${SSIBUILDSHIMS_DIR}/bin/make_distribution_tarball ${product_dir} ${package} ${pkgver} ${fullqual}
   exit 0
fi

echo "building ${package} for ${OS}-${plat}-${qualdir} (flavor ${flvr})"

# -------------------------------------------------------------------
# package dependent stuff goes here
# -------------------------------------------------------------------

case ${extraqual} in
debug) cflg="-g -O0";;
prof)  cflg="-O3 -g -DNDEBUG -fno-omit-frame-pointer";;
* )
   echo "ERROR: please specify debug or prof"
   usage
   exit 1
;;
esac

if [[ "${basequal}" == e1[024] ]]
then
  cxxflg="${cflg} -std=c++14"
else
  ssi_die "Qualifier $basequal not recognized."
fi

mkdir -p ${pkgdir}
if [ ! -d ${pkgdir} ]
then
   echo "ERROR: failed to create ${pkgdir}"
   exit 1
fi

# declare now so we can setup
# fake ups declare
fakedb=${product_dir}/${package}/${pkgver}/fakedb
${SSIBUILDSHIMS_DIR}/bin/fake_declare_product ${product_dir} ${package} ${pkgver} ${fullqual}

setup -B ${package} ${pkgver} -q ${fullqual} -z ${fakedb}:${product_dir}:${PRODUCTS} || ssi_die "fake setup failed"

set -x
cd ${pkgdir} || exit 1
tar xf ${tardir}/${pkgtarfile} || exit 1
# patch
patch -b -p0 < ${patchdir}/wirecell.patch  || ssi_die "Failed to apply patch"

cd ${pkgdir}/wire-cell-build || exit 1

env CC=gcc CXX=g++ FC=gfortran ./wcb configure \
      --with-jsoncpp ${JSONCPP_FQ_DIR} \
      --with-tbb ${TBB_FQ_DIR} \
      --with-eigen  ${EIGEN_DIR} \
      --with-root ${ROOTSYS} \
      --boost-includes ${BOOST_INC} \
      --boost-libs ${BOOST_LIB} \
      --boost-mt \
      --prefix="${pkgdir}"
(( $? == 0 )) || ssi_die "wcb configure failed."

./wcb build install || exit 1

# run tests
./wcb --alltests --testcmd="env LD_LIBRARY_PATH=$WCT_EXTERNALS/lib:`pwd`/install/lib %s" || ssi_die "tests failed"

set +x

if [ ! -d ${pkgdir}/bin ]
then
   echo "ERROR: failed to create ${pkgdir}/bin"
   echo "       Something is very wrong"
   exit 1
fi

# real ups declare
${SSIBUILDSHIMS_DIR}/bin/declare_product ${product_dir} ${package} ${pkgver} ${fullqual}

# -------------------------------------------------------------------
# common bottom stuff
# -------------------------------------------------------------------

# this should not complain
echo "Finished building ${package} ${pkgver}"
setup ${package} ${pkgver} -q ${fullqual} -z ${product_dir}:${PRODUCTS}
echo "wirecell is installed at ${WIRECELL_FQ_DIR}"

# this must be last
if [ "${maketar}" = "tar" ] && [ -d ${pkgdir}/bin ]
then
   ${SSIBUILDSHIMS_DIR}/bin/make_distribution_tarball ${product_dir} ${package} ${pkgver} ${fullqual}
fi

exit 0
