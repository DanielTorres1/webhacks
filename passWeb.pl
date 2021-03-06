#!/usr/bin/perl
use Data::Dumper;
require webHacks;
use strict;
use Getopt::Std;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

my %opts;
getopts('t:p:m:d:u:f:h', \%opts);


my $target = $opts{'t'} if $opts{'t'};
my $port = $opts{'p'} if $opts{'p'};
my $module = $opts{'m'} if $opts{'m'};
my $user = $opts{'u'} if $opts{'u'};
my $path = $opts{'d'} if $opts{'d'};
my $passwords_file = $opts{'f'} if $opts{'f'};

sub usage { 
  
  print "Uso:  \n";
  print "Autor: Daniel Torres Sandi \n";
  print "	Ejemplo 1:  passWeb.pl -t 192.168.0.2 -p 80 -d / -m ZKSoftware -u administrator -f passwords.txt \n"; 
  print "	Ejemplo 2:  passWeb.pl -t 192.168.0.2 -p 443 -d /admin/ -m phpmyadmin -u root -f passwords.txt \n"; 
  print "	Ejemplo 3:  passWeb.pl -t 192.168.0.2 -p 80 -d / -m PRTG -u prtgadmin -f passwords.txt  \n"; 
  print "	Ejemplo 4:  passWeb.pl -t 192.168.0.2 -p 80 -d / -m zimbra -u juan.perez -f passwords.txt  \n"; 
  print "	Ejemplo 5:  passWeb.pl -t 192.168.0.2 -p 80 -d / -m zte -u user -f passwords.txt  \n"; 
  print "	Ejemplo 6:  passWeb.pl -t 192.168.0.2 -p 8081 -d / -m pentaho -u admin -f top.txt \n"; 
  
 
  
}	
# Print help message if required
if ($opts{'h'} || !(%opts)) {
	usage();
	exit 0;
}

	   				   
my $webHacks = webHacks->new( rhost => $target,
						rport => $port,
						max_redirect => 1,
					    debug => 0);
					    

# Need to make a request to discover if SSL is in use
$webHacks->dispatch(url => "http://$target:$port".$path,method => 'GET');

$webHacks->passwordTest( module => $module, path => $path, user => $user, passwords_file => $passwords_file)
