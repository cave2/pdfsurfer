/* pdfsurfer.c: render surfaces in OBJ format to 3-d PDF
 *
 * Monash Web Surfer: web surface visualisation utility
 * (c) David G. Barnes, Monash University 2014
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 * 
 * usage: echo /s2null | pdfsurfer [path/to/]model.tok
 * (then) wsxpdf.pl [path/to/]model.tok
 * (then) pdflatex wsxpdf; # rpt 3 times
 * (then) open wsxpdf.pdf
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "s2plot.h"
#include "libobj.c"

/* see websurfer/index.html for these structures and defined "globals" */
typedef struct {
  char *label;
  char *group;
  char *filename;
  float r, g, b, a;
} PSOBJ_STRUCT;

typedef struct {
  char *name;
  char *id;
  int init;
} GRP_STRUCT;

XYZ camera_position = {0, 0, 1500};
XYZ camera_lookat = {0, 0, 0};
XYZ camera_up = {0, 1, 0};
XYZ background = {0.976, 0.976, 0.976};
//char ambientLight[] = "0x666666";
XYZ ambientLight = {0.4, 0.4, 0.4};
//char headLight[] = "0x777777";
XYZ headLight = {0.467, 0.467, 0.467};

PSOBJ_STRUCT *objs = NULL;
int nobjs = 0;

GRP_STRUCT *grps = NULL;
int ngrps = 0;

char *_sep = ":";
#define LINELENGTH 400
char line[LINELENGTH+1];

void writePRC(void);
int ParsePosInfo(char *line, XYZ *var);
int ParseGrps(char *line); // into globals
int ParseObjs(char *line, char *basepath); // into globals

