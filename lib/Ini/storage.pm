class Ini::Storage;

use filepath;
use dprint;
#save configuration settings

sub new {
  my $proto    = shift;
  my $filename = shift;
  my $class    = ref($proto) || $proto;
  my $isdisk   = shift;
  my $self     = {};

  #definitions
  my $p = filepath::getdir($filename);
  #print "filepath [$p]";
  if ( not defined $p ) {
    $p = $ENV{USERPROFILE};
    d::w "settings", "p:$p";
    if ( defined $p ) {
   
      $self->{filename} = $p . filepath::separator . filepath::getbasename($filename);
     
    }
    else {
      $self->{filename} = $filename;
    }
  }
  else {
    $self->{filename} = $filename;
  }

  if ( not defined $isdisk or $isdisk == 1 ) {
    $self->{disk} = 1;
  }
  else {
    $self->{disk} = 0;
  }

  $self->{changed} = 0;
  bless( $self, $class );
  if ( $self->{disk} ) {
    my $status= $self->ReadFile;
    if ( $status == 1 or $status == 0) {
      return $self;
    }
    else {
      return undef;
    }
  }
  return $self;
}

sub DESTROY {
  my $this = shift;
  $this->Flush;
}

sub GetFilename {
  my $this = shift;
  return $this->{filename};
}

sub SetFilename {
  my $this = shift;
  my $newfn= shift;
  $this->{filename}=$newfn;
  $this->{changed} = 1;
}

sub Read {
  my $this = shift;
  my $key  = shift;
  my $default = shift;
  my ( $group, $entry ) = $key =~ /\/?(.+?)\/(.+)/;
  #print "XXread:$this->{hash}{$group}{$entry}\n";
  if ((not exists $this->{hash}{$group}) or
  (not  exists $this->{hash}{$group}{$entry} ))
  {
    return $default;
  }
  else
  {
    return $this->{hash}{$group}{$entry};
  }
}

sub Exchange {
 my $this = shift;
 my $key  = shift;
 my $key2  = shift;
 my ( $group, $entry ) = $key =~ /\/?(.+?)\/(.+)/;
 my ( $group2, $entry2 ) = $key2 =~ /\/?(.+?)\/(.+)/;
 if (exists $this->{hash}{$group}{$entry})
 {
  my $val=$this->{hash}{$group}{$entry};
  if (exists $this->{hash}{$group2}{$entry2})
  {
   $val2=$this->{hash}{$group2}{$entry2};
   $this->{hash}{$group}{$entry}=$val2;
   $this->{hash}{$group2}{$entry2}=$val;
   $this->{changed} = 1;
  }
 }
}

sub GetEntryName
{
  my $this = shift;
  my $group  = shift;
  my $no = shift;
  $no--;
 return $this->{list}{$group}[$no];
}

sub FindRegInGroup
{
  my $this = shift;
  my $group  = shift;
}

sub Write {
  my $this  = shift;
  my $key   = shift;
  my $value = shift;
  my ( $group, $entry ) = $key =~ /\/?(.+?)\/(.+)/;
  my $exists = 0;
  #print "write $group $entry $value\n";
  
  for ( @{ $this->{group} } ) {
    if ( $_ eq $group ) {
      $exists = 1;
    }
  }
  if ( not $exists ) {
    push @{ $this->{group} }, $group;
    d::w "settings", "another group\n";
  }
  if ( exists $this->{hash}{$group}{$entry} ) {

    $this->{hash}{$group}{$entry} = $value;
   #  print "hello2 write $group $entry $value\n";
  }
  else {
   # print "hello2\n";

    $this->{hash}{$group}{$entry} = $value;
    push @{ $this->{list}{$group} }, $entry;
  }
#  for my $i ( @{ $this->{list}{$group} } ) {
#    print "check $i=$this->{hash}{$group}{$i}\n";
#  }
  $this->{changed} = 1;
}

sub Copy {
  my $this = shift;
  my $obj  = shift;
  for ( @{ $obj->{group} } ) {
    for my $i ( @{ $obj->{list}{$_} } ) {
      $this->Write( "/$_/$i", $obj->{hash}{$_}{$i} );
    }
  }
}

sub CountEntries {
  my $this  = shift;
  my $group = shift;
  my $c;
  if (defined $this->{list}{$group})
  {
    return @{ $this->{list}{$group} };
  }
  return 0;
}

sub CopyGroup {
  my $this  = shift;
  my $obj   = shift;
  my $group = shift;
  my $newgroupname = shift // $group;
  for my $i ( @{ $obj->{list}{$group} } ) {
    $this->Write( "/$newgroupname/$i", $obj->{hash}{$group}{$i} );
  }
}

