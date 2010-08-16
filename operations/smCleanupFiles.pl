#!/usr/bin/env perl
# $Id: smCleanupFiles.pl,v 1.8 2010/04/30 09:35:14 gbauer Exp $

use strict;
use warnings;
use DBI;
use Getopt::Long;
use File::Basename;
use File::Find ();


my ($help, $debug, $nothing, $now, $force, $execute, $maxfiles, $fileagemin, $skipdelete, $dbagemax);
my ($hostname, $filename, $dataset, $stream, $config);
my ($runnumber, $uptorun, $safety, $rmexitcode, $chmodexitcode );
my ($constraint_runnumber, $constraint_uptorun, $constraint_filename, $constraint_hostname, $constraint_dataset);

my ($reader, $phrase);
my ($dbi, $dbh);
my ($minRunSMI, $fileageSMI);
my %h_notfiles;



#-----------------------------------------------------------------
sub usage
{
  print "
  ##############################################################################

  Usage $0 [--help] [--debug] [--nothing]  [--now]
  Almost all the parameters are obvious. Non-obvious ones are:
   --now : suppress 'sleep' in delete based on host ID

  ##############################################################################
 \n";
  exit 0;
}

#-----------------------------------------------------------------
#subroutine for getting formatted time for SQL to_date method
sub gettimestamp($)
		 {
		     my $stime = shift;
		     my @ltime = localtime($stime);
		     my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = @ltime;
		     
		     $year += 1900;
		     $mon++;
		     
		     my $timestr = $year."-";
		     if ($mon < 10) {
			 $timestr=$timestr . "0";
		     }
		     
		     $timestr=$timestr . $mon . "-";
		     
		     if ($mday < 10) {
			 $timestr=$timestr . "0";
		     }
		     
		     $timestr=$timestr . $mday . " " . $hour . ":" . $min . ":" . $sec;
		     return $timestr;
		 }

