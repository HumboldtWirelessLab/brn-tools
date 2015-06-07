#!/bin/sh

dir=$(dirname "$0")
pwd=$(pwd)

SIGN=`echo $dir | cut -b 1`

case "$SIGN" in
  "/")
        DIR=$dir
        ;;
  ".")
        DIR=$pwd/$dir
        ;;
   *)
        echo "Error while getting directory"
        exit -1
        ;;
esac

DISABLE_JIST=0

#test_cmds()
#{
#  for line in `cat $0 | grep "#CMD" | grep -v "line" | awk '{print $2}'`; do
#    command -v $line >/dev/null 2>&1 || /usr/bin/pkg-config $line >/dev/null 2>&1 || { echo >&2 "Click requires $line but it's not installed.  Aborting."; return 1; }
#  done
#}

test_ant()
{
  command -v ant >/dev/null 2>&1 || /usr/bin/pkg-config ant >/dev/null 2>&1 || { echo >&2 "Ant not installed. Disable JIST"; DISABLE_JIST=1; }
}

resolve_deps()
{
  deps="$1"

  echo "Checking dependencies...\n"

  # for debian based distros
  command -v apt-get >/dev/null 2>&1
  if [ $? = 0 ]; then
    echo "Found apt-get."
    echo "Installing dependencies..."
	sudo apt-get install $deps
    if [ $? = 0 ]; then
      return 0;
    fi
  fi

  # for other distros with gdebi
  # FIXME: make a list of urls for debs, download debs, install debs with gdebi
  command -v gdebi >/dev/null 2>&1
  if [ $? = 0 ] && [ -f $DIR/brn-tools.deb ]; then
    echo "Found gdebi and a build package."
    echo "Installing dependencies..."
    sudo gdebi $DIR/brn-tools.deb
    if [ $? = 0 ]; then
      return 0;
    fi
  fi

  return 1;
}

build_bashrc()
{
  NEWBRNTOOLSGITVERSION=`(cd $DIR;git log | grep commit | head -n 1 | awk '{print $2}')`

  echo "export BRN_TOOLS_PATH=$DIR" > $DIR/brn-tools.bashrc
  echo "export BRNTOOLSGITVERSION=$NEWBRNTOOLSGITVERSION" >> $DIR/brn-tools.bashrc

  if [ -e $DIR/click-extern ]; then
    echo "export CLICKPATH=\$BRN_TOOLS_PATH/click-extern/" >> $DIR/brn-tools.bashrc
  else
    echo "export CLICKPATH=\$BRN_TOOLS_PATH/click-brn/" >> $DIR/brn-tools.bashrc
  fi
  echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$CLICKPATH/ns/:\$BRN_TOOLS_PATH/ns2/lib:\$BRN_TOOLS_PATH/click-brn-libs/lib" >> $DIR/brn-tools.bashrc
  echo "export PATH=\$BRN_TOOLS_PATH/ns2/bin/:\$CLICKPATH/userlevel/:\$CLICKPATH/tools/click-align/:\$BRN_TOOLS_PATH/helper/simulation/bin/:\$BRN_TOOLS_PATH/helper/evaluation/bin:\$BRN_TOOLS_PATH/helper/measurement/bin:\$BRN_TOOLS_PATH/helper/host/bin:\$PATH" >> $DIR/brn-tools.bashrc
  echo "if [ -e \$BRN_TOOLS_PATH/jist-brn/brn-install/bashrc.jist ]; then" >> $DIR/brn-tools.bashrc
  echo "  . \$BRN_TOOLS_PATH/jist-brn/brn-install/bashrc.jist" >> $DIR/brn-tools.bashrc
  echo "fi" >> $DIR/brn-tools.bashrc

  if [ "x$NS3PATHEXT" = "x" ]; then
    if [ -f $BRN_TOOLS_PATH/ns-3-brn/bashrc.ns3 ]; then
      NS3PATHEXT=ns-3-brn
    fi
  fi

  if [ "x$NS3PATHEXT" = "x" ]; then
    if [ "x$NS3PATH" != "x" ]; then
      echo "if [ -e $NS3PATH/bashrc.ns3 ]; then" >> $DIR/brn-tools.bashrc
      echo "  . $NS3PATH/bashrc.ns3" >> $DIR/brn-tools.bashrc
      echo "fi" >> $DIR/brn-tools.bashrc
    fi
  else
    echo "if [ -e \$BRN_TOOLS_PATH/$NS3PATHEXT/bashrc.ns3 ]; then" >> $DIR/brn-tools.bashrc
    echo "  . \$BRN_TOOLS_PATH/$NS3PATHEXT/bashrc.ns3" >> $DIR/brn-tools.bashrc
    echo "fi" >> $DIR/brn-tools.bashrc
  fi
}