sub DeleteEntry {
  my $this = shift;
  my $key  = shift;
  my ( $group, $entry ) = $key =~ /\/?(.+?)\/(.+)/;
  d::w "settings", "delete $group $entry\n";
  if ( defined $this->{hash}{$group}{$entry} ) {
    delete $this->{hash}{$group}{$entry};
    my $i = 0;
    for ( @{ $this->{list}{$group} } ) {
      if ( $_ eq $entry ) {
        last;
      }
      $i++;
    }
   
    splice @{ $this->{list}{$group} }, $i, 1;
    d::w "settings", "del:@{ $this->{list}{$group} } $i\n";
    $this->{changed} = 1;
  }
 # for my $i ( @{ $this->{list}{$group} } ) {
 #   print "check $i=$this->{hash}{$group}{$i}\n";
 # }
}

sub RenameEntry
{
  my $this = shift;
  my $key  = shift;
  my $keynew  = shift;
  my ( $group, $entry ) = $key =~ /\/?(.+?)\/(.+)/;
  my ( $groupnew, $entrynew ) = $keynew =~ /\/?(.+?)\/(.+)/;
  d::w "settings", "rename $group $entry\n";
  my $val;
  if ( exists $this->{hash}{$group}{$entry} and not exists
   $this->{hash}{$groupnew}{$entrynew}) {
    $val=$this->{hash}{$group}{$entry};
    delete $this->{hash}{$group}{$entry};
    my $i = 0;
    for ( @{ $this->{list}{$group} } ) {
      if ( $_ eq $entry ) {
        last;
      }
      $i++;
    }
    d::w "settings", "del:@{ $this->{list}{$group} } $i\n";
    splice @{ $this->{list}{$group} }, $i, 1;
    $this->{changed} = 1;
    $this->Write($keynew,$val);
  }
#  for my $i ( @{ $this->{list}{$group} } ) {
#    print "check $i=$this->{hash}{$group}{$i}\n";
#  }
}

sub DeleteEntryFromArray
{
  my $this = shift;
  my $key  = shift;
  my ( $group, $entry ) = $key =~ /\/?(.+?)\/(.+)/;
  my ($arrayname,$no)= $entry=~ /(.+?)(\d+)$/;
  d::w "settings", "deletefromarray $group $entry $arrayname,$no\n";
  if (not defined $1)
  {
    return;
  }
  $this->DeleteEntry($key);
  my @list=  @{ $this->{list}{$group} };
  for my $i ( @list ) {
    if ($i=~ /$arrayname(\d+)$/)
    {
      if ($1>$no)
      {
        $this->RenameEntry("$group/$arrayname".$1,"$group/$arrayname".($1-1));
      }
    }
    #print "check $i=$this->{hash}{$group}{$i}\n";
  }
}

sub GetLastArrayIndex
{
  my $this = shift;
  my $key  = shift;
 # my $array  = shift;
  my ( $group, $array ) = $key =~ /\/?(.+?)\/(.+)/;
  my $maxi=-1;
  for ( @{ $this->{list}{$group} } ) {
        if (/^$array(\d+)$/)
        {

           if ($1>$maxi)
           {
             $maxi=$1;
           }
        }
  }
  return $maxi;
}

sub DeleteGroup {
  my $this = shift;
  my $group = shift;
  if ( defined $this->{hash}{$group} ) {
    delete $this->{hash}{$group};
    delete $this->{list}{$group};
    $this->{changed} = 1;
    my $i = 0;
    for ( @{ $this->{group} } ) {
      if ( $_ eq $group ) {
        splice @{ $this->{group} }, $i, 1;
        last;
      }
      $i++;
    }
 #   for my $i ( @{ $this->{list}{$group} } ) {
 #   print "check $i=$this->{hash}{$group}{$i}\n";
#  }
  }
}

sub GroupExists
{
my $this=shift;
my $group=shift;
if ( exists $this->{hash}{$group} ) {
    return 1;
  }
  else {
    return 0;
  }

}

sub Exists {
  my $this = shift;
  my $key  = shift;
  my ( $group, $entry ) = $key =~ /\/?(.+?)\/(.+)/;
  if ( exists $this->{hash}{$group} and exists $this->{hash}{$group}{$entry} ) {
    return 1;
  }
  else {
    return 0;
  }
}

sub GetGroups
{
my $this  = shift;
return @{ $this->{group} };
}

sub GetEntriesInGroup {
  my $this  = shift;
  my $group = shift;
  return $this->{hash}{$group};
}