#-----------------------------------------------------------------
sub deletefiles()
{

# Look for files in FILES_TRANS_CHECKED - implies closed and safety >= 100 in the old scheme.
# Alternate queries for different values of these? even needed?
# These files need to be in FILES_CREATED and FILES_INJECTED to
# check correct hostname and pathname. They must not be in FILES_DELETED.
#
# this query contains some optimizations from DB experts: do not muck with this lightly! [gb 02Jun2010]
    my $basesql = "select fi.PATHNAME, fc.FILENAME, fc.HOSTNAME from CMS_STOMGR.FILES_CREATED fc " .
                      "inner join CMS_STOMGR.FILES_INJECTED fi " .
                              "on fc.FILENAME = fi.FILENAME    and  fi.ITIME > systimestamp - $dbagemax " .
                      "inner join CMS_STOMGR.FILES_TRANS_CHECKED ftc " .
                              "on fc.FILENAME = ftc.FILENAME   and ftc.ITIME > systimestamp - $dbagemax " .
                      "left outer join CMS_STOMGR.FILES_DELETED fd " .
                              "on fc.FILENAME = fd.FILENAME " .
			      "where fc.CTIME > systimestamp - $dbagemax and  fd.FILENAME is null ";
 

# Sorting by time
    my $endsql = " order by ITIME";

    
# Additional constraints
    $constraint_runnumber = '';
    $constraint_uptorun   = '';
    $constraint_filename  = '';
    $constraint_hostname  = '';
    $constraint_dataset   = '';
    
    if ($runnumber) { $constraint_runnumber = " and RUNNUMBER = $runnumber"; }
    if ($uptorun)   { $constraint_uptorun   = " and RUNNUMBER >= $uptorun";  }
    if ($filename)  { $constraint_filename  = " and CMS_STOMGR.FILES_TRANS_CHECKED.FILENAME = '$filename'";}
    if ($hostname)  { $constraint_hostname  = " and HOSTNAME = '$hostname'";}
    if ($dataset)   { $constraint_dataset   = " and SETUPLABEL = '$dataset'";}
    
# Compose DB query
    my $myquery = '';
    $myquery = "$basesql $constraint_runnumber $constraint_uptorun $constraint_filename $constraint_hostname $constraint_dataset $endsql";
    
    $debug && print "******BASE QUERY:\n   $myquery,\n";
    
        
    my $insertDel = $dbh->prepare("insert into CMS_STOMGR.FILES_DELETED (FILENAME,DTIME) VALUES (?,TO_DATE(?,'YYYY-MM-DD HH24:MI:SS'))");
    my $sth  = $dbh->prepare($myquery);
    
    
    
    my $predate=`date`;
    print "PreQuery: $predate...\n";
    
    $sth->execute() || die "Initial DB query failed: $dbh->errstr\n";
    
    my $postdate=`date`;
    print "PostQuery: $postdate...\n";
    

############## Parse and process the result
    my $nFiles   = 0;
    my $nRMFiles = 0;
    my $nRMind   = 0;
    
    
    
    my @row;
    
    $debug && print "MAXFILES: $maxfiles\n";
    
    while ( $nFiles<$maxfiles &&  (@row = $sth->fetchrow_array) ) {
	
	$rmexitcode = 9999;    # Be over-cautious and set a non-zero default
	$debug   && print "       --------------------------------------------------------------------\n";
	$nFiles++;
	
	#keep track of smallest run number processed:
	my ($currrun) = ($row[1] =~ /[a-zA-Z0-9]+\.([0-9]+)\..*/);
	if( $minRunSMI >  $currrun ){ $minRunSMI = $currrun;}
	
	# get .ind file name
	my $file =  "$row[0]/$row[1]";
	my $fileIND;
	if ( $file =~ /^(.*)\.(?:dat|root)$/ ) {
	    $fileIND = $1 . '.ind';
	}
	
	if ( -e $file ) {
	    my $FILEAGEMIN   =  (time - (stat(_))[9])/60;
	    $debug   && print "$FILEAGEMIN $fileagemin\n";
	    
	    if ($execute && $FILEAGEMIN > $fileagemin) {
		if ( unlink( $file ) == 1 ) {
		    # unlink should return 1: removed 1 file
		    $rmexitcode = 0;
		} else {
		    print "Removal of $file failed\n";
		    $rmexitcode = 9996;
		}
	    } elsif (!$execute && $FILEAGEMIN > $fileagemin) {
		#if we're not executing anything want to fake
		print "Pretending to remove $file\n";
		$rmexitcode = 0;
	    } elsif ($FILEAGEMIN < $fileagemin) {
		$debug   && print "File $file too young to die\n";
		$rmexitcode = 9995;
	    } else {
		print "This should never happen. File $file has issues!\n";
		$rmexitcode = 9994;
	    }
	} elsif ($force) {
	    print "File $file does not exist, but force=1, so continue\n";
	    $rmexitcode = 0;
	} elsif ( ! -d $row[0] ) {
	    print "Path $row[0] does not exist. Are the disks mounted?\n";
	    $rmexitcode = 9998;
	} else {
	    print "File $file does not exist\n";
	    $rmexitcode = 9997;
	}
	#$rmexitcode =0;
	# check file was really removed
	if ($rmexitcode != 0) {
	    print "Could not delete file: $file (rmexitcode=$rmexitcode)\n";
	} elsif ( ! -e $file ) {
	    $nRMFiles++;
	    
	    # insert file into deleted db
	    $insertDel->bind_param(1,$row[1]);
	    $insertDel->bind_param(2,gettimestamp(time));
	    $execute && ($insertDel->execute() || die "DB insert into deleted files failed: $insertDel->errstr\n");
	    my $delErr = $insertDel->errstr;
	    if(defined($delErr)) {
		print "Delete DB insert produced error: $delErr\n";
	    } else {
		$debug && print "File inserted into deleted DB, rm .ind\n";
		if ( $execute && -e $fileIND) {
		    my $rmIND = `rm -f $fileIND`;
		    if (! -e "$fileIND" ) {$nRMind++;}
		}
	    }
	} else {
	    print "Unlink returned success, but file $file is still there!\n";
	}


}


# Only print summary if STDIN is a tty, so not in cron
#if( -t STDIN ) {
    print "\n=================> DONE!:\n";
    print ">>BASE QUERY WAS:\n   $myquery,\n";
    print " $nFiles Files Processed\n" .
      " $nRMFiles Files rm-ed\n" .
      " $nRMind ind Files removed\n\n\n";
#}


#make sure handles are done
$sth->finish();


}


