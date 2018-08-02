#!/usr/bin/perl
use Data::Dumper;
use webHacks;
use strict;
use Getopt::Std;

my %opts;
getopts('t:p:d:j:h:c:e:s:m:q', \%opts);

my $site = $opts{'t'} if $opts{'t'};
my $port = $opts{'p'} if $opts{'p'};
my $path = $opts{'d'} if $opts{'d'};

my $cookie = "";
$cookie = $opts{'c'} if $opts{'c'};
my $ssl = $opts{'s'};
my $ajax = "0";
$ajax = $opts{'j'} if $opts{'j'};
my $mode = $opts{'m'} if $opts{'m'};
my $threads = $opts{'h'} if $opts{'h'};
my $quiet = $opts{'q'} if $opts{'q'};
my $error404 = $opts{'e'} if $opts{'e'};
#my $debug = $opts{'d'} if $opts{'d'};
my $debug=0;
# scan for comments

#PATTERNS = {
    # "<!%-.-%-!?>", -- HTML comment
    # "/%*.-%*/", -- Javascript multiline comment
    #"[ ,\n]//.-\n" -- Javascript one-line comment. Could be better?    
    #}
    
    # <!-- Copyright (c) Rohde & Schwarz GmbH & Co. KG Munich Germany All Rights Reserved.-->
    #<meta name="description" content="WVC80N">
    
# ADD FUNCTIONALITY 
#   Source code comments
    #Errors (MySQL errors, warnings, fatals, etc)
    #Linux file paths    


$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

my $banner = <<EOF;
      ___  __      __        __  ___  ___  __  