#*********************************************************************************
#*************************   S E T   U R L S   ***********************************
#*********************************************************************************

FULLFILENAME=`basename $0`
FULLFILENAME=$DIR/$FULLFILENAME


if [ -f $DIR/.git/config ]; then
  GITURL_BRNTOOLS=`cat $DIR/.git/config  | grep -A 2 "\[remote" | grep url | awk '{print $3}'`

  GITURL=`echo $GITURL_BRNTOOLS | awk -F: '{print $1}'`

  GITHOST=`echo $GITURL | awk -F@ '{print $2}'`
else
  GITURL="git@gitsar"
fi

#*********************************************************************************
#********************************** C H E C K  ***********************************
#*********************************************************************************
if [ "x$1" = "xbashrc" ]; then
  build_bashrc
  exit 0
fi

CURRENTBRNTOOLSGITVERSION=`(cd $DIR; git log | grep commit | head -n 1 | awk '{print $2}')`

#if diff gitversion just reread the bashrc first
if [ "x$CURRENTBRNTOOLSGITVERSION" != "x$BRNTOOLSGITVERSION" ] && [ -f $DIR/brn-tools.bashrc ]; then
  . $DIR/brn-tools.bashrc
fi

#if it is still different -> rebuild
if [ "x$CURRENTBRNTOOLSGITVERSION" != "x$BRNTOOLSGITVERSION" ] && [ -f $DIR/brn-tools.bashrc ]; then
  echo "Different GITVERSIONS! Update bashrc !"
  cp brn-tools.bashrc brn-tools.bashrc.old
  sh $0 bashrc
  . $DIR/brn-tools.bashrc
fi

if [ "x$1" = "xhelp" ]; then
  cat $FULLFILENAME | grep "^#HELP" | sed -e "s/#HELP[[:space:]]*//g" -e "s#TARGETDIR#$DIR#g"
  exit 0
fi

if [ -f $DIR/brn-tools.bashrc ] && [ "x$1" = "x" ]; then
  echo "Rebuild brn-tools. Are you sure? If so, remove brn-tools.bashrc!"
  exit 0
fi

if [ ! -f $DIR/brn-tools.bashrc ] && [ "x$1" != "x" ]; then
  echo "Build brn-tools!!!! Start $0 without args!"
  exit 0
fi


#*********************************************************************************
#*********************** S E T U P   B U I L D ***********************************
#*********************************************************************************

if [ "x$FULL" = "x1" ]; then
  DEVELOP=1
  ENABLE_NS3=1
  BRNDRIVER=1
  BRNTESTBED=1
fi

# toggle dependency checking
if [ "x$DEPS" = "x1" ]; then
  CHECK_DEPS=1
fi

#*******************************************************************************************
#********************************** B R N - D R I V E R  ***********************************
#*******************************************************************************************

if [ "x$1" = "xdriver" ]; then
  if [ ! -e ../brn-driver ]; then
    ( cd ..; git clone $GITURL:brn-driver )
  fi

  ( cd ../brn-driver; sh ./brn-driver.sh init)

  exit 0
fi

#*******************************************************************************************
#********************************** B R N - T E S T B E D **********************************
#*******************************************************************************************

if [ "x$1" = "xtestbed" ]; then
  if [ ! -e ../brn-testbed ]; then
    ( cd ..; git clone $GITURL:brn-testbed )
  fi

  ( cd ../brn-testbed; sh ./brn-testbed.sh )

  exit 0
fi

if [ "x$CLICKURL" != "x" ]; then
  git clone $CLICKURL click-extern