#---------------------------helper function for uncountfiles()----
sub wantedfiles {
    # Data.00129762.1825.A.storageManager.01.0000.dat
    ! /\.EcalCalibration\./
	&& /(^[^.]+)\.([0-9]+)\..*\.([0-9]+)\.[0-9]+\.dat$/
	&& $h_notfiles{$2}{$3}{$1}++;
}

#----------------------------------------------uncountfiles()----
sub uncountfiles(){
# routine to check disk for file unaccounted for in the DB and enter (N_UNACCOUNT) number in SM_INSTANCES table
    
#satadir:
#    my $nsata=`df | grep -ic sata`;
#    if( $nsata <1 ) { return;} 
    
#prepare SQL's:
#diagnostic query:
    my $qinstancesql = "SELECT CMS_STOMGR.SM_INSTANCES.RUNNUMBER,SETUPLABEL,INSTANCE,HOSTNAME,NVL(N_CREATED,0),NVL(N_INJECTED,0),NVL(N_DELETED,0),NVL(N_UNACCOUNT,0) " .
        	       "from CMS_STOMGR.SM_INSTANCES where RUNNUMBER=? and HOSTNAME=?";
    

#query to zero out N_UNACCOUNT counter:
    my $upallinstancesql = "UPDATE CMS_STOMGR.SM_INSTANCES SET N_UNACCOUNT=0 " .
	                   "where HOSTNAME=? and  RUNNUMBER>? ";

#( RUNNUMBER>? or LAST_WRITE_TIME > systimestamp - $fileageSMI ) ";

#	                   "where HOSTNAME=? and ( RUNNUMBER>? or LAST_WRITE_TIME+$fileageSMI>sysdate) ";
print      "where HOSTNAME=? and ( RUNNUMBER>? or LAST_WRITE_TIME+$fileageSMI>sysdate) \n";


#merge to enter info into DB:
    my $mergesql = " merge into CMS_STOMGR.SM_INSTANCES using dual on (CMS_STOMGR.SM_INSTANCES.RUNNUMBER=? AND " .
                   "            CMS_STOMGR.SM_INSTANCES.HOSTNAME=? AND CMS_STOMGR.SM_INSTANCES.INSTANCE=? )    " .
                   " when matched then update set  N_UNACCOUNT=?-TO_NUMBER(NVL(N_INJECTED,0))+TO_NUMBER(NVL(N_DELETED,0)) " .
                   " when not matched then insert (RUNNUMBER,HOSTNAME,INSTANCE,SETUPLABEL,N_UNACCOUNT) values (?,?, ?, ?, ?) ";

    
    

#check what file are ACTUALLY on disk by desired filesystems
    File::Find::find({wanted => \&wantedfiles}, </store/sata*/gcd/closed/>);


    my $qinstance     = $dbh->prepare($qinstancesql);
    my $upallinstance = $dbh->prepare($upallinstancesql);
    my $merge         = $dbh->prepare($mergesql);



#put in and extra buffer of look at files older than the min-run number  just in case they need updating
    $minRunSMI = $minRunSMI - 1000;
    
#global update to initialize counters to zero:
    print "global update with minrun=$minRunSMI and age=$fileageSMI days\n";
    $upallinstance->bind_param(1,$hostname);
    $upallinstance->bind_param(2,$minRunSMI);
    my $upallinstanceCheck = $upallinstance->execute() or die("Error: Global Zeroing of SM_INSTANCES - $dbh->errstr \n");

    $upallinstance->finish();

    
    
    
    for my $run ( sort keys %h_notfiles ) {
	for my $instance ( sort keys %{$h_notfiles{$run}} ) {
	    for my $label ( sort keys %{$h_notfiles{$run}{$instance}} ) {
		print "************ run= $run  instance=$instance  label=$label \n ";
		
		if($run > 129710){
		    
		    print "run= $run; instance=$instance  label=$label  files=$h_notfiles{$run}{$instance}{$label} \n";
		    
		    
		    $qinstance->bind_param(1,$run);
		    $qinstance->bind_param(2,$hostname);
		    my $qinstanceCheck = $qinstance->execute() or die("Error: Query2 failed - $dbh->errstr \n");
		    my @result = $qinstance->fetchrow_array;
		    my $diff = $h_notfiles{$run}{$instance}{$label}-$result[4]+$result[6];
		    print "SELECT-OUT: $result[0], Label=$result[1], INST=$result[2], $result[3], CREA=$result[4], INJ=$result[5], DELE=$result[6], UNACC=$result[7] || diff=$diff\n";
		    
		    
##update SM_INSTANCES:
		    print "UPDATE instances for RUN $run  with disk file count=$h_notfiles{$run}{$instance}{$label} \n";
		    $merge->bind_param(1,$run);
		    $merge->bind_param(2,$hostname);
		    $merge->bind_param(3,$instance);
		    $merge->bind_param(4,$h_notfiles{$run}{$instance}{$label});
		    $merge->bind_param(5,$run);
		    $merge->bind_param(6,$hostname);
		    $merge->bind_param(7,$instance);
		    $merge->bind_param(8,$label);
		    $merge->bind_param(9,$h_notfiles{$run}{$instance}{$label});
		    my $mergeCheck = $merge->execute() or die("Error: Update of SM_INSTANCES for Host $hostname  Run $run - $dbh->errst \n");
		    
		    
## #check results:
		    $qinstanceCheck = $qinstance->execute() or die("Error: Query failed - $dbh->errstr \n");
		    @result = $qinstance->fetchrow_array;
		    $diff = $h_notfiles{$run}{$instance}{$label}-$result[4]+$result[6];
		    print "SELECT-OUT: $result[0], Label=$result[1], INST=$result[2], $result[3], CREA=$result[4], INJ=$result[5], DELE=$result[6], UNACC=$result[7] || diff=$diff\n";
		    
		    
		    
		    print "-------------------\n";
		  
		    
		} 
	    }
	}
    }
    
    
## 
## my %touchruns=();
## foreach my $ifile (@Files) {
##     my ($run) = ($ifile =~ /[a-zA-Z0-9]+\.([0-9]+)\..*/);
##     if($minRunSMI > $run){$minRunSMI = $run;}
##     if (exists $touchruns{$run}){
## 	$touchruns{$run} =  $touchruns{$run}+1;
##     }else{
## 	$touchruns{$run} =  1;
##     }
## }
## 
## #put in and extra buffer of look at old file entries just in case for updating
## $minRunSMI = $minRunSMI - 1000;
## 
## 
## #global update to initialize counters to zero:
## print "global update with minrun=$minRunSMI and age=$fileageSMI days\n";
## $upallinstance->bind_param(1,$hostname);
## $upallinstance->bind_param(2,$minRunSMI);
## my $upallinstanceCheck = $upallinstance->execute() or die("Error: Global Zeroing of SM_INSTANCES - $dbh->errstr \n");
## 
## 
## 
## #cycle through Runs which have files on disk:
## foreach my $run (keys %touchruns) {
##     print " ********* RUN=$run, NFiles=$touchruns{$run} \n";
##     if($run > 129710){
## 
##  	$qinstance->bind_param(1,$run);
##  	$qinstance->bind_param(2,$hostname);
##  	my $qinstanceCheck = $qinstance->execute() or die("Error: Query2 failed - $dbh->errstr \n");
##  	print "CHECK: $qinstanceCheck || \n";
##  	my @result = $qinstance->fetchrow_array;	
##  	print "----RESULT dump:..||\n";
##  	print @result;
##  	print "\n---------\n";      
##         my $diff = $touchruns{$run}-$result[4]+$result[5];
##  	print "SELECT-OUT: $result[0], INST=$result[1], $result[2], CREA=$result[3], INJ=$result[4], DELE=$result[5], UNACC=$result[6] || diff=$diff\n";
##  		
## 	
## ##update SM_INSTANCES:
## 	print "UPDATE instances for RUN $run  with disk file count=$touchruns{$run} \n";
## 
##        
## 	$merge->bind_param(1,$run);
## 	$merge->bind_param(2,$hostname);
## 	$merge->bind_param(3,$touchruns{$run});
## 	$merge->bind_param(4,$run);
## 	$merge->bind_param(5,$hostname);
## 	$merge->bind_param(6,-99);
## 	$merge->bind_param(7,$touchruns{$run});
## 	my $mergeCheck = $merge->execute() or die("Error: Update of SM_INSTANCES for Host $hostname  Run $run - $dbh->errst \n");
## 	
## 	
## ## #check results:
##  	$qinstanceCheck = $qinstance->execute() or die("Error: Query failed - $dbh->errstr \n");
##  	print "CHECK: $qinstanceCheck || \n";
##  	@result = $qinstance->fetchrow_array;
##         $diff = $touchruns{$run}-$result[4]+$result[5];
##  	print "UPDATED-OUT: $result[0], INST=$result[1], $result[2], CREA=$result[3], INJ=$result[4], DELE=$result[5], UNACC=$result[6] || diff=$diff\n";
## 
##  	print "-------------------\n";
## ## 	
## 	
## 	
## #    }else{
## #	print "Run  $run is too old to process for !Files\n";
##     }
##     
## }
    
#keep these 'finishes' of DB at the end, so ALL worked or a rollback?
    $qinstance->finish();
    $merge->finish();
    
    
}

