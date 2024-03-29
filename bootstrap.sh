#!/bin/bash

# use the bootstrap script to build a source code distribution

usage()
{
   echo "USAGE: `basename ${0}` <product_dir>"
   echo "       `basename ${0}` installs the source code distribution and creates the source code tarball"
}

get_this_dir() 
{
    ( cd / ; /bin/pwd -P ) >/dev/null 2>&1
    if (( $? == 0 )); then
      pwd_P_arg="-P"
    fi
    reldir=`dirname ${0}`
    thisdir=`cd ${reldir} && /bin/pwd ${pwd_P_arg}`
}

ensure_ssibuildshims()
{
    cd ${product_dir}
    ssidotver=`echo ${ssibuildshims_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
    if  ups exist ssibuildshims ${ssibuildshims_version} -z ${product_dir} >/dev/null 2>&1; then
       echo "ssibuildshims ${ssibuildshims_version} is already installed"
       ups list -aK+ ssibuildshims ${ssibuildshims_version} -z ${product_dir}
    else
       echo "Installing ssibuildshims ${ssibuildshims_version}"
       wget http://scisoft.fnal.gov/scisoft/packages/ssibuildshims/${ssibuildshims_version}/ssibuildshims-${ssidotver}-noarch.tar.bz2
       tar xjf ssibuildshims-${ssidotver}-noarch.tar.bz2 || exit 1
    fi
}

product_dir=${1}

if [ -z ${product_dir} ]
then
   echo "ERROR: please specify the product directory"
   usage
   exit 1
fi

package=wcp
origpkgver=v00_12_00
pkgver=${origpkgver}
ssibuildshims_version=v1_04_13
#pkgdotver=`echo ${origpkgver} | sed -e 's/_/./g' | sed -e 's/^v//'`
pkgdotver=`echo ${origpkgver}`
sourceurl=https://github.com/BNLIF/wire-cell.git
srcname="wcp-${pkgdotver}"

get_this_dir

if [ -z ${UPS_DIR} ]
then
   echo "ERROR: please setup ups"
   exit 1
fi

ensure_ssibuildshims

source `${UPS_DIR}/bin/ups setup ssibuildshims ${ssibuildshims_version} -z ${product_dir}`

if [ -z ${SSIBUILDSHIMS_DIR} ]
then
   echo "ERROR: failed to setup ssibuildshims"
   exit 1
fi

echo "calling ${SSIBUILDSHIMS_DIR}/bin/make_source_code_base"

${SSIBUILDSHIMS_DIR}/bin/make_source_code_base ${product_dir} \
                                               ${package} \
                                               ${pkgver} \
                                               ${thisdir}

pkgdir=${product_dir}/${package}/${pkgver}
if [ ! -d ${pkgdir}/tar ]
then
   echo "ERROR: cannot find ${pkgdir}/tar"
   exit 1
fi

set -x

cd ${pkgdir}/tar || ssi_die "could not cd ${pkgdir}/tar"
git clone ${sourceurl} ${srcname}
cd ${pkgdir}/tar/${srcname} || ssi_die "could not cd ${pkgdir}/tar/${srcname}"
git checkout -b ${pkgver} remotes/origin/${pkgdotver}
./switch-git-urls
git submodule init
git submodule update
#git submodule foreach git checkout ${pkgdotver}
#git submodule foreach git checkout -b ${pkgver}
cd ${pkgdir}/tar || ssi_die "could not cd ${pkgdir}/tar"
tar cjf ${package}-${pkgdotver}.tar.bz2 --exclude=\.git ${srcname} || ssi_die "tar failed"
rm -rf ${srcname}

set +x

cd ${product_dir}
${SSIBUILDSHIMS_DIR}/bin/make_source_code_tarball ${product_dir} ${package} ${pkgver}


exit 0