fi

if [ "x$NS3URL" != "x" ]; then
  git clone $NS3URL ns-3-extern
fi

#*******************************************************************************************
#******************************************* U P D A T E ***********************************
#*******************************************************************************************

if [ "x$1" = "xpull" ] || [ "x$1" = "xpush" ] || [ "x$1" = "xgui" ] || [ "x$1" = "xstatus" ]; then
   GITSUBDIRS=`git submodule | awk '{print $2}'`
   if [ -e ns-3-extern/.git ]; then
     GITSUBDIRS="$GITSUBDIRS ns-3-extern"
   fi
   if [ -e ns-3-extern/.git ]; then
     GITSUBDIRS="$GITSUBDIRS click-extern"
   fi
fi

if [ "x$1" = "xpull" ]; then
   git pull

   if [ ! -e click-brn/.git ]; then
     git submodule init
     git submodule update
   fi

   if [ ! -e click-brn-libs/.git ]; then
     (cd click-brn-libs/; git submodule init; git submodule update; git checkout master)
   fi

   for i in $GITSUBDIRS; do
     (cd $i; CURRENT=`git branch | grep "*" | awk '{print $2}'`; if [ "x$CURRENT" = "x(no" ]; then git checkout master; fi )
   done

   for i in $GITSUBDIRS; do echo $i; (cd $i;CURRENT=`git branch | grep "*" | awk '{print $2}'`; if [ "x$CURRENT" != "xmaster" ]; then echo "Switch to master (current: $CURRENT)"; git checkout master; fi; git pull; if [ "x$CURRENT" != "xmaster" ]; then echo "Switch back to $CURRENT"; git checkout $CURRENT; git rebase master; fi); done
   echo "brn-tools"
   CURRENT=`git branch | grep "*" | awk '{print $2}'`; if [ "x$CURRENT" != "xmaster" ]; then echo "Switch to master (current: $CURRENT)"; git checkout master; fi; git pull; if [ "x$CURRENT" != "xmaster" ]; then echo "Switch back to $CURRENT"; git checkout $CURRENT; git rebase master; fi
   exit 0
fi

if [ "x$1" = "xpush" ]; then
   for i in $GITSUBDIRS; do echo $i; (cd $i;CURRENT=`git branch | grep "*" | awk '{print $2}'`; if [ "x$CURRENT" != "xmaster" ]; then git checkout master; git merge $CURRENT; fi; git pull; git push; if [ "x$CURRENT" != "xmaster" ]; then git checkout $CURRENT; git rebase master; fi); done
   echo "brn-tools"
   CURRENT=`git branch | grep "*" | awk '{print $2}'`; if [ "x$CURRENT" != "xmaster" ]; then git checkout master; git merge $CURRENT; fi; git pull; git push; if [ "x$CURRENT" != "xmaster" ]; then git checkout $CURRENT; git rebase master; fi
   exit 0
fi

if [ "x$1" = "xgui" ]; then
   for i in $GITSUBDIRS; do echo $i; (cd $i; git gui); done
   echo "brn-tools"
   git gui
   exit 0
fi
if [ "x$1" = "xstatus" ]; then
   for i in $GITSUBDIRS; do echo $i; (cd $i; git status); done
   echo "brn-tools"
   git status
   exit 0
fi
if [ "x$1" = "xallstatus" ]; then
   sh $0 status
   if [ -e ../brn-driver/brn-driver.sh ]; then ( cd ../brn-driver; sh ./brn-driver.sh status); fi
   if [ -e ../brn-testbed/brn-testbed.sh ]; then ( cd ../brn-testbed; sh ./brn-testbed.sh status); fi
   exit 0
fi

if [ "x$1" != "x" ]; then
  sh $0 help
  exit 0
fi
#******************************************************************************
#*************************** C H E C K   S O F T W A R E  *********************
#******************************************************************************
deps="g++ clang autoconf libx11-dev libxt-dev libxmu-dev flex bison bc"

echo "Make sure that you have the following packages:"
for package in $deps; do
  echo " * " $package
done