#-----------------------------------------------------------------
sub deleteCopyManager()
{
    my $dir="/store/copymanager/Logs";
    
    print "search in $dir \n";
    if( -d $dir ){
	
	my $string = `df $dir | grep dev`;
	my ($favail) = ($string =~ /.*\ ([0-9]+)\%.*/);
	print "----- Initial disk usage $favail\n";
	
	#delete older than 45 days:
	my $delete =`find /store/copymanager/Logs/*/ -cmin +64800  -type f   -exec sudo -u cmsprod  rm -f \'{}\' \\\; >& /dev/null`;
	
	$string = `df $dir | grep dev`;
	($favail) = ($string =~ /.*\ ([0-9]+)\%.*/);
	print "----- 45-day disk usage $favail\n";
	
	if( $favail > 85 ){
	    
	    #delete older than 32 days:
	    $delete = `find /store/copymanager/Logs/*/ -cmin +46080  -type f  -exec sudo -u cmsprod  rm -f \'{}\' \\\; >& /dev/null`;
	    
	    $string = `df $dir | grep dev`;
	    ($favail) = ($string =~ /.*\ ([0-9]+)\%.*/);
	    print "----- 32-day disk usage $favail\n";
	    my $gbdebug1 =`echo "-----   32-day disk usage $favail" >> /tmp/gbdebugClean.txt`;
	    my $gbdebug2 =`echo "2: $delete" >> /tmp/gbdebugClean.txt`;

	    
	    
	    #brutal action: Manager files older than 15 days, and /tmp area older than 8 days
	    if( $favail > 94 ){
		$delete = `find /store/copymanager/Logs/*/ -cmin +21600  -type f  -exec sudo -u cmsprod  rm -f \'{}\' \\\; >& /dev/null`;
		
		my $gbdebug3 =`echo "3: $delete" >> /tmp/gbdebugClean.txt`;
		
		$delete = `sudo -u cmsprod find /tmp/* -cmin +4320  -type f  -exec sudo rm -f {} \; >& /dev/null`;
		
		
		#emergency action: Manager files older than 3 days, and /tmp area older than 3 days
		if( $favail > 96 ){
		    
		    $delete = `find /store/copymanager/Logs/*/ -cmin +4320  -type f  -exec sudo -u cmsprod  rm -f \'{}\' \\\; >& /dev/null`;
		    
		    $delete = `find /tmp/* -cmin +4320  -type f  -exec sudo -u   rm -f {} \; >& /dev/null`;
		    
		}
	    }
	}
	
	$string = `df $dir | grep dev`;
	($favail) = ($string =~ /.*\ ([0-9]+)\%.*/);
	print "----- FINAL disk usage $favail\n";
	
	my $gbdebug =`echo "----- FINAL disk usage $favail " >> /tmp/gbdebugClean.txt`;
    }
}


