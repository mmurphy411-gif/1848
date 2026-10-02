shader_type particles;
float rand(float x){return fract(sin(x*127.1+.1848)*43758.5453);}
void start(){
 TRANSFORM=EMISSION_TRANSFORM;
 TRANSFORM[3].xyz+=(vec3(rand(float(NUMBER)),0.0,rand(float(NUMBER)+9.0))-.5)*vec3(20.0,0.0,20.0);
 // Terminal speed of large drops; slower than before so each 0.9 m streak overlaps
 // itself frame to frame and survives temporal AA.
 VELOCITY=vec3(.8,-9.5-rand(float(NUMBER)+3.0)*2.0,.22);
}
void process(){
 TRANSFORM[3].xyz+=VELOCITY*DELTA;
 vec3 p=TRANSFORM[3].xyz;
 float shore=-6.0+.0075*p.x*p.x;
 float ground=.12+max(0.0,p.z-shore)*.035;
 if(p.y<=max(0.0,ground))ACTIVE=false;
}