echo ""
echo "Add following lines to .ssh/config"
echo "Host gruenau"
echo "   User username"
echo "   HostName gruenau.informatik.hu-berlin.de"
echo ""
echo "Host gitsar"
echo "   User username"
echo "   HostName localhost"
echo "   ProxyCommand ssh -q gruenau netcat sar 2222"
echo ""

#test_cmds
test_ant

if [ $? = 1 ]; then
  exit 1;
fi

echo "Do you want to check for build dependencies now? (y/n) -Sudo required!-"
read DEP_CHECK
if [ "x$DEP_CHECK" = "xy" ] || [ "x$DEP_CHECK" = "xY" ]; then
  resolve_deps "$deps"
  if [ $? = 1 ]; then
    echo "Could not resolve dependencies."
    echo "Please resolve possible dependency issues manually!\n"
    echo "Enter to continue with installation"
    read foo
  fi
else
  echo "Please resolve possible dependency issues manually!"
  echo "Enter to continue with installation"
  read foo
fi

#*******************************************************************************************
#*************************** G E T   S O U R C E S   ( S T A G E   1 ) *********************
#*******************************************************************************************

if [ ! -e brn-tools ]; then
  if [ ! -e click-brn ]; then
    echo "Get sources..."
    git clone $GITURL:brn-tools

    echo "Start build"
    (cd ./brn-tools; sh ./brn-tools.sh)
    exit $?
  fi
else
  echo "Start build"
  (cd ./brn-tools; sh ./brn-tools.sh)
  exit $?
fi

if [ "x$DEVELOP" = "x" ]; then
  DEVELOP=1
fi

if [ "x$CLEAN" = "x" ]; then
  CLEAN=1
fi

if [ "x$CPUS" = "x" ]; then
  if [ -f /proc/cpuinfo ]; then
    CPUS=`grep -e "^processor" /proc/cpuinfo | wc -l`
  else
    CPUS=1
  fi
fi

echo "Use $CPUS cpus"

#*****************************************************************************************
#*************************** G E T   S O U R C E S ( S T A G E   2 ) *********************
#*****************************************************************************************

BUILDLIBS=yes
BUILDCLICK=yes
BUILDCLICKSCRIPTS=yes

if [ ! -e click-brn/.git ]; then
  git submodule init
  git submodule update
fi

for i in `git submodule | awk '{print $2}'`; do
  (cd $i; git checkout master)
done

if [ -f helper/host/etc/keys/id_dsa ]; then
  chmod 600 helper/host/etc/keys/id_dsa
fi

#***********************************************************************
#******************************** B U I L D ****************************
#***********************************************************************

if [ "x$BUILDLIBS" = "xyes" ]; then
  if [ -e click-brn-libs/src ]; then
    if [ -f click-brn-libs/src/build.sh ]; then
      (cd click-brn-libs/src/; ./build.sh)
    fi
  fi
fi

if [ "x$CLICKPATH" = "x" ]; then
  if [ -e click-extern ]; then
    CLICKPATH=$DIR/click-extern
    if [ "x$DISABLE_TEST" = "x" ]; then
      DISABLE_TEST=1
    fi
  else
    CLICKPATH=$DIR/click-brn
  fi
fi

if [ "x$BUILDCLICK" = "xyes" ]; then
  #copy to build tools
  if [ ! -f $CLICKPATH/brn-conf.sh ]; then
    cp $DIR/click-brn/brn-conf.sh $CLICKPATH
  fi

  if [ "x$GPROF" = "x1" ]; then
    XCFLAGS="-pg $XCFLAGS"
  else
    if [ "x$NOOPT" != "x1" ]; then
      XCFLAGS="$XCFLAGS -O2"
    fi
  fi

  if [ $DISABLE_JIST -eq 0 ]; then
	(cd $CLICKPATH;touch ./configure; /bin/sh brn-conf.sh tools; BRN_TOOLS_PATH=$DIR XCFLAGS="-fpermissive -fPIC $XCFLAGS" /bin/sh brn-conf.sh sim_userlevel; make -j $CPUS) 2>&1 | tee click_build.log
  else
	(cd $CLICKPATH;touch ./configure; /bin/sh brn-conf.sh tools; BRN_TOOLS_PATH=$DIR XCFLAGS="-fpermissive -fPIC $XCFLAGS" /bin/sh brn-conf.sh ns2_userlevel; make -j $CPUS) 2>&1 | tee click_build.log
  fi