int main(int argc, char **argv) {

  if (argc != 2) {
    fprintf(stderr, "usage: %s [path/to/]model.tok\n", argv[0]);
    exit(-1);
  }

  // identify path prefix if provided
  char basepath[400];
  strcpy(basepath, argv[1]);
  int kk = strlen(basepath)-1;
  while ((kk >= 0) && (basepath[kk] != '/')) {
    kk--;
  }
  if (kk > 0) {
    basepath[kk+1] = '\0';
  } else {
    strcpy(basepath, "");
  }
  fprintf(stderr, "basepath = %s\n", basepath);
  //exit(-1);
  
  FILE *fin = fopen(argv[1], "r");
  if (!fin) {
    fprintf(stderr, "error: failed to open (tokenised) model file %s.\n", argv[1]);
    exit(-1);
  }

  int lidx = 0;
  while (fgets(line, LINELENGTH, fin)) {

    char *word;

    word = strtok(line, _sep);
    if (!word) {
      continue;
    }
      
    if (!strcmp(word, "camera_position")) {
      ParsePosInfo(NULL, &camera_position);
    } else if (!strcmp(word, "camera_lookat")) {
      ParsePosInfo(NULL, &camera_lookat);
    } else if (!strcmp(word, "camera_up")) {
      ParsePosInfo(NULL, &camera_up);
    } else if (!strcmp(word, "background")) {
      ParsePosInfo(NULL, &background);
    } else if (!strcmp(word, "ambientLight")) {
      ParsePosInfo(NULL, &ambientLight);
    } else if (!strcmp(word, "headLight")) {
      ParsePosInfo(NULL, &headLight);
    }

    else if (!strcmp(word, "grps")) {
      ParseGrps(NULL);
    } 

    else if (!strcmp(word, "objs")) {
      ParseObjs(NULL, basepath);
    }

    
    

    lidx++;
  }
  

#if (1)
  s2opend("/?", argc, argv);
  
  ss2sbc(background.x, background.y, background.z);
  ss2sfc(1.0 - background.x, 1.0 - background.y, 1.0 - background.z);

  XYZ one = {1,1,1};
  XYZ mone = {-1,-1,-1};

  XYZ minP, maxP;
  minP = mone;
  maxP = one;

  OBJ_STRUCT **obj = (OBJ_STRUCT **)malloc(nobjs * sizeof(OBJ_STRUCT *));

  int i;
  for (i = 0; i < nobjs; i++) {
    if (!strncmp(objs[i].filename+strlen(objs[i].filename)-3, "obj", 3)) {
      obj[i] = loadObj(objs[i].filename, objs[i].label, 
		       objs[i].r, objs[i].g, objs[i].b, objs[i].a);
    } else if (!strncmp(objs[i].filename+strlen(objs[i].filename)-3, "stl", 3)) {
      obj[i] = loadObjFromSTL(objs[i].filename, objs[i].label,
			      objs[i].r, objs[i].g, objs[i].b, objs[i].a);
    } else {
      fprintf(stderr, "failed loading... %s\n", objs[i].filename);
      exit(-1);
    }

    // BADLY NAMED OBJ FILE NEEDS TO BE CAUGHT!!! Maybe check (return) value of obj[i] ?

#if (0)
#if (0) // convert trapezius
    if (i == 1) {
      fprintf(stderr, "* * * Transforming surface %d\n", i);
      float m[] = { 0, 0, 1, 0,
		    1, 0, 0, 0,
		    0, 1, 0, 0};
      transformObj(obj[i], m);
    }
#else // convert bones
    // try to transform "bones_all_right_position" (moved to MR space by MQ)
    // into same space as scapula_orig.
    if (i == 3) {
      float n[] = {0.999699971,  0.01956703452,  -0.0147328116,  35.45830307,
		   -0.01911784629,  0.9993659074,  0.03003614311,  101.0009958,
		   0.01531118878,  -0.02974547023,  0.9994402422,  -0.7996837918};
      //transformObj(obj[i], n);
      float m[] = { 0, 0, 1, 0, 
      		    0, 1, 0, 0,
      		    -1, 0, 0, 0};
      transformObj(obj[i], m);
    }
#endif
#endif

    if (i == 0) {
      minP = obj[i]->minP;
      maxP = obj[i]->maxP;
    } else {
      if (obj[i]->minP.x < minP.x) {
	minP.x = obj[i]->minP.x;
      }
      if (obj[i]->minP.y < minP.y) {
	minP.y = obj[i]->minP.y;
      }
      if (obj[i]->minP.z < minP.z) {
	minP.z = obj[i]->minP.z;
      }

      if (obj[i]->maxP.x > maxP.x) {
	maxP.x = obj[i]->maxP.x;
      }
      if (obj[i]->maxP.y > maxP.y) {
	maxP.y = obj[i]->maxP.y;
      }
      if (obj[i]->maxP.z > maxP.z) {
	maxP.z = obj[i]->maxP.z;
      }

    }
  }


  // offset all model parts
  XYZ mid = VectorAdd(minP, maxP);
  mid = VectorMul(mid, 0.5);
  fprintf(stderr, "LookAt: %f %f %f\n", mid.x, mid.y, mid.z);
  for (i = 0; i < nobjs; i++) {
    translateObj(obj[i], mid);
  }
  minP = VectorSub(mid, minP);
  maxP = VectorSub(mid, maxP);


  // now find global min (x,y,z) and max (x,y,z) so we have a
  // properly scaled world coordinate box to draw in
  float min = minP.x;
  if (minP.y < min) {
    min = minP.y;
  }
  if (minP.z < min) {
    min = minP.z;
  }

  float max = maxP.x;
  if (maxP.y > max) {
    max = maxP.y;
  }
  if (maxP.z > max) {
    max = maxP.z;
  }

  s2swin(min,max, min,max, min,max);
  //s2swin(-1,1,-1,1,-1,1);
  FILE *S2W = fopen("s2direct.xyz", "w");
  fprintf(S2W, "S2WORLDMIN:%f:%f:%f\n", min, min, min);
  fprintf(S2W, "S2WORLDMAX:%f:%f:%f\n", max, max, max);
  fprintf(S2W, "S2WORLDOFF:%f:%f:%f\n", mid.x, mid.y, mid.z);
  fclose(S2W);

#if (0)
  unsigned int texid = ss2lt("femur.tga");
  fprintf(stderr, "Loaded texture, id = %d\n", texid);
  drawObjAsTexturedMesh(obj[0], texid);
#else
  for (i = 0; i < nobjs; i++) {
    drawObj(obj[i]);
  }
#endif
  
#if (0)
  s2box("BCDE",0,0,"BCDE",0,0,"BCDE",0,0);
  COLOUR red = {1.,0.0,0.0};
  XYZ v_start_w = {-5.825637, -79.917597, 7.105154};
  XYZ v_end_w = {-0.790148, 79.326064, -13.341468};
  //ns2vline(v_start_w, v_end_w, red);
  ns2vthpoint(v_start_w, red, 3.0);
  ns2vthpoint(v_end_w, red, 3.0);

  COLOUR yellow = {1., 1., 0.};
  v_start_w = VectorSub(mid, v_start_w);
  v_end_w = VectorSub(mid, v_end_w);
  //ns2vline(v_start_w, v_end_w, yellow);
  ns2vthpoint(v_start_w, yellow, 3.0);
  ns2vthpoint(v_end_w, yellow, 3.0);

  fprintf(stderr, "v_start_w = (%f, %f, %f)\n", v_start_w.x, v_start_w.y, v_start_w.z);
  fprintf(stderr, "v_end_w =   (%f, %f, %f)\n", v_end_w.x,   v_end_w.y,   v_end_w.z);

  XYZ v_start_d;
  v_start_d.x = (v_start_w.x - min) / (max - min);
  v_start_d.y = (v_start_w.y - min) / (max - min);
  v_start_d.z = (v_start_w.z - min) / (max - min);

  XYZ v_end_d;
  v_end_d.x = (v_end_w.x - min) / (max - min);
  v_end_d.y = (v_end_w.y - min) / (max - min);
  v_end_d.z = (v_end_w.z - min) / (max - min);

  fprintf(stderr, "v_start_d = (%f, %f, %f)\n", v_start_d.x, v_start_d.y, v_start_d.z);
  fprintf(stderr, "v_end_d =   (%f, %f, %f)\n", v_end_d.x,   v_end_d.y,   v_end_d.z);

#endif

  int stereo, fs, dome;
  ss2qsa(&stereo, &fs, &dome);
  if (stereo < 0) { // null device
    //double t = 0.0;
    //int kc = 0;
    //doPRC = 1;
    //cb(&t, &kc); // but what about billboards?
    writePRC();
  } else {
    char opt[] = "BCDETMNOPQ";
    pushVRMLname("XAXES");
    s2sci(S2_PG_RED);
    s2box(opt,0,0, "",0,0,"",0,0);
    pushVRMLname("YAXES");
    s2sci(S2_PG_GREEN);
    s2box("",0,0, opt,0,0, "",0,0);
    pushVRMLname("ZAXES");
    s2sci(S2_PG_BLUE);
    s2box("",0,0, "",0,0, opt,0,0);
    pushVRMLname("ANON");
    s2show(1);
  }

#endif

  return 0;
}

