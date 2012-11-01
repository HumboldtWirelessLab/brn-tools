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

test_cmds()
{
  for line in `cat $0 | grep "#CMD" | grep -v "line" | awk '{print $2}'`; do
    command -v $line >/dev/null 2>&1 || /usr/bin/pkg-config $line >/dev/null 2>&1 || { echo >&2 "Click requires $line but it's not installed.  Aborting."; return 1; }
  done 
}

FULLFILENAME=`basename $0`
FULLFILENAME=$DIR/$FULLFILENAME

GITHOST=gitsar

if [ "x$FULL" = "x1" ]; then
  DEVELOP=1
  ENABLE_NS3=1
  BRNDRIVER=1
  BRNTESTBED=1
fi

#*******************************************************************************************
#********************************** B R N - D R I V E R  ***********************************
#*******************************************************************************************

if [ "x$1" = "xdriver" ]; then
  if [ ! -e ../brn-driver ]; then
    ( cd ..; git clone git@$GITHOST:brn-driver )
  fi

  ( cd ../brn-driver; sh ./brn-driver.sh init)

  exit 0
fi

#*******************************************************************************************
#********************************** B R N - T E S T B E D **********************************
#*******************************************************************************************

if [ "x$1" = "xtestbed" ]; then
  if [ ! -e ../brn-testbed ]; then
    ( cd ..; git clone git@$GITHOST:brn-testbed )
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
   if [ ! -e click-brn/.git ]; then
     git submodule init
     git submodule update
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

#******************************************************************************
#*************************** C H E C K   S O F T W A R E  *********************
#******************************************************************************

echo "Make sure that you have the following packages:"
echo " * g++"
echo " * autoconf"
echo " * libx11-dev"
echo " * libxt-dev"
echo " * libxmu-dev"
echo " * flex"
echo " * bison"
echo " * bc "
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

test_cmds

if [ $? = 1 ]; then
  exit 1;
fi

#*******************************************************************************************
#*************************** G E T   S O U R C E S   ( S T A G E   1 ) *********************
#*******************************************************************************************

if [ ! -e brn-tools ]; then
  if [ ! -e click-brn ]; then
    echo "Get sources..."
    git clone git@$GITHOST:brn-tools

    echo "Start build"
    (cd ./brn-tools; sh ./brn-tools.sh)
    exit $?
  fi
else
  echo "Start build"
  (cd ./brn-tools; sh ./brn-tools.sh)
  exit $?
fi

if [ "x$1" = "xhelp" ]; then
  exit 0
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

BUILDCLICK=yes
BUILDCLICKSCRIPTS=yes

if [ ! -e click-brn/.git ]; then
  git submodule init
  git submodule update
fi

for i in `git submodule | awk '{print $2}'`; do
  (cd $i; git checkout master)
done

chmod 600 helper/host/etc/keys/id_dsa

#***********************************************************************
#******************************** B U I L D ****************************
#***********************************************************************

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
  if [ ! -f $CLICKPATH/brn-conf.sh ]; then
    cp $DIR/click-brn/brn-conf.sh $CLICKPATH
  fi
  (cd $CLICKPATH;touch ./configure; /bin/sh brn-conf.sh tools; XCFLAGS="-fpermissive -fPIC $XCFLAGS" /bin/sh brn-conf.sh sim_userlevel; make -j $CPUS) 2>&1 | tee click_build.log
fi

(cd brn-ns2-click; CLEAN=$CLEAN DEVELOP=$DEVELOP VERSION=5 PREFIX=$DIR/ns2 CPUS=$CPUS CLICKPATH=$CLICKPATH ./install_ns2.sh) 2>&1 | tee ns2_build.log

(cd jist-brn/brn-install/; sh ./install.sh ) 2>&1 | tee jist_build.log

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

  (cd $NS3PATH; ./waf configure --with-nsclick=$CLICKPATH --enable-examples; ./waf build) 2>&1 | tee ns3_build.log
  echo "export NS3_HOME=$BRN_TOOLS_PATH/ns-3-brn/" > $DIR/ns-3-brn/bashrc.ns3
fi

echo "export BRN_TOOLS_PATH=$DIR" > $DIR/brn-tools.bashrc
echo "export CLICKPATH=\$BRN_TOOLS_PATH/click-brn/" >> $DIR/brn-tools.bashrc
echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$CLICKPATH/ns/:\$BRN_TOOLS_PATH/ns2/lib" >> $DIR/brn-tools.bashrc
echo "export PATH=\$BRN_TOOLS_PATH/ns2/bin/:\$CLICKPATH/userlevel/:\$CLICKPATH/tools/click-align/:\$BRN_TOOLS_PATH/helper/simulation/bin/:\$BRN_TOOLS_PATH/helper/evaluation/bin:\$BRN_TOOLS_PATH/helper/measurement/bin:\$PATH" >> $DIR/brn-tools.bashrc
echo "if [ -e \$BRN_TOOLS_PATH/jist-brn/brn-install/bashrc.jist ]; then" >> $DIR/brn-tools.bashrc
echo "  . \$BRN_TOOLS_PATH/jist-brn/brn-install/bashrc.jist" >> $DIR/brn-tools.bashrc
echo "fi" >> $DIR/brn-tools.bashrc
if [ "x$NS3PATHEXT" = "x" ]; then
  echo "if [ -e $NS3PATH/bashrc.ns3 ]; then" >> $DIR/brn-tools.bashrc
  echo "  . $NS3PATH/bashrc.ns3" >> $DIR/brn-tools.bashrc
else
  echo "if [ -e \$BRN_TOOLS_PATH/$NS3PATHEXT/bashrc.ns3 ]; then" >> $DIR/brn-tools.bashrc
  echo "  . \$BRN_TOOLS_PATH/$NS3PATHEXT/bashrc.ns3" >> $DIR/brn-tools.bashrc
fi
echo "fi" >> $DIR/brn-tools.bashrc

if [ "x$DISABLE_TEST" = "x1" ]; then
  echo "Test disabled"
  rm -f click_build.log ns2_build.log
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
#CMD ant
#CMD bc
#CMD x11
#CMD xt
#CMD xmu