###################################################################
######################### MAIN ####################################

$help       = 0;
$debug      = 0;
$nothing    = 0;
$now        = 0;
$filename   = '';
$dataset    = '';
$uptorun    = 0;
$runnumber  = 0;
$safety     = 100;
$hostname   = '';
$execute    = 1;
$maxfiles   = 400000;
$fileagemin = 130;  #min
#$dbagemax   = 365;  #days
$dbagemax   = 45;  #days
$force      = 0;
$config     = "/opt/injectworker/.db.conf";


$hostname   = `hostname -s`;
chomp($hostname);

GetOptions(
           "help"          =>\$help,
           "debug"         =>\$debug,
           "nothing"       =>\$nothing,
           "now"           =>\$now,
           "force"         =>\$force,
           "config=s"      =>\$config,
           "hostname=s"    =>\$hostname,
           "run=i"         =>\$runnumber,
           "runnumber=i"   =>\$runnumber,
	   "uptorun=s"	   =>\$uptorun,
	   "filename=s"	   =>\$filename,
	   "dataset=s"	   =>\$dataset,
           "stream=s"      =>\$stream,
           "maxfiles=i"    =>\$maxfiles,
           "fileagemin=i"  =>\$fileagemin,
           "dbagemax=i"    =>\$dbagemax,
           "skipdelete"    =>\$skipdelete
	  );