int ParsePosInfo(char *line, XYZ *var) {
  char *word;
  float x = 0., y = 0., z= 0.;
  int valid = 0;
  word = strtok(line, _sep);
  if (word) {
    x = atof(word);
    valid++;
  }
  
  word = strtok(line, _sep);
  if (word) {
    y = atof(word);
    valid++;
  }

  word = strtok(line, _sep);
  if (word) {
    z = atof(word);
    valid++;
  }

  if (valid == 3) {
    var->x = x;
    var->y = y;
    var->z = z;
  }
  
  return (valid == 3);
}

int ParseGrps(char *line){
  char *word;
  char grpname[400], grpid[32];
  int grpinit;
  int valid = 0;
  word = strtok(line, _sep);
  if (word) {
    strcpy(grpname, word);
    valid++;
  }

  word = strtok(line, _sep);
  if (word) {
    strcpy(grpid, word);
    valid++;
  }

  word = strtok(line, _sep);
  if (word) {
    grpinit = atoi(word);
    valid++;
  }

  if (valid == 3) {
    grps = (GRP_STRUCT *)realloc(grps, (ngrps+1) * sizeof(GRP_STRUCT));
    grps[ngrps].name = (char *)malloc(strlen(grpname)+1);
    strcpy(grps[ngrps].name, grpname);
    grps[ngrps].id = (char *)malloc(strlen(grpid)+1);
    strcpy(grps[ngrps].id, grpid);
    grps[ngrps].init = grpinit;
    ngrps++;
  }
    
  return (valid == 3);
}


int ParseObjs(char *line, char *basepath) {

  char *word;
  char objlabel[400], objgroup[400], objfilename[400];
  float obj_r = 1.0, obj_g = 1.0, obj_b = 1.0, obj_a = 1.0;
  int valid = 0;
  
  word = strtok(line, _sep);
  if (word) {
    strcpy(objlabel, word);
    valid++;
  }

  word = strtok(line, _sep);
  if (word) {
    strcpy(objgroup, word);
    valid++;
  }

  word = strtok(line, _sep);
  if (word) {
    sprintf(objfilename, "%s%s", basepath, word);
    //strcpy(objfilename, word);
    valid++;
  }

  word = strtok(line, _sep);
  if (word) {
    obj_r = atof(word);
    valid++;
  }

  word = strtok(line, _sep);
  if (word) {
    obj_g = atof(word);
    valid++;
  }

  word = strtok(line, _sep);
  if (word) {
    obj_b = atof(word);
    valid++;
  }

  word = strtok(line, _sep);
  if (word) {
    obj_a = atof(word);
    valid++;
  }

  if (valid == 7) {
    objs = (PSOBJ_STRUCT *)realloc(objs, (nobjs+1) * sizeof(PSOBJ_STRUCT));
    objs[nobjs].label = (char *)malloc(strlen(objlabel)+1);
    strcpy(objs[nobjs].label, objlabel);
    //sprintf(objs[nobjs].label, "L%d", nobjs);
    objs[nobjs].group = (char *)malloc(strlen(objgroup)+1);
    strcpy(objs[nobjs].group, objgroup);
    objs[nobjs].filename = (char *)malloc(strlen(objfilename)+1);
    strcpy(objs[nobjs].filename, objfilename);
    objs[nobjs].r = obj_r;
    objs[nobjs].g = obj_g;
    objs[nobjs].b = obj_b;
    objs[nobjs].a = obj_a;

    fprintf(stderr, "loaded: %s : %s\n", objlabel, objs[nobjs].label);
    nobjs++;
  }
  
  return (valid == 7);
}
