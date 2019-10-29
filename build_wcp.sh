#!/bin/bash
#

usage()
{
   echo "USAGE: `basename ${0}` <product_dir> <e17|c2>[:py3] <debug|prof> [tar]"
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

    cd ${product_dir}
    echo "setup ssibuildshims ${ssibuildshims_version} -z ${product_dir}"
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

package=wcp
origpkgver=v00_12_00
pkgver=${origpkgver}
#pkgdotver=`echo ${origpkgver} | sed -e 's/_/./g' | sed -e 's/^v//'`
pkgdotver=`echo ${origpkgver}`
ssibuildshims_version=v1_04_13

srcname=${package}-${pkgdotver}
pkgtarfile=${srcname}.tar.bz2

get_this_dir

get_ssibuildshims

source define_basics --

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
debug) 
   cflg="-g -O0"
   ;;
prof)  cflg="-O3 -g -DNDEBUG -fno-omit-frame-pointer";;
* )
   echo "ERROR: please specify debug or prof"
   usage
   exit 1
;;
esac

if [[ "${basequal}" == e1[0245] ]]
then
  cc=gcc
  cxx=g++
  cxxflg="${cflg} -std=c++14"
elif [[ "${basequal}" == e1[79] ]] || [[ "${basequal}" == e1[79]:py3 ]]
then
  cc=gcc
  cxx=g++
  cxxflg="${cflg} -std=c++17"
elif [[ "${basequal}" == e1[79]:py3 ]] || [[ "${basequal}" == e1[79]:py3 ]]
then
  cc=gcc
  cxx=g++
  cxxflg="${cflg} -std=c++17"
elif [[ "${basequal}" == c[27] ]] || [[ "${basequal}" == c[27]:py3 ]]
then
  cc=clang
  cxx=clang++
  cxxflg="${cflg} -std=c++17"
elif [[ "${basequal}" == c[27]:py3 ]] || [[ "${basequal}" == c[27]:py3 ]]
then
  cc=clang
  cxx=clang++
  cxxflg="${cflg} -std=c++17"
else
  ssi_die "Qualifier $basequal not recognized."
fi

if [ "${OS1}" = "Darwin" ]
then
  macos_extras="--with-zlib=/usr"
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

cd ${product_dir}
setup -B ${package} ${pkgver} -f ${flvr} -q ${fullqual} -z ${fakedb}:${product_dir}:${PRODUCTS} || ssi_die "fake setup failed"

if [ -z ${EIGEN_DIR} ]
then
   echo "ERROR: failed to setup eigen"
   exit 1
else
   echo "EIGEN_DIR: ${EIGEN_DIR}"
fi
if [ -z ${ROOTSYS} ]
then
   echo "ERROR: failed to setup root"
   exit 1
else
   echo "ROOTSYS: ${ROOTSYS}"
fi

set -x
cd ${pkgdir} || exit 1
tar xf ${tardir}/${pkgtarfile} || exit 1

cd ${pkgdir}/${srcname} || exit 1
#patch -b -p1 < "${patchdir}/${srcname}.patch" || ssi_die "application of patch ${patchdir}/${srcname}.patch failed."

echo $PKG_CONFIG_PATH

env CC=${cc} CXX=${cxx} FC=gfortran ./waf-tools/waf configure \
    --with-root="$ROOTSYS" \
    --boost-includes="$BOOST_INC" \
    --boost-libs="$BOOST_LIB" \
    --boost-mt \
    --with-fftw="$FFTW_FQ_DIR" \
    --with-fftw-include="$FFTW_INC" \
    --with-fftw-lib="$FFTW_LIBRARY" \
    --with-eigen="$EIGEN_DIR" \
    --prefix="${pkgdir}"
(( $? == 0 )) || ssi_die "wcb configure failed."

# add -vv to this line for verbose output
./waf-tools/waf --notests -j 4 build install || exit 1

# run tests.  Note, wcb does not return failure if some tests fail.
#./waf-tools/waf --alltests

# Remove intermediate build and test products so they don't get
# included in the copy of the source that goes into the final UPS
# product.  Ignoring this adds more than 1GB of useless cruft.
cd ${pkgdir}/${srcname} || exit 1
if [[ "${OS1}" == "Darwin" ]] && [[ "${extraqual}" == "debug" ]]; then
  # keep the object files for macOS debugging ...
  rm -rf util/test_*json*
else
  rm -rf build util/test_*json*
fi

if [ ! -d ${pkgdir}/bin ]
then
   echo "ERROR: failed to create ${pkgdir}/bin"
   echo "       Something is very wrong"
   exit 1
fi

set +x

# real ups declare
cd ${product_dir}
${SSIBUILDSHIMS_DIR}/bin/declare_product ${product_dir} ${package} ${pkgver} ${fullqual} || \
  ssi_die "failed to declare ${package} ${pkgver} ${fullqual}"

# -------------------------------------------------------------------
# common bottom stuff
# -------------------------------------------------------------------

# this should not complain
echo "Finished building ${package} ${pkgver}"
cd ${product_dir}
setup ${package} ${pkgver} -q ${fullqual} -z ${product_dir}:${PRODUCTS}
echo "wcp is installed at ${WCP_FQ_DIR}"

# this must be last
if [ "${maketar}" = "tar" ] && [ -d ${pkgdir}/bin ]
then
   cd ${product_dir}
   ${SSIBUILDSHIMS_DIR}/bin/make_distribution_tarball ${product_dir} ${package} ${pkgver} ${fullqual}
fi

exit 0