$help && usage;
if ($nothing) { $execute = 0; $debug = 1; }

#special OVERRIDE!!!
$maxfiles   = 400000;



#what's the current time:
my $hour  = `date +%H`+0;
my $hour6 =  $hour%6;
my $min   = `date +%M`+0;


my $sleeptime = 0;
#figure out what timing delays we want for cleaning etc:
my ($rack, $node, $deltaT);
if       ( ( $rack, $node ) = ( $hostname =~ /srv-c2c0([67])-(\d+)$/i ) ){ # main SM
    my $hourPC  = ( 2*($node-12) + 10*($rack-6) )%18 + ($rack-6);
    my $minPC   = $hourPC%3;
    my $hourPC3 = ($hourPC - $minPC)/3;
    my $minPC20 = 20*$minPC;
    #time diff for scheduling deletes
    $deltaT   = 60*($hour6-$hourPC3) +  $min-$minPC20;
#       print " standard SM, tdiff=  $deltaT  \n";
}elsif ( ($rack, $node ) = ( $hostname =~ /dvsrv-c2f3([7])-(\d+)$/i ) ){   # daqval SM
 #   haven't decided what to do for daqval SM's yet!
     exit 0;
}elsif (  $hostname =~ /cmsdisk1/i ||  $hostname =~ /srv-C2D05-02/i  ){    # minidaq SM
     #force deletion near c07-20's slot cuz it's probably not having to do much anyhow
     #but do it only ONCE per day (15:07 hrs)
     $deltaT = 60*($hour-15);    
     $node   = 20;
     $rack   =  7;
     $sleeptime = 0.5;
     print "..do cmsdisk1 sleep!  \n";
     sleep(60*1);
 }else {
    #unknown machine
    exit 0;
}

