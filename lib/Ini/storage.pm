class Ini::Storage;

use Path::Util;
#use dprint;
#save configuration settings

submethod BUILD($filename,$isdisk) {
 # my $proto    = shift;
 # my $filename = shift;
 # my $class    = ref($proto) || $proto;
 # my $isdisk   = shift;
 # my $self     = {};

  #definitions
  my $p = filepath::getdir($filename);
  #print "filepath [$p]";
  if ( not defined $p ) {
    $p = %*ENV{USERPROFILE};
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

submethod DESTROY {
  $this->Flush;
}

method GetFilename {
  return $this->{filename};
}

method SetFilename($newfn) {
  $this->{filename}=$newfn;
  $this->{changed} = 1;
}

method Read($key,$default) {
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

method Exchange($key,$key2) {
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

method GetEntryName($group,$no)
{
  $no--;
 return $this->{list}{$group}[$no];
}

method FindRegInGroup($group)
{

}

method Write($key,$value) {
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

method Copy($obj) {
  for ( @{ $obj->{group} } ) {
    for my $i ( @{ $obj->{list}{$_} } ) {
      $this->Write( "/$_/$i", $obj->{hash}{$_}{$i} );
    }
  }
}

method CountEntries($group) {
  my $c;
  if (defined $this->{list}{$group})
  {
    return @{ $this->{list}{$group} };
  }
  return 0;
}

method CopyGroup($obj,$group) {
  my $newgroupname = shift // $group;
  for my $i ( @{ $obj->{list}{$group} } ) {
    $this->Write( "/$newgroupname/$i", $obj->{hash}{$group}{$i} );
  }
}

method DeleteEntry($key) {
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

method RenameEntry($key,$keynew)
{
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

method DeleteEntryFromArray($key)
{
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

method GetLastArrayIndex($key)
{
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

method DeleteGroup($group) {
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

method GroupExists($group)
{
if ( exists $this->{hash}{$group} ) {
    return 1;
  }
  else {
    return 0;
  }
}

method Exists($key) {
  my ( $group, $entry ) = $key =~ /\/?(.+?)\/(.+)/;
  if ( exists $this->{hash}{$group} and exists $this->{hash}{$group}{$entry} ) {
    return 1;
  }
  else {
    return 0;
  }
}

method GetGroups
{
return @{ $this->{group} };
}

method GetEntriesInGroup($group) {
  return $this->{hash}{$group};
}

method FindIndexInArrayByValue($group,$arrayname,$value) {

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

method FindAValueInRecordByKey($group,$arrayname,$value,$arrayname2) {
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

method GetArrayInGroupK($key) {
my ( $group, $entry ) = $key =~ /\/?(.+?)\/(.+)/;
return $this->GetArrayInGroupGE($group, $entry);
}




method GetArrayInGroupGE($group,$name) {
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

method SetArrayInGroup ($group,$name,$arr) {
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



method ReadFile {
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

method WriteFile {
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

method PrintGroup($group) {

  d::w "settings", "[$group]\n";
    for my $i ( @{ $this->{list}{$group} } ) {
      print  "$i=$this->{hash}{$group}{$i}\n";
    }

}

method SetDisk($disk)
{
 $this->{disk}= $disk;
}

method Flush {
  d::w "settings", "flush $this->{changed}\n";
  if ( $this->{disk} and $this->{changed} ) { $this->WriteFile; }
  $this->{changed} = 0;
}

1;