sub FindIndexInArrayByValue {
my $this  = shift;
my $group = shift;
my $arrayname = shift;
my $value = shift;
my %ref=%{$this->{hash}{$group}};
  for (keys %ref)
    {
      if (/^($arrayname(\d+))$/)
       {
        if ($ref{$1} eq $value)
        { return $2;}
      }
    }
  return -1;
}

sub FindAValueInRecordByKey {
my $this  = shift;
my $group = shift;
my $arrayname = shift; #find key in this array
my $value = shift; #
my $arrayname2 = shift;
my $index=$this->FindIndexInArrayByValue($group,$arrayname,$value);
return undef if ($index==-1);

my %ref=%{$this->{hash}{$group}};
  for (keys %ref)
    {
      if (/^($arrayname2(\d+))$/)
       {
        if ($2 eq $index)
        { return $ref{$1};}
      }
    }
  return undef;
}

sub GetArrayInGroupK($$) {
my $this = shift;
my $key  = shift;
my ( $group, $entry ) = $key =~ /\/?(.+?)\/(.+)/;
return $this->GetArrayInGroupGE($group, $entry);
}




sub GetArrayInGroupGE($$$) {
  my $this  = shift;
  my $group = shift;
  my $name = shift;
  my %ref=%{$this->{hash}{$group}};
  my $res;
  my @arr;
  for (keys %ref)
    {
      if (/^($name(\d+))$/)
       {
      $arr[$2]=$ref{$1};
      }
    }
  return \@arr;
}

sub SetArrayInGroup ($$$$) {
  my $this  = shift;
  my $group = shift;
  my $name = shift;
  my $arr= shift;
  my %ref=%{$this->{hash}{$group}};
  my $res;
  my @arr;
  for (keys %ref)
    {
     if (/^($name(\d+))$/)
       {
      $this->DeleteEntry("$group/$_");
      }
    }
  for (my $i=0;$i<@{$arr};$i++)
  {
  $this->Write("$group/$name$i",$$arr[$i]) if defined $$arr[$i];
  }
}



sub ReadFile {
  my $this = shift;
  my $currgroup;
  d::w "settings", "read file\n";
  if ( -e $this->{filename} ) {
    d::w "settings", "bele $this->{filename}\n";
    open F, "<$this->{filename}" or return "fileerror";
    d::w "settings", "bele2 $this->{filename}\n";
    local $/ = undef;
    my $file = <F>;
    close F;
    while ( $file =~ /^\s*\[(.+?)\]/gcm ) {
      push @{ $this->{group} }, $1;
      $currgroup = $1;
      d::w "settings", "bele3 $currgroup\n";

      if ( defined $currgroup ) {
        while ( $file =~ /^\s*(\w+)\s*=(.*)|^\s*\[(.+?)\]/gcm ) {
          if ( defined $3 ) {
            pos($file) = $-[3] - 1;
            last;
          }
          my $decoded=$2;
          my $key=$1;
           $decoded=~s/\\x0a/\x0a/g;
           $decoded=~s/\\x0d/\x0d/g;
           $decoded=~s/\\\\/\\/g;    
          $this->{hash}{$currgroup}{$key} = $decoded;
          d::w "settings", "$currgroup: $key $decoded\n";
          push @{ $this->{list}{$currgroup} }, $key;
        }
      }
    }
  }
  else {
    return 0;
  }
  return 1;
}

sub WriteFile {
  my $this = shift;
  d::w "settings", "WriteFile\n";
  open F, ">$this->{filename}" or return "fileerror";
  d::w "settings", "on\n";
  for ( @{ $this->{group} } ) {
    print F "[$_]\n";
    for my $i ( @{ $this->{list}{$_} } ) {
     my $encoded=$this->{hash}{$_}{$i};
     #$DB::single=2;
      $encoded=~s/\\/\\\\/g;
      $encoded=~s/\x0a/\\x0a/g;
      $encoded=~s/\x0d/\\x0d/g;
      print F "$i=$encoded\n";
      d::w "settings", "WriteFile:$_ $i\n";
    }
  }
  close F;
  return 1;
}

sub PrintGroup {
my $this = shift;
my $group = shift;
  d::w "settings", "[$group]\n";
    for my $i ( @{ $this->{list}{$group} } ) {
      print  "$i=$this->{hash}{$group}{$i}\n";
    }

}

sub SetDisk
{
 my $this = shift;
 my $disk = shift;
 $this->{disk}= $disk;
}

sub Flush {
  my $this = shift;
  d::w "settings", "flush $this->{changed}\n";
  if ( $this->{disk} and $this->{changed} ) { $this->WriteFile; }
  $this->{changed} = 0;
}

1;
