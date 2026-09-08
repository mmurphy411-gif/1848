shader_type particles;
float rand(float x){return fract(sin(x*127.1+.1848)*43758.5453);}
void start(){
 TRANSFORM=EMISSION_TRANSFORM;
 TRANSFORM[3].xyz+=(vec3(rand(float(NUMBER)),0.0,rand(float(NUMBER)+9.0))-.5)*vec3(20.0,0.0,20.0);
 VELOCITY=vec3(1.1,-14.0-rand(float(NUMBER)+3.0)*3.0,.3);
}
void process(){
 TRANSFORM[3].xyz+=VELOCITY*DELTA;
 vec3 p=TRANSFORM[3].xyz;
 float shore=-6.0+.0075*p.x*p.x;
 float ground=.12+max(0.0,p.z-shore)*.035;
 if(p.y<=max(0.0,ground))ACTIVE=false;
}