#     print " standard SM, tdiff=  $deltaT  \n";


print "$hostname: $hour ($hour6) h AND $min min ===> deltaTime= $deltaT\n";


#setup sleep delays for Unaccounted files (to span 18 min cycle)
my  $interval = 18;
#print "     $sleeptime = ( 2*($node-12) + 10*($rack-6) )%$interval + ($rack-6); \n";
    $sleeptime = $sleeptime + ( 2*($node-12) + 10*($rack-6) )%$interval + ($rack-6);


print "$hostname:  $rack $node sleep time: $sleeptime \n";


#count sata-mounts, if NONE, then no need to try and do disk inventory OR clean!
my $nsata=`df | grep -ic sata`;
if( $nsata >0 ) { 
    

my $date=`date`;
print "$date  ..maybe sleep 60*$sleeptime...\n";
if( abs($deltaT) > 7 &&  !$now  ){ 
   sleep(60*$sleeptime);
}
$date=`date`;
print "$date  ..sleep done...\n";



$reader = "xxx";
$phrase = "xxx";
my ($hltdbi, $hltreader, $hltphrase);
if(-e $config) {
    eval `su smpro -c "cat $config"`;
} else {
    print "Error: Can not read config file $config, exiting!\n";
    usage();
}


$dbi    = "DBI:Oracle:cms_rcms";
$dbh    = DBI->connect($dbi,$reader,$phrase)
    or die "Can't make DB connection: $DBI::errstr\n";



#default params for filling SM_INSTANCES table
$minRunSMI   = 134000; #smallest run number being handled
$fileageSMI  = 5;         #in days


  my $gbdebug1 =`echo "----- $hostname: $hour6- AND $min ===> deltaTime= $deltaT " >> /tmp/gbdebugClean.txt`;


   $date=`date`;
if( abs($deltaT) < 7  ||  $now  ){ 
    if( !$now ){ sleep 10;}
    
    my  $gbNEWdebug =`date:  >> /tmp/gbdebugNewClean.txt`;
    $gbNEWdebug =`echo "$hostname: $hour6- AND $min ===> deltaTime= $deltaT  " >> /tmp/gbdebugNewClean.txt`;
    
     print "$date ..execute DELETES cycle...\n";
    if (!$skipdelete) { deletefiles(); }
    $date=`date`;
    print "$date ..DONE executing DELETES...\n";
    
    #if we did a file delete, kill the snooze time for the UNACCTFILES:
    $sleeptime=0;

}else{
    
    print "unsatisfied, eXIT!..\n";
    sleep 1;
}



$date=`date`;
print "$date  ..execute !Files...\n";
uncountfiles();
$date=`date`;
print "$date ..DONE executing unDELETES...\n";


$dbh->disconnect;

}

my  $gbdebug =`date >> /tmp/gbdebugClean.txt`;
$gbdebug =`echo "    $hour && $min: Delta-t= $deltaT " >> /tmp/gbdebugClean.txt`;


if($now ||  abs($deltaT) < 8   ) { 
    my $date=`date`;
    print " $date: cleanup CopyManager if there  \n";
    deleteCopyManager(); 

    $date=`date`;
    print "$date .. move copyworker work-logs.... \n";
    my $clnmngr = `sudo -u cmsprod  perl /cmsnfshome0/nfshome0/gbauer/cleanupCopyWorkerWorkDir.pl`;
    
}

    my $date=`date`;
    print "$date .. all done!\n";