fi

(cd brn-ns2-click; XCFLAGS="$XCFLAGS" CLEAN=$CLEAN DEVELOP=$DEVELOP VERSION=5 BRN_TOOLS_PATH=$DIR PREFIX=$DIR/ns2 CPUS=$CPUS CLICKPATH=$CLICKPATH ./install_ns2.sh) 2>&1 | tee ns2_build.log

if [ $DISABLE_JIST -eq 0 ]; then
  (cd jist-brn/brn-install/; sh ./install.sh ) 2>&1 | tee jist_build.log
fi

if [ "x$ENABLE_NS3" = "x1" ]; then
  if [ "x$NS3PATH" = "x" ]; then
    if [ -e ns-3-extern ]; then
      NS3PATH=$DIR/ns-3-extern
      NS3PATHEXT=ns-3-extern
    else
      NS3PATH=$DIR/ns-3-brn
      NS3PATHEXT=ns-3-brn
    fi
  fi

  CLICK_CFLAGS=`(cd $CLICKPATH/ns; make linkerconfig)`
  CLICK_CFLAGS="$CLICK_CFLAGS -I$DIR/click-brn-libs/include -L$DIR/click-brn-libs/lib"
  (cd $NS3PATH; CCFLAGS="$CLICK_CFLAGS" CXXFLAGS="$CLICK_CFLAGS" ./waf configure --with-nsclick=$CLICKPATH --enable-examples; CCFLAGS="$CLICK_CFLAGS" CXXFLAGS="$CLICK_CFLAGS" ./waf build) 2>&1 | tee ns3_build.log
  echo "export NS3_HOME=$NS3PATH/" > $NS3PATH/bashrc.ns3
fi

build_bashrc

if [ "x$DISABLE_TEST" = "x1" ]; then
  echo "Test disabled"
  rm -f click_build.log ns2_build.log jist_build.log ns3_build.log
else
  echo "Start Tests"

  . $DIR/brn-tools.bashrc

  (cd $DIR/click-brn-scripts/; NOLATEX=1 sh ./test.sh) > test.log 2> /dev/null

  #less test.log

  TESTS_OVERALL=`cat test.log | grep "Test" | wc -l`
  TESTS_OK=`cat test.log | grep "Test" | awk '{print $3}' | grep "ok" | wc -l`

  echo "$TESTS_OK of $TESTS_OVERALL tests finished without errors. See $DIR/click-brn-scripts/testbed.pdf for more details."

  if [ $TESTS_OK -ne $TESTS_OVERALL ]; then
    echo "Detect failures. Please send test.log, click_build.log, jist_build.log and ns2_build.log (hwl-team)."
    exit 1
  else
    rm -f test.log click_build.log ns2_build.log jist_build.log ns3_build.log
  fi

fi

if [ "x$BRNDRIVER" = "x1" ]; then
  sh $0 driver
fi

if [ "x$BRNTESTBED" = "x1" ]; then
  sh $0 testbed
fi

cat $FULLFILENAME | grep "^#INFO" | sed -e "s/#INFO[[:space:]]*//g" -e "s#TARGETDIR#$DIR#g"

exit 0

#INFO
#INFO
#INFO --------------- FINISH ------------------
#INFO
#INFO
#INFO
#INFO
#INFO Well done !
#INFO
#INFO Use "source TARGETDIR/brn-tools.bashrc" to setup the path-var or add following line to .bashrc:
#INFO if [ -e TARGETDIR/brn-tools.bashrc ]; then . TARGETDIR/brn-tools.bashrc; fi
#INFO

#HELP Update NS2: CLICKPATH=/XXX/click-brn CLICKSCRIPTS=/XXX/click-brn-scripts/ sh ./brn-tools.sh

#CMD make
#CMD gcc
#CMD g++
#CMD autoconf
#CMD flex
#CMD bison
#CMD javac
#CMD bc
#CMD x11
#CMD xt
#CMD xmu
