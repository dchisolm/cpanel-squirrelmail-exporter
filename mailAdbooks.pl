use strict;
use warnings;
use lib '/usr/local/cpanel';
use Time::Piece;
use POSIX qw(strftime);
use Cpanel::Email::Send;
use Getopt::Long qw(GetOptions);
Getopt::Long::Configure qw(gnu_getopt);
use Sys::Hostname;
#Global Vars
my $sourceDir;
my $help;
my $emailTemplate;
my $host = hostname;
my $logFile = "/root/cpanel-squirrelmail-export-mail.log";
my $silent = 0;
GetOptions(
    'source=s'  => \$sourceDir,
    'help'    => \$help,
) or die "Use --help";

if ($help) { 
(my $helpText = qq{
    This script will find all files that end with .abook.csv in the source directory.
    It will then mail all of those files to the email address that is contained within the filename.
    This script is designed to work exclusively with the files generated by the exportAbooks.pl script.

   --source /path/to/source/directory
	The source directory should be one of the export directories created by the exportAbooks.pl script.
}) =~ s/^ {4}//mg;
	print $helpText;
	exit;	
}

($emailTemplate = qq{
    Hello,

    Your SquirrelMail addressbook has been exported and attacthed to this email.

    You may import the attached file to RoundCube and Horde with the following instructions:

    First, download the attached CSV file to your computer.

    RoundCube:
     - Login to the RoundCube webmail client
     - Click on the Contacts button in the upper right corner
     - Click on the Import button on the upper left corner
     - Upload the csv file from your computer

    Horde:
     - Login to the Horde webmail client
     - Click on Address Book in the horizontal menu
     - Click on Import/Export in the upper left area
     - Upload the csv file from your computer

}) =~ s/^ {4}//mg;


if (-d $sourceDir) {
	chdir $sourceDir;
	my @files = glob("*.abook.csv");
	if (scalar @files < 1 ) { message ("ERROR: Source directory does not contain any files ending in .abook.csv . No addressbooks were mailed.", 1, 1, 1) }
	foreach my $file (@files) {
		my $count = `wc -l < $file`;
		if ($count < 1) { message ("NOTICE: $file appears to be empty so it has been skipped and not mailed.", 1, 1, 0); next; }
	 	open( my $fh, "<", $file) or die "Can't open < $file: $!";
		my $file_content = do { local $/; <$fh> };
		if ($count == 1 and $file_content =~ "Nickname" ) { message ("NOTICE: $file appears to only contain header information so it has been skipped and not mailed.", 1, 1, 0); next; }
		my %attachment;
		$attachment{'content'} = $fh;
		$attachment{'name'} = $file;
		my @attachments = (\%attachment);
		my @to = ($file); 
		$to[0] =~ s/.abook.csv//ig;
		sendMessage(\@to, "Your SquirrelMail AddressBook", $emailTemplate, "root\@$host", \@attachments);
		message ("INFO: $file file has been mailed to $to[0] .", 1, 1, 0);
	}
	message ("INFO: Mailing has concluded. Check /var/log/exim_mainlog if you have any doubts or concerns about the messages that were sent.", 1, 1, 0);
	message ("INFO: You may view the above output at the following log $logFile", 1, 1, 0);
} else {
	die "--source is not a directory. Use --help\n";
}

sub sendMessage {
	
	my %opts;

	$opts{'to'}           =  $_[0];
	$opts{'subject'}      =  $_[1];
	$opts{'text_body'}    = \$_[2];
	$opts{'from'}         =  $_[3];
	$opts{'attachments'}  =  $_[4];

	Cpanel::Email::Send::email_message( \%opts );
}

sub writeLog {
	my $message = $_[0];
	
	my $timeStamp = strftime "%D %T", localtime;
	
	open (my $fh, '>>', $logFile) or die "Could not open $logFile for writing";
	print $fh "$timeStamp $message";
	close $fh;
}

sub message {
        my $message = $_[0];
        my $stdOut  = $_[1];
        my $log     = $_[1];
        my $die     = $_[3];

        chomp($message);
        $message = "$message\n";

        if ($log) { writeLog($message) }
        if ($die and not $silent) {
                die $message;
        } elsif ($die and $silent and $log) {
                writeLog ($message);
                exit;
        } elsif ($die and $silent and not $log) {
                # Even if the original intention was to not log, we're going to override this so that the script never dies without saying *something*
                writeLog($message);
                exit;
        }
        if ($stdOut and not $silent) { print $message }
}