|  | |__  |__)    |__) |  | /__`  |  |__  |__) 
|/\\| |___ |__)    |__) \\__/ .__/  |  |___ |  \\ v1.0                                              

Autor: Daniel Torres Sandi
EOF


sub usage { 
  
  print $banner;
  print "Uso:  \n";  
  print "-t : IP o dominio del servidor web \n";
  print "-p : Puerto del servidor web \n";
  print "-d : Ruta donde empezara a probar directorios \n";
  print "-j : Adicionar header ajax (xmlhttprequest) 1 para habilitar \n";
  print "-h : Numero de hilos (Conexiones en paralelo) \n";
  print "-c : cookie con la que hacer el escaneo ej: PHPSESSION=k35234325 \n";
  print "-e : Busca este patron en la respuesta para determinar si es una pagina de error 404\n";
  print "-s : SSL (opcional) \n";
  print "		-s 1 = SSL \n";
  print "		-s 0 = NO SSL \n";	
  print "-m : Modo. Puede ser: \n";
  print "	  directorios: Probar si existen directorios comunes \n";
  print "	  archivos: Probar si existen directorios comunes \n";
  print "	  cgi: 	Probar si existen archivos cgi \n";
  print "	  webdav: Directorios webdav \n";
  print "	  webservices: Directorios webservices \n";  
  print "	  webserver: Probar si existen archivos propios de un servidor web (server-status, access_log, etc) \n";
  print "	  backup: Busca backups de archivos de configuracion comunes (Drupal, wordpress, IIS, etc) \n";
  print "	  \n\tCombinaciones:\n";
  print "	  iis:    directorios + admin + archivos + webservices + webserver + backup + archivos asp/aspx/html/htm\n";
  print "	  tomcat: directorios + admin + archivos + webservices + webserver + backup + archivos jps/html/htm\n";
  print "	  apache: directorios + admin + cgi + archivos + webservices + webserver + backup + archivos php/html/htm\n";
  
  
  print "	  completo: Probara Todos los modulos \n";
  #print "	  username: Probara si existen directorios de usuarios tipo http://192.168.0.2/~daniel \n";  
  print "\n";
  print "Ejemplo 1:  Buscar arhivos comunes en el directorio raiz (/) del host 192.168.0.2 en el puerto 80  con 10 hilos\n";
  print "	  web-buster.pl -t 192.168.0.2 -p 80 -d / -m archivos -h 10 \n";
  print "\n";
  print "Ejemplo 2:  Buscar backups de archivos de configuracion en el directorio /wordpress/ del host 192.168.0.2 en el puerto 443 (SSL)  \n";
  print "	  web-buster.pl -t 192.168.0.2 -p 443 -d /wordpress/ -m backup -s 1 -h 30\n";  
  print "\n";
  print "Ejemplo 3:  Buscar archivos/directorios del host 192.168.0.2 (apache) en el puerto 443 (SSL)  \n";
  print "	  web-buster.pl -t 192.168.0.2 -p 443 -d / -m apache -s 1 -h 30\n";  
  print "\n";  
}	

#extensiones:  
# iis asp, aspx
# tomcat jsp
# apache/nginx php
# comunes: html, htm,  

# Print help message if required
if (!(%opts)) {
	usage();
	exit 0;
}

if ($quiet ne 1)
{print $banner,"\n";}



			    
					    
my $webHacks ;

if($error404 eq '' and $ssl eq '')
{

	$webHacks = webHacks->new( rhost => $site,
						rport => $port,
						path => $path,
						threads => $threads,						
						cookie => $cookie,
						ajax => $ajax,						
						max_redirect => 0,
					    debug => $debug);	

# Need to make a request to discover if SSL is in use
$webHacks->dispatch(url => "http://$site:$port$path",method => 'GET');
}

if($error404 ne '' and $ssl eq '' )
{
	
	$webHacks = webHacks->new( rhost => $site,
						rport => $port,
						path => $path,
						threads => $threads,
						error404 => $error404,						
						cookie => $cookie,
						ajax => $ajax,						
						max_redirect => 0,
					    debug => $debug);	

# Need to make a request to discover if SSL is in use
$webHacks->dispatch(url => "http://$site:$port$path",method => 'GET');					    
}

if($ssl ne '' and $error404 eq '' )
{

	$webHacks = webHacks->new( rhost => $site,
						rport => $port,
						path => $path,
						threads => $threads,
						ssl => $ssl,
						cookie => $cookie,
						ajax => $ajax,						
						max_redirect => 0,
					    debug => $debug);	
}

if ($error404 ne ''  and $ssl ne '' )
{	
	$webHacks = webHacks->new( rhost => $site,
						rport => $port,
						path => $path,
						threads => $threads,
						error404 => $error404,
						ssl => $ssl,
						cookie => $cookie,
						ajax => $ajax,						
						max_redirect => 0,
					    debug => $debug);	
}


# fuzz with common files names
if ($mode eq "archivos" or $mode eq "completo" or $mode eq "apache" or $mode eq "tomcat" or $mode eq "iis"){	
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/files.txt");	
	print "\n";
}

# fuzz with admin
if ($mode eq "admin" or $mode eq "completo" or $mode eq "apache" or $mode eq "tomcat" or $mode eq "iis"){		
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/admin.txt");	
	print "\n";
}

# fuzz with common directory names
if ($mode eq "directorios" or $mode eq "completo" or $mode eq "apache" or $mode eq "tomcat" or $mode eq "iis"){		
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/directorios.txt");	
	print "\n";
}

# fuzz with common cgi files names
if ($mode eq "cgi" or $mode eq "completo" or $mode eq "apache" ){		
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/cgi.txt");	
	print "\n";
}

# fuzz with common server files names
if ($mode eq "webserver" or $mode eq "completo" or $mode eq "apache" or $mode eq "tomcat" or $mode eq "iis"){			
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/webserver.txt");	
	print "\n";
}

# fuzz with backup names (add .bak, .swp, etc)
if ($mode eq "backup" or $mode eq "completo" or $mode eq "apache" or $mode eq "tomcat" or $mode eq "iis"){			
	my $status = $webHacks->backupbuster("/usr/share/webhacks/wordlist/configFiles.txt");	
	print "\n";
}

# fuzz with webservices
if ($mode eq "webservices" or $mode eq "completo" or $mode eq "apache" or $mode eq "tomcat" or $mode eq "iis"){		
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/webservices.txt");	
	print "\n";
}


# fuzz with files (with extension)
if ($mode eq "apache"  or $mode eq "php"  or $mode eq "completo"){	
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/php.txt");	
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/files2.txt","php");	
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/files2.txt","htm");	
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/files2.txt","html");		
	print "\n";
}

# fuzz with iis
if ($mode eq "iis"  or $mode eq "asp"  or $mode eq "completo"){		
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/iis.txt");	
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/files2.txt","asp");	
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/files2.txt","aspx");	
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/files2.txt","html");		
	print "\n";
}

# fuzz with tomcat
if ($mode eq "tomcat"  or $mode eq "jsp"  or $mode eq "completo"){			
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/tomcat.txt");	
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/files2.txt","jsp");		
	my $status = $webHacks->dirbuster("/usr/share/webhacks/wordlist/files2.txt","html");	
	print "\n";
}

# fuzz with user names 
if ($mode eq "username" or $mode eq "completo"){	
	my $status = $webHacks->userbuster("/usr/share/webhacks/wordlist/nombres.txt");	
	print "\n";
}

