#!/usr/bin/perl
#
# wsxpdf.pl: final script in websurfer -> pdf chain
#
# David Barnes, October 2012
#

die "usage: $0 [-movie15] [-nopdf] [-untidy] [-noidentify] [-skipregen] [-definvis] model.tok\n" if $#ARGV < 0 || $#ARVH > 1;

$tokfile = $ARGV[$#ARGV];
$pdffile = $tokfile;
$pdffile =~ s/\.tok$/\.pdf/;
$pdffile =~ s/\.TOK$/\.pdf/;

#print "$tokfile \t $pdffile\n";
#die;
$basepath = $tokfile;
@basepathcomps = split(/\//, $tokfile);
pop(@basepathcomps);
$basepath = join("/", @basepathcomps);

die "Token file $tokfile does not exist!\n" if ! -e $tokfile;

# -2. what mode? media9 (default) or movie15 ("-movie15")
#                pdf output (default) or just display s2plot ("-nopdf")
#                remove temp files (default) or don't clean-up ("-untidy")
#                disable object identification ("-noidentify")
#                skip regeneration of PRC model following -untidy run ("-skipregen")
$media9 = 1;
$skippdf = 0;
$tidyup = 1;
$identify = 1;
$skipregen = 0;
$defvis = 1;
$saveviews = "";
for ($i = 0; $i < $#ARGV; $i++) {
  if ($ARGV[$i] eq "-movie15") {
    $media9 = 0;
  } elsif ($ARGV[$i] eq "-nopdf") {
    $skippdf = 1;
  } elsif ($ARGV[$i] eq "-untidy") {
    $tidyup = 0;
  } elsif ($ARGV[$i] eq "-noidentify") {
    $identify = 0;
  } elsif ($ARGV[$i] eq "-skipregen") {
    $skipregen = 1;
  } elsif ($ARGV[$i] eq "-definvis") {
    $defvis = 0;
  } elsif ($ARGV[$i] eq "-saveviews") {
    $saveviews = "To save a custom view (camera angle, part visibility (via model tree), rendering mode, part rendering mode, background colour, zoom, ...), set things up as you like (using the toolbar above the model and/or the modeltree), then \\\movieref[3Dgetview]{wsxfig}{CLICK HERE}.  In the window that opens, highlight and copy the entire text from top to bottom (the window may need to scroll!) then paste it into a new file.  Save the file as a plain text file and give it the name you'd like to appear in the 'Views' menu, with a .txt extension.";
  } else {
    die "usage:  $0 [-movie15] [-nopdf] [-untidy] [-noidentify] [-skipregen] [-definvis] [-saveviews] model.tok\n";
  }
}

# -1. run pdfsurfer
if ($skippdf) {
  system "echo /S2MONO | pdfsurfer $tokfile";
  exit(0);
} elsif (!$skipregen) {
  system "echo /S2NULL | pdfsurfer $tokfile";
}

# 0. read coordinate info
@s2worldmin = (-1,-1,-1);
@s2worldmax = (1,1,1);
@s2worldoff = (0,0,0);
$ROLL = 0.0;
open (S2W, "s2direct.xyz"); # || die "Cannot open required s2direct.xyz file.\n";
while(<S2W>) {
  chop;

  @parts = split(':');
  if (/^S2WORLDMIN/) {
    @s2worldmin = ($parts[1], $parts[2], $parts[3]);
  } elsif (/^S2WORLDMAX/) {
    @s2worldmax = ($parts[1], $parts[2], $parts[3]);
  } elsif (/^S2WORLDOFF/) {
    @s2worldoff = ($parts[1], $parts[2], $parts[3]);
  }
}
close(S2W);

# printed out by pdfsurfer S2PLOT app...


# 1. read groups and objects from token file
$#grp_names = -1;
$#grp_cnames = -1; # compressed names (remove spaces, parenth, -> lowercase)
$#grp_ids = -1;
$#grp_inits = -1;
$#obj_names = -1;
$#obj_cnames = -1;
$#obj_pnames = -1; # "serialized" pdf names
$#obj_grps = -1;
$#obj_alphas = -1;
$title_frag = "<B>PDFSurfer</B>---3-d PDF publishing platform";
$footer_txt = "<B>PDFSurfer</B>---3-d imprint by D.G. Barnes (Monash e-Research Centre)";
$pdffooter_txt = "";
@camera_position = (0,0,1500);
@camera_lookat = (0,0,0);
@camera_up = (0,1,0);
@background = (0.976,0.976,0.976);
$jscriptext = "";
# @ambientLight = {0.4,0.4,0.4};
# @headLight = {0.467,0.467,0.467};

$#views_name = -1;
$#views_position = -1;
$#views_lookat = -1;
$#views_up = -1;

open(TOK, $tokfile); # || die "Cannot open named token file.\n";
while(<TOK>) {
  chop;
  #$line = $_;
  
  @parts = split(':');
  if (/^title_frag/) {
    $title_frag = $parts[1];
    # paste title split on ":" back together
    $k = 2;
    while ($k <= $#parts) {
      $title_frag .= ":" . $parts[$k];
      $k++;
    }

  } elsif (/^footer_txt/) {
    $footer_txt = $parts[1];
    # paste footer back together if split on ":"
    $k = 2;
    while ($k <= $#parts) {
      $footer_txt .= ":" . $parts[$k];
      $k++;
    }

  } elsif (/^pdffooter_txt/) {
    $pdffooter_txt = $parts[1];
    # paste footer back together if split on ":"
    $k = 2;
    while ($k <= $#parts) {
      $pdffooter_txt .= ":" . $parts[$k];
      $k++;
    }

  } elsif (/^camera_position/) {
    # rotate tuple due to different coords PDF/WebGL
    @camera_position = ($parts[1], $parts[2], $parts[3]);
  } elsif (/^camera_lookat/) {
    @camera_lookat = ($parts[1], $parts[2], $parts[3]);
  } elsif (/^camera_up/) {
    @camera_up = ($parts[1], $parts[2], $parts[3]);

  } elsif (/^jscriptext/) {
    $jscriptext = $parts[1];

  } elsif (/^background/) {
    @background = ($parts[1], $parts[2], $parts[3]);

  } elsif (/^grps/) {
    #@parts = split(':');

    # remove spaces, parentheses etc from name
    $name = $parts[1];
    $name =~ s/[\s\(\)]//g;
    $name =~ tr/[A-Z]/[a-z]/;

    push(@grp_names, $parts[1]);
    push(@grp_cnames, $name);
    push(@grp_ids, $parts[2]);
    push(@grp_inits, $parts[3]);

  } elsif (/^objs/) {
    #@parts = split(':');
    
    # remove spaces, parentheses etc from name
    $name = $parts[1];
    $name =~ s/[\s\(\)]//g;
    $name =~ tr/[A-Z]/[a-z]/;

    push(@obj_names, $parts[1]);
    push(@obj_cnames, $name);
    push(@obj_grps, $parts[2]);
    push(@obj_alphas, $parts[7]);

  } elsif (/^views/) {
    #@parts = split(':');

    push(@views_name, $parts[1]);
    push(@views_position, $parts[2]);
    push(@views_lookat, $parts[3]);
    push(@views_up, @parts[4]);

  }
 # print;
}
close(TOK);

$title_frag = reformHTML($title_frag);
if ($pdffooter_txt) {
  $footer_txt = reformHTML($pdffooter_txt);
} else {
  $footer_txt = reformHTML($footer_txt);
}

#printf "read from file:\n";
#printf "camera_lookat: %f %f %f\n", $camera_lookat[0], $camera_lookat[1], $camera_lookat[2];

@camera_position = rotateS2(@camera_position);
@camera_lookat = rotateS2(@camera_lookat);
@camera_up = rotateS2(@camera_up);

#printf "rotated:\n";
#printf "camera_lookat: %f %f %f\n", $camera_lookat[0], $camera_lookat[1], $camera_lookat[2];

@camera_position = rescaleS2(@camera_position);
@camera_lookat = rescaleS2(@camera_lookat);

#printf "rescaled:\n";
#printf "camera_lookat: %f %f %f\n", $camera_lookat[0], $camera_lookat[1], $camera_lookat[2];

@COO = @camera_lookat;
@COO = (0,0,0);
@C2C = ($camera_position[0]-$camera_lookat[0],
	$camera_position[1]-$camera_lookat[1],
	$camera_position[2]-$camera_lookat[2]);
$ROO = sqrt($C2C[0]*$C2C[0] + $C2C[1]*$C2C[1] + $C2C[2]*$C2C[2]);
@C2C = ($C2C[0]/$ROO, $C2C[1]/$ROO, $C2C[2]/$ROO);

# oh me oh my how to work out camera roll? 
# a. -C2C X camera_up = camera_right
@negC2C = (-$C2C[0], -$C2C[1], -$C2C[2]);
@camera_right = vectorCross(@negC2C, @camera_up);
# b. camera_right X -C2C = new_camera_up
@new_up = vectorCross(@camera_right, @negC2C);
# c. project new_camera_up into XZ plane
$new_up[1] = 0.0;
# d. measure angle it makes with Z
$len = sqrt($new_up[0]*$new_up[0] + $new_up[2]*$new_up[2]);
@new_up = ($new_up[0]/$len, $new_up[1]/$len, $new_up[2]/$len);
printf "ROLL components are %f, %f, %f\n", $new_up[0], $new_up[1], $new_up[2];
# measure angle rotated around from z axis up, e.g. x-axis = -90

# works almost perfectly for shoulder and cortex
$angle = atan2(-$new_up[0], $new_up[2]);
$ROLL = $angle * 180.0 / (atan2(1,1)*4.);

# 2. load the mapping from model.js object name to PDF object name
open(MAP, "s2direct.map");
while(<MAP>) {
  chop;
  if (/PART=\{(.+)\}/) {
    $pname = $1;
    for ($i = 0; $i <= $#obj_names; $i++) {
      if (substr($pname, 0, length($obj_names[$i])+1) eq $obj_names[$i].".") {
	$obj_pnames[$i] = $pname;
	#print $obj_names[$i], ":", $obj_pnames[$i], "\n";
      }
    }
  }

}
close(MAP);

# 3. for each group, create a toggle script and accumulate LaTeX code for all 
#    parts in the group (for movie15)
#    or accumulate PushButton with inline code (for media9).
#$preptoggle = "Toggle: ";
$preptoggle = "";
for ($i = 0; $i <= $#grp_names; $i++) {
  if (!$media9) {
    open(TSCR, "> pdfsurfer-$grp_cnames[$i].js");
  }

  $togjs = "";
  
  for ($j = 0; $j <= $#obj_names; $j++) {
    if ($obj_grps[$j] eq $grp_ids[$i]) {
      if ($media9) {
	$togjs .= "annotRM['wsxfig'].context3D.toggleVisibilityOfSerialisedNode(\"$obj_pnames[$j]\");";
      } else {
	print TSCR "annot3D['wsxfig'].context3D.toggleVisibilityOfSerialisedNode(\"$obj_pnames[$j]\");\n";
      }
    }
  }
  
  if ($preptoggle eq "") {
    $preptoggle = "Toggle: ";
  }
  if ($media9) {
    $preptoggle .= "\\PushButton[onclick={$togjs}]{\\fbox{$grp_names[$i]}}";
  } else {
    $preptoggle .= "\\movieref[3Djscript=pdfsurfer-$grp_cnames[$i].js]{wsxfig}{$grp_names[$i]}";
  }

  if ($i == $#grp_names) {
    $preptoggle .= ".\n\n";
  } else {
    if ($media9) {
      $preptoggle .= " ";
    } else {
      $preptoggle .= "; ";
    } 
  }

  if (!$media9) {
    close(TSCR);
  }
}


if (1) {
  createViews();
} else {

# 4. create a single-view s2views.txt file
open(S2V, "> pdfsurfer-s2views.txt");
print S2V "VIEW={Default view}\n";
print S2V "  COO=$COO[0] $COO[1] $COO[2]\n";
print S2V "  C2C=$C2C[0] $C2C[1] $C2C[2]\n";
print S2V "  ROO=$ROO\n";
print S2V "  ROLL=$ROLL\n";
for ($i = 0; $i <= $#obj_names; $i++) {
  print S2V "PART={$obj_pnames[$i]}\n";
  # is this part visible?
  $vis = $defvis;
  for ($j = 0; $j <= $#grp_names; $j++) {
    if ($obj_grps[$i] =~ m/$grp_ids[$j]/) {
      if (($grp_inits[$j] eq "true") || ($grp_inits[$j] == 1)) {
	$vis = 1;
      };
      print "$obj_pnames[$i]: group=$obj_grps[$i]: visible=$vis\n";
    }
  }
  if ($media9 || 1) {
    if ($vis) {
      print S2V "  VISIBLE=true\n";
    } else {
      print S2V "  VISIBLE=false\n";
    }
  } else {
    print S2V "  VISIBLE=$vis\n";
  }
  
  # is this part transparent?
  if ($obj_alphas[$i] < 0.99) {
    print S2V "  OPACITY=$obj_alphas[$i]\n";
  }

  print S2V "END\n";
}


print S2V "END\n";
close(S2V);
}

# 6. copy the s2plot-prc.js file 
system("cp \$S2PATH/s2prc/s2plot-prc.js .");
if ($identify) {
  system("cat pdfsurfer-selection.js >> s2plot-prc.js");
}
if ($jscriptext) {
  print "cat $basepath/$jscriptext >> s2plotprc.js\n";
  system("cat $basepath/$jscriptext >> s2plot-prc.js");
}

#10. read the template LaTex file and create the final version with toggles, text, etc.
print "Generating LaTeX file...\n";
if ($media9) {
  open(TEXTEMP, "pdfsurfer-template-media9.tex");
} else {
  open(TEXTEMP, "pdfsurfer-template-movie15.tex");
}
open(TEXOUT, "> pdfsurfer.tex");
while(<TEXTEMP>) {

  s/TITLETEXT/$title_frag/;

 # s/SECTIONTEXT/put section text here/;

 # s/CAPTIONTEXT/put caption text here/;

  s/BGCOLORS/$background[0] $background[1] $background[2]/;

  if (($identify && ($#obj_names > 0))) {
    s/IDENTIFY/\\noindent \\TextField\[name=objectlabel, width=0.8\\hsize\]\{Object:\}/;
  } else {
    s/IDENTIFY//;
  }

  s/TOGGLE/$preptoggle/;

  s/SAVEVIEWS/$saveviews/;

  s/FOOTER/$footer_txt/;

  print TEXOUT;
}
close(TEXOUT);

#exit(0);

#12. run pdflatex
print "Executing pdflatex (1/3) to generate PDF file...\n";
system "pdflatex pdfsurfer.tex "; # >& /dev/null";
print "Executing pdflatex (2/3) to generate PDF file...\n";
system "pdflatex pdfsurfer.tex >& /dev/null";
print "Executing pdflatex (3/3) to generate PDF file...\n";
system "pdflatex pdfsurfer.tex >& /dev/null";

  if ($tidyup) {
    print "Tidying up...\n";
    if (!$media9) {
      for ($i = 0; $i <= $#grp_names; $i++) {
	system ("rm pdfsurfer-$grp_cnames[$i].js");
      }
    }
    system ("rm pdfsurfer-s2views.txt s2plot-prc.js pdfsurfer.log s2direct.map pdfsurfer.aux pdfsurfer.tex s2plotprc.pdf s2direct.prc pdfsurfer.out s2direct.xyz");
  }

system "mv pdfsurfer.pdf $pdffile";

print "Done!\n";




sub reformHTML {
  local($html) = @_;
  $html =~ s|<[b,B]>(.*?)</[b,B]>|\{\\bf $1\}|g;
  $html =~ s|<[i,I]>(.*?)</[i,I]>|\{\\em $1\}|g;
  $html =~ s|\&amp;|\\\&|g;
  $html =~ s|\&nbsp;|~|g;
  $html;
}

sub rotateS2 {
  local ($x, $y, $z) = @_;
  @result = ($z, $x, $y);
}

sub rescaleS2 {
  local($x, $y, $z) = @_;

  $x = $x - $s2worldoff[0];
  $y = $y - $s2worldoff[1];
  $z = $z - $s2worldoff[2];

  $x = -1. + 2. * ($x - $s2worldmin[0]) / ($s2worldmax[0] - $s2worldmin[0]);
  $y = -1. + 2. * ($y - $s2worldmin[1]) / ($s2worldmax[1] - $s2worldmin[1]);
  $z = -1. + 2. * ($z - $s2worldmin[2]) / ($s2worldmax[2] - $s2worldmin[2]);

  @result = ($x,$y,$z);
}

sub vectorCross {
  local($ax,$ay,$az,$bx,$by,$bz) = @_;
  local $x = $ay * $bz - $az * $by;
  local $y = $az * $bx - $ax * $bz;
  local $z = $ax * $by - $ay * $bx;
  return ($x,$y,$z);
}

sub createViews {


# 4. create a single-view s2views.txt file
  open(S2V, "> pdfsurfer-s2views.txt");

  for ($vi = 0; $vi <= $#views_name; $vi++) {

    print S2V "VIEW={$views_name[$vi]}\n";

    # compute COO, C2C, ROO and ROLL
    @camera_position = split(',', $views_position[$vi]);
    @camera_lookat = split(',', $views_lookat[$vi]);
    @camera_up = split(',', $views_up[$vi]);

    @camera_position = rotateS2(@camera_position);
    @camera_lookat = rotateS2(@camera_lookat);
    @camera_up = rotateS2(@camera_up);
    
    #printf "rotated:\n";
    #printf "camera_lookat: %f %f %f\n", $camera_lookat[0], $camera_lookat[1], $camera_lookat[2];
    
    @camera_position = rescaleS2(@camera_position);
    @camera_lookat = rescaleS2(@camera_lookat);
    
    #printf "rescaled:\n";
    #printf "camera_lookat: %f %f %f\n", $camera_lookat[0], $camera_lookat[1], $camera_lookat[2];
    
    @COO = @camera_lookat;
    @COO = (0,0,0);
    @C2C = ($camera_position[0]-$camera_lookat[0],
	    $camera_position[1]-$camera_lookat[1],
	    $camera_position[2]-$camera_lookat[2]);
    $ROO = sqrt($C2C[0]*$C2C[0] + $C2C[1]*$C2C[1] + $C2C[2]*$C2C[2]);
    @C2C = ($C2C[0]/$ROO, $C2C[1]/$ROO, $C2C[2]/$ROO);
    
    # oh me oh my how to work out camera roll? 
    # a. -C2C X camera_up = camera_right
    @negC2C = (-$C2C[0], -$C2C[1], -$C2C[2]);
    @camera_right = vectorCross(@negC2C, @camera_up);
    # b. camera_right X -C2C = new_camera_up
    @new_up = vectorCross(@camera_right, @negC2C);
    # c. project new_camera_up into XZ plane
    $new_up[1] = 0.0;
    # d. measure angle it makes with Z
    $len = sqrt($new_up[0]*$new_up[0] + $new_up[2]*$new_up[2]);
    @new_up = ($new_up[0]/$len, $new_up[1]/$len, $new_up[2]/$len);
    printf "ROLL components are %f, %f, %f\n", $new_up[0], $new_up[1], $new_up[2];
    # measure angle rotated around from z axis up, e.g. x-axis = -90
    
    # works almost perfectly for shoulder and cortex
    $angle = atan2(-$new_up[0], $new_up[2]);
    $ROLL = $angle * 180.0 / (atan2(1,1)*4.);
    


    # write to view file
    print S2V "  COO=$COO[0] $COO[1] $COO[2]\n";
    print S2V "  C2C=$C2C[0] $C2C[1] $C2C[2]\n";
    print S2V "  ROO=$ROO\n";
    print S2V "  ROLL=$ROLL\n";

    # which parts are visible?
    for ($i = 0; $i <= $#obj_names; $i++) {
      print S2V "PART={$obj_pnames[$i]}\n";
      # is this part visible?
      $vis = $defvis;
      for ($j = 0; $j <= $#grp_names; $j++) {
	if ($obj_grps[$i] =~ m/$grp_ids[$j]/) {
	  if (($grp_inits[$j] eq "true") || ($grp_inits[$j] == 1)) {
	    $vis = 1;
	  };
	  print "$obj_pnames[$i]: group=$obj_grps[$i]: visible=$vis\n";
	}
      }
      if ($media9 || 1) {
	if ($vis) {
	  print S2V "  VISIBLE=true\n";
	} else {
	  print S2V "  VISIBLE=false\n";
	}
      } else {
	print S2V "  VISIBLE=$vis\n";
      }
    
      # is this part transparent?
      if ($obj_alphas[$i] < 0.99) {
	print S2V "  OPACITY=$obj_alphas[$i]\n";
      }
      print S2V "END\n"; # part end
    }

    print S2V "END\n"; # view end

  } # loop over views
  
  close(S2V);
  
}
